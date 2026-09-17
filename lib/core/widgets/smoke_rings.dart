import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Anillos de humo adaptados del shader de Shadertoy "Smoke Rings"
/// (dlK3RW, a partir de 4dVXDt), replicados con `CustomPainter` en lugar
/// de un shader de Flutter.
///
/// Reglas del shader original (`COLOR_MODE 3`, `USEMIC`, 18 anillos):
/// - Los 18 anillos comparten el mismo radio base (`uSize`) y se
///   diferencian en distorsión (`amp = 0.1 + frac³·0.7`: los exteriores
///   se deforman más), fase y color.
/// - Cada anillo muestrea dos puntos de audio decorrelacionados (graves y
///   agudos) que modulan las direcciones, fases y amplitud de dos ondas
///   `sin·cos` que deforman el anillo.
/// - Color por anillo `lerp(naranja, verde, frac³)` (t1/t2 del modo 3).
/// - Todo el conjunto oscila con el tiempo (`xoff`) y las ondas llevan
///   el tiempo (`iTime`).
/// - Fondo negro: en silencio los anillos se apagan.
///
/// Se alimenta de FFT real de SoLoud cuando está disponible (música) o de
/// FFT sintética en radio (ver `FakeSmokeRingsVisualizer` en
/// `audio_waveform.dart`).
class SmokeRingsPainter extends CustomPainter {
  SmokeRingsPainter({
    required this.fft,
    this.time = 0,
    this.rings = 18,
    this.audioScale = 1.8,
  });

  final Float32List fft;

  /// Tiempo de animación en segundos (equivale a `iTime` del shader).
  final double time;
  final int rings;
  final double audioScale;

  static const Color _inner = Color(0xFFE6804D); // t1 = 1-(0.1,0.5,0.7)
  static const Color _outer = Color(0xFF33E633); // t2 = 1-(0.8,0.1,0.8)

  /// Muestra la FFT en coordenada normalizada 0..1 (como la textura del
  /// shader). Se reparte en mitad grave y mitad aguda para tener dos
  /// puntos decorrelacionados con energía musical real.
  double _sample(double nx) {
    if (fft.isEmpty) return 0;
    final t = nx.clamp(0.0, 1.0);
    final half = (fft.length / 2).floor().clamp(1, fft.length);
    final idx = t < 0.5
        ? (t * 2 * (half - 1)).floor().clamp(0, half - 1)
        : (half + ((t - 0.5) * 2 * (fft.length - half - 1)).floor())
            .clamp(half, fft.length - 1);
    return (fft[idx] * audioScale).clamp(0.0, 1.0);
  }

  static double _waves(
    double cx,
    double cy,
    double m1x,
    double m1y,
    double m2x,
    double m2y,
    double phx,
    double phy,
    double tmx,
    double tmy,
    double time,
  ) {
    return 0.5 *
        (math.sin(cx * m1x + cy * m1y + tmx * time + phx) +
            math.cos(cx * m2x + cy * m2y + tmy * time + phy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || rings <= 0) return;
    final w = size.width;
    final h = size.height;
    // Centro como el shader (0.5, 0.26 en unidades de ancho), limitado
    // para que los arcos sigan visibles en paneles muy apaisados.
    final cx = w * 0.5 + _xoff * w * 0.06;
    final cy = math.min(w * 0.26, h * 0.85);
    // Radio base `uSize` en unidades de ancho.
    final radius = w * 0.2;
    if (radius <= 0) return;

    const points = 64;
    for (var i = 0; i < rings; i++) {
      final frac = rings == 1 ? 0.0 : i / rings;
      final amp = 0.1 + math.pow(frac, 3) * 0.7;
      final phase = math.pow(1 - frac, 0.2) * 0.09;
      // Dos puntos de audio decorrelacionados (grave y agudo).
      final n1 = _sample(phase * 0.5);
      final n2r = _sample(0.5 + (1 - phase) * 0.5);
      final n2g = _sample(0.5 + (1 - phase) * 0.45);
      final n2b = _sample(0.5 + (1 - phase) * 0.4);
      final sharp = (n1 * (n2r + n2g + n2b) / 3).clamp(0.0, 1.0);
      final bright = (0.06 + sharp * 5).clamp(0.0, 1.0);
      if (bright < 0.02) continue;
      final color = Color.lerp(_inner, _outer, math.pow(frac, 3).toDouble())!;

      final path = Path();
      for (var j = 0; j <= points; j++) {
        final a = j / points * math.pi * 2;
        // Punto base del anillo en unidades de ancho.
        final bx = math.cos(a) * 0.2;
        final by = math.sin(a) * 0.2;
        final w1 = _waves(
          bx, by,
          (1.9 + 0.4 * n1) * 3.3, (1.9 + 0.4 * n1) * 3.3,
          (5.7 + 1.4 * n1) * 2.8, (5.7 + 1.4 * n2r) * 2.8,
          (n1 - n2r) * 5.0, (n1 + n2b) * 5.0,
          1.1, 1.1, time,
        );
        final w2 = _waves(
          bx, by,
          (-1.7 - 0.9 * n2g) * 3.1, (1.7 + 0.9 * n2b) * 3.1,
          (5.9 + 0.8 * n1) * 3.7, (-5.9 - 0.8 * n1) * 3.7,
          (n1 + n2g) * 5.0, (n1 - n2r) * 5.0,
          -0.9, -0.9, time,
        );
        final dx = _xoff + 0.6 * w1;
        final dy = 0.5 + 0.4 * w2;
        final mag = (n1 * 0.2 + 0.6 * (dx.abs() + dy.abs())) * amp * 0.2;
        final len = math.sqrt(dx * dx + dy * dy);
        final nx = len > 0 ? dx / len : 1.0;
        final ny = len > 0 ? dy / len : 0.0;
        final px = cx + (bx + nx * mag) * w;
        final py = cy + (by + ny * mag) * w;
        if (j == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();
      // Banda de humo ancha y tenue (sin blur: el ancho ya suaviza y el
      // MaskFilter por trazo era el mayor coste de GPU) + núcleo definido,
      // con mezcla normal para que los cruces no florezcan a blanco.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (radius * 0.45).clamp(4.0, 64.0)
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: 0.05 + bright * 0.16),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: 0.20 + bright * 0.65),
      );
    }
  }

  double get _xoff =>
      0.5 * (0.9 * math.cos(time * 0.6 + 1.1) + 0.4 * math.cos(time * 2.4));

  @override
  bool shouldRepaint(covariant SmokeRingsPainter oldDelegate) => true;
}

/// Visualizador SmokeRings con FFT real de SoLoud (música / music player).
/// El tiempo avanza de forma continua.
class SmokeRingsVisualizer extends StatefulWidget {
  const SmokeRingsVisualizer({super.key});

  @override
  State<SmokeRingsVisualizer> createState() => _SmokeRingsVisualizerState();
}

class _SmokeRingsVisualizerState extends State<SmokeRingsVisualizer>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  Float32List _fft = Float32List(256);
  late final Ticker _ticker;
  double _time = 0;
  double _pending = 0;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    try {
      SoLoud.instance.setVisualizationEnabled(true);
      SoLoud.instance.setFftSmoothing(0.85);
    } catch (_) {}
    // La FFT solo se almacena: el repintado lo marca el ticker limitado
    // a ~30fps para no saturar la CPU/GPU.
    _sub = SoLoud.instance.audioVisualizationEvents.listen((data) {
      if (data.fftData != null) _fft = data.fftData!;
    });
    _ticker = createTicker((elapsed) {
      final dt = _lastTick == null
          ? 0.016
          : (elapsed - _lastTick!).inMicroseconds / 1e6;
      _lastTick = elapsed;
      _pending += dt;
      if (_pending < 1 / 30 || !mounted) return;
      setState(() {
        _time += _pending;
        _pending = 0;
      });
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
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: SmokeRingsPainter(fft: _fft, time: _time),
      ),
    );
  }
}
