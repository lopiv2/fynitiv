import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Sala raymarcheada con 16 luces de colores adaptada del shader de
/// Shadertoy "Audio Visualizer - Raymarching" (Xd3GRX), replicada en
/// 2.5D con `CustomPainter` en lugar de un shader de Flutter (un
/// raymarcher por píxel no es viable a 60fps en Canvas).
///
/// Elementos del shader original que se conservan:
/// - Habitación en perspectiva: pared del fondo + suelo/techo/laterales.
/// - 16 luces en fila cuya altura la marca su banda de frecuencia
///   (`lp[i].y = hArr[i]*2-1`) y cuyo color sale del degradado
///   teal → azul → rojo (`Color1/2/3` con `GRADVAL 0.8`).
/// - Las luces iluminan la pared (pozas de luz) y brillan como orbes.
/// - Cinta de onda flotante (`ENABLEWAVE`, gris 0.3).
/// - Viñeta oscura en los bordes.
///
/// Se alimenta de FFT real de SoLoud cuando está disponible (música) o de
/// FFT sintética en radio (ver `FakeRaymarchVisualizer` en
/// `audio_waveform.dart`).
class RaymarchPainter extends CustomPainter {
  RaymarchPainter({
    required this.fft,
    required this.wave,
    this.audioScale = 1.8,
    this.minBin = 1,
    this.maxBin = 120,
  });

  final Float32List fft;
  final Float32List wave;
  final double audioScale;
  final int minBin;
  final int maxBin;

  static const int lights = 16;

  static const Color _teal = Color(0xFF409F9F);
  static const Color _blue = Color(0xFF4040FF);
  static const Color _red = Color(0xFFFF4040);

  /// Degradado del shader con `GRADVAL 0.8`: teal → azul → rojo.
  static Color lightColor(double v) {
    final t = v.clamp(0.0, 1.0);
    if (t < 0.8) {
      return Color.lerp(_teal, _blue, t / 0.8)!;
    }
    return Color.lerp(_blue, _red, (t - 0.8) / 0.2)!;
  }

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

  double _waveAt(double t) {
    if (wave.isEmpty) return 0;
    final idx = (t * (wave.length - 1)).clamp(0, wave.length - 1).round();
    return wave[idx].clamp(-1.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.52;

    // Habitación en perspectiva: pared del fondo + quads + aristas.
    final wallW = w * 0.44;
    final wallH = h * 0.64;
    final wall = Rect.fromCenter(center: Offset(cx, cy), width: wallW, height: wallH);
    canvas.drawRect(wall, Paint()..color = const Color(0xFF0A0D13));
    canvas.drawRect(
      wall,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.07),
    );
    final corners = [
      wall.topLeft, wall.topRight, wall.bottomRight, wall.bottomLeft,
      const Offset(0, 0), Offset(w, 0), Offset(w, h), Offset(0, h),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        corners[i],
        corners[i + 4],
        Paint()
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.05),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(0, h)
        ..lineTo(w, h)
        ..lineTo(wall.bottomRight.dx, wall.bottomRight.dy)
        ..lineTo(wall.bottomLeft.dx, wall.bottomLeft.dy)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.025),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w, 0)
        ..lineTo(wall.topRight.dx, wall.topRight.dy)
        ..lineTo(wall.topLeft.dx, wall.topLeft.dy)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.02),
    );

    // Niveles de las 16 bandas.
    final levels = List<double>.generate(lights, (i) => _bin(i, lights));

    // Pozas de luz sobre la pared (iluminación de la sala).
    for (var i = 0; i < lights; i++) {
      final v = levels[i];
      if (v < 0.03) continue;
      final color = lightColor(v);
      final px = wall.left + (i + 0.5) / lights * wall.width;
      final py = cy - v * wall.height * 0.38;
      final radius = wall.width * 0.20;
      canvas.drawCircle(
        Offset(px, py),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.10 + v * 0.22),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(px, py), radius: radius)),
      );
    }

    // Cinta de onda flotante (gris 0.3 del shader).
    const wavePoints = 64;
    final wavePath = Path();
    final ribbonY = cy + h * 0.24;
    for (var j = 0; j <= wavePoints; j++) {
      final t = j / wavePoints;
      final px = t * w;
      final py = ribbonY - _waveAt(t) * h * 0.16;
      if (j == 0) {
        wavePath.moveTo(px, py);
      } else {
        wavePath.lineTo(px, py);
      }
    }
    const waveGrey = Color(0xFF4D4D4D);
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = waveGrey.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      wavePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = waveGrey.withValues(alpha: 0.85),
    );

    // Fila de 16 orbes de luz, contenida dentro de la pared del fondo
    // (antes ocupaba todo el ancho). El resplandor sí puede sangrar fuera.
    const orbInset = 10.0;
    for (var i = 0; i < lights; i++) {
      final v = levels[i];
      final color = lightColor(v);
      final px =
          wall.left + orbInset + (i + 0.5) / lights * (wall.width - orbInset * 2);
      final py = (cy - v * wall.height * 0.42)
          .clamp(wall.top + 6, wall.bottom - 6);
      final glowR = 9 + v * 26;
      canvas.drawCircle(
        Offset(px, py),
        glowR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.25 + v * 0.35),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset(px, py), radius: glowR)),
      );
      canvas.drawCircle(
        Offset(px, py),
        2.2 + v * 4.2,
        Paint()..color = color.withValues(alpha: 0.65 + v * 0.35),
      );
      canvas.drawCircle(
        Offset(px, py),
        1.2 + v * 1.8,
        Paint()..color = Colors.white.withValues(alpha: 0.55 + v * 0.4),
      );
    }

    // Viñeta oscura en los bordes.
    final vigR = math.max(w, h) * 0.72;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0),
          radius: 1.0,
          colors: const [Colors.transparent, Color(0x99000000)],
          stops: const [0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: vigR)),
    );
  }

  @override
  bool shouldRepaint(covariant RaymarchPainter oldDelegate) => true;
}

/// Visualizador Raymarching con FFT + onda reales de SoLoud
/// (música / music player).
class RaymarchVisualizer extends StatefulWidget {
  const RaymarchVisualizer({super.key});

  @override
  State<RaymarchVisualizer> createState() => _RaymarchVisualizerState();
}

class _RaymarchVisualizerState extends State<RaymarchVisualizer> {
  StreamSubscription? _sub;
  Float32List _fft = Float32List(256);
  Float32List _wave = Float32List(512);

  @override
  void initState() {
    super.initState();
    try {
      SoLoud.instance.setVisualizationEnabled(true);
      SoLoud.instance.setFftSmoothing(0.85);
    } catch (_) {}
    _sub = SoLoud.instance.audioVisualizationEvents.listen((data) {
      if (!mounted) return;
      setState(() {
        if (data.fftData != null) _fft = data.fftData!;
        if (data.waveData != null) _wave = data.waveData!;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: RaymarchPainter(fft: _fft, wave: _wave),
    );
  }
}
