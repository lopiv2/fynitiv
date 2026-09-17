import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Eclipse sonoro adaptado del shader de Shadertoy "ls3BDH" (a partir de
/// 4tGXzt), replicado con `CustomPainter` en lugar de un shader de Flutter.
///
/// Reglas del shader original:
/// - Fondo azul oscuro; disco negro central (halo que funde a negro dentro).
/// - Anillo fino con caída `1/|dist-RADIUS)` y neón: el grosor es fijo y
///   la FFT modula el brillo; tono arcoíris girando con el tiempo.
/// - Muestreo de frecuencia espejado: `abs(ángulo/π)` en el anillo
///   (graves arriba) y `abs(x)` en la línea (graves en el centro).
/// - Línea espectral sobre coordenadas rotadas con el tiempo (orbita el
///   disco) que sale de detrás de él (`smoothstep(R, R*1.8, |x|)`).
/// - Rayos radiales según la frecuencia (cosecha propia sobre el shader).
///
/// Toda la composición rota de forma continua. Se alimenta de FFT real de
/// SoLoud cuando está disponible (música) o de FFT sintética en radio
/// (ver `FakeSoundEclipseVisualizer` en `audio_waveform.dart`).
class SoundEclipsePainter extends CustomPainter {
  SoundEclipsePainter({
    required this.fft,
    this.rotation = 0,
    this.ringSegments = 48,
    this.lineBars = 48,
    this.rayCount = 24,
    this.audioScale = 1.6,
    this.minBin = 1,
    this.maxBin = 120,
  });

  final Float32List fft;

  /// Rotación actual en radianes: gira el anillo (tonos), la línea
  /// espectral y los rayos.
  final double rotation;
  final int ringSegments;
  final int lineBars;
  final int rayCount;
  final double audioScale;
  final int minBin;
  final int maxBin;

  static Color hue(double t) =>
      HSVColor.fromAHSV(1, (t % 1.0) * 360, 1, 1).toColor();

  double _bin(int bar, int bars) {
    if (fft.isEmpty || bars <= 0) return 0;
    final effMax = maxBin.clamp(0, fft.length - 1);
    final effMin = minBin.clamp(0, effMax);
    final range = (effMax - effMin + 1).clamp(1, fft.length);
    final chunk = range / bars;
    final start = (bar * chunk + effMin).floor().clamp(0, fft.length - 1);
    final end = ((bar + 1) * chunk + effMin).ceil().clamp(0, fft.length);
    double sum = 0;
    var count = 0;
    for (var k = start; k < end; k++) {
      sum += fft[k];
      count++;
    }
    if (count == 0) return 0;
    return (sum / count * audioScale).clamp(0.0, 1.0);
  }

  double _bass() {
    if (fft.isEmpty) return 0;
    final end = 8.clamp(0, fft.length);
    double sum = 0;
    for (var k = 0; k < end; k++) {
      sum += fft[k];
    }
    return (sum / end * audioScale).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final bass = _bass();
    final radius =
        (math.min(size.width, size.height) * 0.26 * (1 + bass * 0.10))
            .clamp(8.0, math.min(size.width, size.height) / 2);
    final rotTurns = rotation / (math.pi * 2);

    // Rayos radiales en todas direcciones, longitud/alpha según frecuencia
    // (muestreo espejado como el anillo del shader).
    for (var i = 0; i < rayCount; i++) {
      final m = math.min(i, rayCount - i);
      final v = _bin(m, rayCount ~/ 2 + 1);
      if (v < 0.05) continue;
      final angle = i * math.pi * 2 / rayCount + rotation * 0.5;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final len = radius * (0.6 + v * 2.6);
      final base = center + dir * radius * 0.95;
      final tip = center + dir * (radius * 0.95 + len);
      final perp = Offset(-dir.dy, dir.dx) * (3 + v * 9);
      final path = Path()
        ..moveTo(base.dx - perp.dx, base.dy - perp.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(base.dx + perp.dx, base.dy + perp.dy)
        ..close();
      final rayColor = hue(i / rayCount + rotTurns * 0.5);
      canvas.drawPath(
        path,
        Paint()
          ..color = rayColor.withValues(alpha: 0.08 + v * 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Línea espectral que atraviesa el disco, girando con la composición.
    // Queda detrás del disco: se dibuja antes que el anillo y el disco.
    final lineAngle = rotation;
    final lineDir = Offset(math.cos(lineAngle), math.sin(lineAngle));
    final lineLen = math.max(size.width, size.height) * 0.95;
    for (var i = 0; i < lineBars; i++) {
      final t = lineBars == 1 ? 0.5 : i / (lineBars - 1);
      // Frecuencia espejada del shader: graves en el centro, agudos fuera.
      final dist = (t - 0.5).abs() * 2;
      final v = _bin(
        (dist * lineBars).floor().clamp(0, lineBars - 1),
        lineBars,
      );
      if (v < 0.02) continue;
      final s = (t - 0.5) * lineLen;
      // La línea sale de detrás del disco: fundido R → R*1.8 del shader.
      final fade = ((s.abs() - radius) / (radius * 0.8)).clamp(0.0, 1.0);
      if (fade <= 0) continue;
      final color = hue(t + rotTurns);
      final thickness = 1.5 + v * 7;
      final p = center + lineDir * s;
      final half = lineLen / lineBars / 2 + 0.5;
      final a = p - lineDir * half;
      final b = p + lineDir * half;
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: (0.35 + v * 0.40) * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(a, b, glow);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (thickness * 0.45).clamp(1.0, thickness)
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: (0.70 + v * 0.30) * fade),
      );
      // Halo sutil en los picos.
      if (v > 0.55) {
        canvas.drawCircle(
          p,
          thickness * (0.8 + v),
          Paint()
            ..color = color.withValues(alpha: 0.18 * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }

    // Anillo fino con resplandor (1/|dist-R| del shader): el grosor es
    // fijo y la frecuencia modula el brillo. Muestreo espejado del shader:
    // graves arriba, agudos abajo, laterales simétricos.
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    final sweep = (math.pi * 2 / ringSegments) * 0.86;
    final ringMirror = ringSegments ~/ 2 + 1;
    for (var i = 0; i < ringSegments; i++) {
      final m = math.min(i, ringSegments - i);
      final v = _bin(m, ringMirror);
      final start = -math.pi / 2 + i * math.pi * 2 / ringSegments;
      final color = hue(i / ringSegments + rotTurns);
      canvas.drawArc(
        ringRect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.12 + v * 0.33)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawArc(
        ringRect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.35 + v * 0.65),
      );
    }

    // Disco negro central del eclipse.
    canvas.drawCircle(center, radius, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant SoundEclipsePainter oldDelegate) => true;
}

/// Velocidad base de rotación del eclipse (radianes por segundo).
const double _kEclipseBaseSpeed = 0.10;

/// Visualizador SoundEclipse con FFT real de SoLoud (música / music player).
/// La composición rota de forma continua; la velocidad aumenta con los graves.
class SoundEclipseVisualizer extends StatefulWidget {
  const SoundEclipseVisualizer({super.key, this.audioScale = 1.6});

  final double audioScale;

  @override
  State<SoundEclipseVisualizer> createState() => _SoundEclipseVisualizerState();
}

class _SoundEclipseVisualizerState extends State<SoundEclipseVisualizer>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  Float32List _fft = Float32List(256);
  late final Ticker _ticker;
  double _rotation = 0;
  Duration? _lastTick;

  double _bass() {
    if (_fft.isEmpty) return 0;
    final end = 8.clamp(0, _fft.length);
    double sum = 0;
    for (var k = 0; k < end; k++) {
      sum += _fft[k];
    }
    return (sum / end * widget.audioScale).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    try {
      SoLoud.instance.setVisualizationEnabled(true);
      SoLoud.instance.setFftSmoothing(0.85);
    } catch (_) {}
    _sub = SoLoud.instance.audioVisualizationEvents.listen((data) {
      if (data.fftData != null && mounted) setState(() => _fft = data.fftData!);
    });
    _ticker = createTicker((elapsed) {
      final dt = _lastTick == null
          ? 0.016
          : (elapsed - _lastTick!).inMicroseconds / 1e6;
      _lastTick = elapsed;
      if (mounted) {
        setState(() {
          _rotation += dt * (_kEclipseBaseSpeed + _bass() * 0.2);
        });
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: SoundEclipsePainter(
        fft: _fft,
        rotation: _rotation,
        audioScale: widget.audioScale,
      ),
    );
  }
}
