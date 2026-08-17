import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/channel.dart';
import '../../domain/program.dart';
import 'epg_viewport.dart';
import 'live_tv_utils.dart';

/// Resultado de un hit-test sobre la rejilla EPG.
class EpgHit {
  const EpgHit({this.channelIndex, this.program, this.time});

  final int? channelIndex;
  final Program? program;
  final DateTime? time;
}

/// Pinta SOLO la parte visible de la rejilla de programas (+ buffer) y hace el
/// hit-test offset → canal + hora → programa.
class EpgGridPainter extends CustomPainter {
  EpgGridPainter({
    required this.viewport,
    required this.channels,
    required this.programsByChannel,
    required this.selectedChannelId,
    required this.now,
  }) : super(repaint: viewport);

  final EpgViewportController viewport;
  final List<Channel> channels;
  final Map<String, List<Program>> programsByChannel;
  final String? selectedChannelId;
  final DateTime now;

  static const double _bufferPx = 200;

  static final Paint _rowLine = Paint()
    ..color = const Color(0x14FFFFFF)
    ..strokeWidth = 1;
  static final Paint _selectedRow = Paint()..color = const Color(0x12FFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final vp = viewport;
    final left = vp.visibleLeft;
    final top = vp.visibleTop;
    final ppm = vp.pixelsPerMinute;
    final rowH = vp.channelRowHeight;
    final count = channels.length;
    if (count == 0) return;

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x06000000));

    final first = math.max(0, vp.firstVisibleChannel - 1);
    final last = math.min(count - 1, vp.lastVisibleChannel + 1);

    final bufferTime = Duration(minutes: (_bufferPx / ppm).round());
    final tStart = vp.visibleStart.subtract(bufferTime);
    final tEnd = vp.visibleEnd.add(bufferTime);

    for (var i = first; i <= last; i++) {
      final channel = channels[i];
      final y = i * rowH - top;
      final selected = channel.id == selectedChannelId;

      if (selected) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, rowH), _selectedRow);
      }

      final programs = programsByChannel[channel.id] ?? const <Program>[];
      final window = programsInWindow(programs, tStart, tEnd);
      for (final p in window) {
        final x = vp.timeToX(p.startTime) - left;
        final w = math.max(
          4.0,
          vp.timeToX(p.endTime) - vp.timeToX(p.startTime),
        );
        _paintProgram(
          canvas,
          Rect.fromLTWH(x, y + 2, w, rowH - 4),
          p,
          selected,
        );
      }

      canvas.drawLine(
        Offset(0, y + rowH),
        Offset(size.width, y + rowH),
        _rowLine,
      );
    }

    // Línea "NOW" (imprescindible).
    final nowX = vp.timeToX(now) - left;
    if (nowX >= -24 && nowX <= size.width + 24) {
      final line = Paint()
        ..color = const Color(0xFFFF5252)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(nowX, 0), Offset(nowX, size.height), line);
      canvas.drawRect(
        Rect.fromLTWH(nowX - 3, 0, 6, 6),
        Paint()..color = const Color(0xFFFF5252),
      );
    }
  }

  void _paintProgram(Canvas canvas, Rect rect, Program program, bool selected) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    final fill = Paint()
      ..color = selected
          ? const Color(0x3DFFFFFF)
          : const Color(0x14FFFFFF);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x26FFFFFF);
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, border);

    if (rect.width < 28 || rect.height < 14) return;

    final titleTp = TextPainter(
      text: TextSpan(
        text: program.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(0, rect.width - 8));
    titleTp.paint(
      canvas,
      Offset(rect.left + 4, rect.top + (rect.height - titleTp.height) / 2),
    );

    if (rect.width > 84) {
      final timeTp = TextPainter(
        text: TextSpan(
          text: formatProgramTime(program.startTime),
          style: const TextStyle(color: Colors.white54, fontSize: 9),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      timeTp.paint(
        canvas,
        Offset(
          rect.left + 4,
          rect.bottom - timeTp.height - 2,
        ),
      );
    }
  }

  /// Convierte un punto local (relativo a la rejilla) en canal + programa.
  EpgHit hitTestProgram(Offset local) {
    final vp = viewport;
    final index = vp.channelAtY(local.dy + vp.visibleTop);
    if (index == null || index >= channels.length) return const EpgHit();
    final channel = channels[index];
    final time = vp.xToTime(local.dx + vp.visibleLeft);
    final programs = programsByChannel[channel.id] ?? const <Program>[];
    return EpgHit(
      channelIndex: index,
      program: programAt(programs, time),
      time: time,
    );
  }

  @override
  bool shouldRepaint(covariant EpgGridPainter oldDelegate) =>
      oldDelegate.viewport != viewport ||
      oldDelegate.channels != channels ||
      oldDelegate.programsByChannel != programsByChannel ||
      oldDelegate.selectedChannelId != selectedChannelId ||
      oldDelegate.now != now;
}
