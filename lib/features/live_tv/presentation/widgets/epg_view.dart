import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/live_state.dart';
import '../../domain/channel.dart';
import 'epg_painter.dart';
import 'epg_viewport.dart';
import 'live_tv_utils.dart';

/// Vista de la guía EPG: un único lienzo gobernado por [EpgViewportController].
/// Solo se construye/pinta la parte visible + buffer.
class EpgView extends ConsumerStatefulWidget {
  const EpgView({
    super.key,
    required this.viewport,
    required this.now,
    required this.onSelectChannel,
    required this.onOpenFullscreen,
  });

  final EpgViewportController viewport;
  final DateTime now;
  final ValueChanged<Channel> onSelectChannel;
  final VoidCallback onOpenFullscreen;

  @override
  ConsumerState<EpgView> createState() => _EpgViewState();
}

class _EpgViewState extends ConsumerState<EpgView> {
  double _lastScale = 1;
  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier(DateTime.now());

  @override
  void didUpdateWidget(covariant EpgView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.now.isAtSameMomentAs(widget.now)) {
      _nowNotifier.value = widget.now;
    }
  }

  @override
  void dispose() {
    _nowNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveTvStateProvider);
    final channels = state.visibleChannels;
    final byChannel = state.programsByChannel;
    final vp = widget.viewport;
    vp.channelCount = channels.length;

    return LayoutBuilder(builder: (context, constraints) {
      final gridWidth = math.max(0.0, constraints.maxWidth - vp.leftRailWidth);
      final gridHeight = math.max(0.0, constraints.maxHeight - vp.headerHeight);
      vp.setViewportSize(gridWidth, gridHeight);

      final gridPainter = EpgGridPainter(
        viewport: vp,
        channels: channels,
        programsByChannel: byChannel,
        selectedChannelId: state.selectedChannelId,
        now: widget.now,
        repaint: Listenable.merge([vp, _nowNotifier]),
      );

      return Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (event.scrollDelta.dx != 0) {
              vp.panBy(event.scrollDelta.dx, 0);
            } else {
              vp.panBy(0, event.scrollDelta.dy);
            }
          }
        },
        child: Column(
          children: [
            SizedBox(
              height: vp.headerHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: vp.leftRailWidth,
                    child: const ColoredBox(color: Color(0x0A000000)),
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: vp,
                      builder: (_, _) => _TimeAxis(viewport: vp),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: vp.leftRailWidth,
                    child: AnimatedBuilder(
                      animation: vp,
                      builder: (_, _) => _ChannelRail(
                        viewport: vp,
                        channels: channels,
                        selectedChannelId: state.selectedChannelId,
                        onTap: widget.onSelectChannel,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onScaleStart: (_) => _lastScale = 1,
                      onScaleUpdate: _onScaleUpdate,
                      onTapUp: (d) =>
                          _onTapUp(d.localPosition, channels, gridPainter),
                      onDoubleTap: widget.onOpenFullscreen,
                      child: CustomPaint(painter: gridPainter),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final vp = widget.viewport;
    final scale = details.scale;
    if ((scale - 1).abs() > 0.01) {
      final factor = scale / _lastScale;
      _lastScale = scale;
      vp.zoomBy(factor, focalX: details.localFocalPoint.dx);
    }
    final delta = details.focalPointDelta;
    if (delta != Offset.zero) {
      vp.panBy(-delta.dx, -delta.dy);
    }
  }

  void _onTapUp(Offset local, List<Channel> channels, EpgGridPainter painter) {
    final hit = painter.hitTestProgram(local);
    final index = hit.channelIndex;
    if (index != null && index < channels.length) {
      widget.onSelectChannel(channels[index]);
    }
  }
}

/// Eje horario de la cabecera (solo etiquetas visibles).
class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.viewport});

  final EpgViewportController viewport;

  @override
  Widget build(BuildContext context) {
    final left = viewport.visibleLeft;
    final start = viewport.visibleStart;
    final stop = viewport.visibleEnd;

    final labels = <Widget>[];
    var hour = DateTime(start.year, start.month, start.day, start.hour);
    while (!hour.isAfter(stop)) {
      final x = viewport.timeToX(hour) - left;
      labels.add(
        Positioned(
          left: x,
          top: 0,
          bottom: 0,
          child: SizedBox(
            width: 60 * viewport.pixelsPerMinute,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  formatProgramTime(hour),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      hour = hour.add(const Duration(hours: 1));
    }
    return ClipRect(child: Stack(children: labels));
  }
}

/// Rail de canales de la columna izquierda (solo filas visibles).
class _ChannelRail extends StatelessWidget {
  const _ChannelRail({
    required this.viewport,
    required this.channels,
    required this.selectedChannelId,
    required this.onTap,
  });

  final EpgViewportController viewport;
  final List<Channel> channels;
  final String? selectedChannelId;
  final ValueChanged<Channel> onTap;

  @override
  Widget build(BuildContext context) {
    final top = viewport.visibleTop;
    final rowH = viewport.channelRowHeight;
    if (channels.isEmpty) return const SizedBox.shrink();
    final first = math.max(0, viewport.firstVisibleChannel - 1);
    final last = math.min(channels.length - 1, viewport.lastVisibleChannel + 1);

    final cells = <Widget>[];
    for (var i = first; i <= last; i++) {
      final c = channels[i];
      cells.add(
        Positioned(
          top: i * rowH - top,
          left: 0,
          right: 0,
          height: rowH,
          child: _RailCell(
            channel: c,
            selected: c.id == selectedChannelId,
            onTap: () => onTap(c),
          ),
        ),
      );
    }
    return ClipRect(child: Stack(children: cells));
  }
}

/// Celda de un canal en el rail.
class _RailCell extends ConsumerWidget {
  const _RailCell({
    required this.channel,
    required this.selected,
    required this.onTap,
  });

  final Channel channel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  channel.number ?? '',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 40,
                  height: 26,
                  child: channel.logoUrl != null
                      ? Image.network(
                          channel.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _RailFallback(channel: channel),
                        )
                      : _RailFallback(channel: channel),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailFallback extends StatelessWidget {
  const _RailFallback({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A2568),
      alignment: Alignment.center,
      child: Text(
        (channel.name.isEmpty ? '?' : channel.name.substring(0, 1)).toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
