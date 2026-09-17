import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Ondas sinusoidales de sonido adaptadas del shader de Shadertoy
/// "Sound sinus wave" (XsX3zS), replicado con `CustomPainter` en lugar
/// de un shader de Flutter.
///
/// Reglas del shader original (WAVES = 8, 9 ondas de i = 0..8):
/// - `freq = FFT(i/8) * 7`: cada onda la modula su banda de frecuencia.
/// - Desplazamiento `sin(x*10+t) * cos(x*2) * freq*0.2 * ((i+1)/8)`.
/// - Brillo `|0.01/y| * clamp(freq, 0.35, 2.0)`: las ondas se ven tenues
///   en silencio y arden con la música.
/// - Color por onda `(i/5, 0.5, 1.75)`: del azul (i=0) al magenta (i=8).
///
/// Se alimenta de FFT real de SoLoud cuando está disponible (música) o de
/// FFT sintética en radio (ver `FakeSoundSinusVisualizer` en
/// `audio_waveform.dart`).
class SoundSinusPainter extends CustomPainter {
  SoundSinusPainter({
    required this.fft,
    this.time = 0,
    this.waves = 9,
    this.audioScale = 1.0,
    this.minBin = 1,
    this.maxBin = 120,
  });

  final Float32List fft;

  /// Tiempo de animación en segundos (equivale a `iTime` del shader).
  final double time;
  final int waves;
  final double audioScale;
  final int minBin;
  final int maxBin;

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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || waves <= 0) return;
    const points = 100;
    for (var i = 0; i < waves; i++) {
      final freq = _bin(i, waves) * 7.0;
      final amp = freq * 0.2 * ((i + 1) / waves);
      final brightness = freq.clamp(0.35, 2.0) * (3.0 / waves);
      final base = Color.fromRGBO(
        ((1.0 * (i / 5) * brightness).clamp(0.0, 1.0) * 255).round(),
        ((0.5 * brightness).clamp(0.0, 1.0) * 255).round(),
        ((1.75 * brightness).clamp(0.0, 1.0) * 255).round(),
        1,
      );
      final path = Path();
      for (var j = 0; j <= points; j++) {
        final x = -1.1 + 2.2 * j / points;
        final xp = x + i * 0.04 + freq * 0.03;
        final y =
            -(math.sin(xp * 10 + time) * math.cos(xp * 2) * amp).clamp(
              -1.2,
              1.2,
            );
        final px = (x + 1.1) / 2.2 * size.width;
        final py = size.height / 2 - y * size.height * 0.45;
        if (j == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      // Bloom como el efecto real: el shader acumula las 9 ondas de forma
      // aditiva (`color += ...` + realce `luma - 1`), así que los cruces
      // queman a blanco. Se replica con `BlendMode.plus` en 3 pasadas:
      // halo exterior, resplandor medio (caída 1/|y|) y núcleo nítido.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..blendMode = BlendMode.plus
          ..color = base.withValues(alpha: 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..blendMode = BlendMode.plus
          ..color = base.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..blendMode = BlendMode.plus
          ..color = Color.lerp(base, const Color(0xFFFFFFFF), 0.25)!
              .withValues(alpha: 0.95),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SoundSinusPainter oldDelegate) => true;
}

/// Visualizador SoundSinus con FFT real de SoLoud (música / music player).
/// El tiempo avanza de forma continua.
class SoundSinusVisualizer extends StatefulWidget {
  const SoundSinusVisualizer({super.key});

  @override
  State<SoundSinusVisualizer> createState() => _SoundSinusVisualizerState();
}

class _SoundSinusVisualizerState extends State<SoundSinusVisualizer>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  Float32List _fft = Float32List(256);
  late final Ticker _ticker;
  double _time = 0;
  Duration? _lastTick;

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
        setState(() => _time += dt);
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
      painter: SoundSinusPainter(fft: _fft, time: _time),
    );
  }
}
