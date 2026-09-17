import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Espectro circular estilo las imágenes de referencia: 3 anillos
/// concéntricos de barras radiales que crecen hacia fuera con la FFT,
/// con tono cian arriba → magenta abajo, resplandor central blanco-magenta
/// y paneles laterales de matriz de puntos. Replicado con `CustomPainter`
/// en lugar de un shader de Flutter.
///
/// Se alimenta de FFT real de SoLoud cuando está disponible (música) o de
/// FFT sintética en radio (ver `FakeCircularSpectrumVisualizer` en
/// `audio_waveform.dart`).
class CircularSpectrumPainter extends CustomPainter {
  CircularSpectrumPainter({
    required this.fft,
    this.audioScale = 1.1,
    this.minBin = 1,
    this.maxBin = 120,
  });

  final Float32List fft;
  final double audioScale;
  final int minBin;
  final int maxBin;

  static const List<double> ringFractions = [1.0, 0.62, 0.36];
  static const List<int> _ringBars = [120, 84, 48];

  /// Escala de las barras por anillo, de fuera hacia dentro, tomando
  /// `audioScale` como referencia del anillo exterior: el central es el
  /// más pequeño y crece hacia el exterior.
  static const List<double> _ringScales = [1.0, 0.65, 0.4];

  /// Valor de una banda del anillo exterior (120 barras, bins 1..120),
  /// igual que el usado al pintar. Sirve para calcular el color
  /// dominante sin necesidad de instancia.
  static double binValue(Float32List fft, int bar, int bars,
      {double audioScale = 1.8}) {
    if (fft.isEmpty || bars <= 0) return 0;
    const minBin = 1;
    const maxBin = 120;
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

  /// Color de la banda más fuerte del anillo exterior: es el que tiñe
  /// la imagen de flare central.
  static Color dominantColor(Float32List fft) {
    var best = 0.0;
    var bestI = 0;
    for (var i = 0; i < _ringBars[0]; i++) {
      final v = binValue(fft, i, _ringBars[0]);
      if (v > best) {
        best = v;
        bestI = i;
      }
    }
    final fromTop = bestI / _ringBars[0] * math.pi * 2;
    final rel = fromTop > math.pi ? fromTop - math.pi * 2 : fromTop;
    return barColor(rel, 1.0);
  }

  /// Nivel de graves (media de los 8 primeros bins).
  static double bassLevel(Float32List fft) {
    if (fft.isEmpty) return 0;
    final end = 8.clamp(0, fft.length);
    double sum = 0;
    for (var k = 0; k < end; k++) {
      sum += fft[k];
    }
    return (sum / end * 1.8).clamp(0.0, 1.0);
  }

  /// Tono por ángulo: cian arriba → magenta abajo (simétrico).
  static Color barColor(double angleFromTop, double value) {
    final k = (angleFromTop.abs() / math.pi).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(
      0.45 + value * 0.55,
      190 + 110 * k,
      1,
      0.55 + 0.45 * value,
    ).toColor();
  }

  double _bass() => bassLevel(fft);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final baseR = math.min(w, h) * 0.34;
    if (baseR <= 0) return;
    final bass = _bass();

    // Círculos base tenues de cada anillo.
    for (var r = 0; r < ringFractions.length; r++) {
      canvas.drawCircle(
        center,
        baseR * ringFractions[r],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF5AA0FF).withValues(alpha: 0.18),
      );
    }

    // Anillos de barras radiales simétricas respecto al anillo base:
    // mitad hacia fuera y mitad hacia dentro.
    for (var r = 0; r < ringFractions.length; r++) {
      final r0 = baseR * ringFractions[r];
      final count = _ringBars[r];
      final ringScale = _ringScales[r.clamp(0, _ringScales.length - 1)];
      final maxLen = baseR * (r == 0 ? 0.45 : 0.38);
      final barW =
          ((2 * math.pi * r0 / count) * 0.55).clamp(1.5, 4.0).toDouble();
      for (var i = 0; i < count; i++) {
        final v = (binValue(fft, i, count,
                audioScale: audioScale * ringScale))
            .clamp(0.0, 1.0);
        // Ángulo desde arriba, en sentido horario.
        final a = -math.pi / 2 + i * math.pi * 2 / count;
        final fromTop = (i / count * math.pi * 2);
        final rel = fromTop > math.pi ? fromTop - math.pi * 2 : fromTop;
        final dir = Offset(math.cos(a), math.sin(a));
        final len = 1.5 + v * maxLen;
        final half = len / 2;
        canvas.drawLine(
          center + dir * (r0 - half),
          center + dir * (r0 + half),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = barW
            ..strokeCap = StrokeCap.butt
            ..color = barColor(rel, v),
        );
      }
    }

    // Resplandor central blanco-magenta que pulsa con los graves.
    final glowR = baseR * 0.30 * (1 + bass * 0.35);
    canvas.drawCircle(
      center,
      glowR,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFE040FB),
            Color(0x00000000),
          ],
          stops: [0.0, 0.35, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowR)),
    );

  }

  @override
  bool shouldRepaint(covariant CircularSpectrumPainter oldDelegate) => true;
}

/// Visualizador CircularSpectrum con FFT real de SoLoud
/// (música / music player).
class CircularSpectrumVisualizer extends StatefulWidget {
  const CircularSpectrumVisualizer({super.key});

  @override
  State<CircularSpectrumVisualizer> createState() =>
      _CircularSpectrumVisualizerState();
}

class _CircularSpectrumVisualizerState
    extends State<CircularSpectrumVisualizer> {
  StreamSubscription? _sub;
  Float32List _fft = Float32List(256);

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
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          size: Size.infinite,
          painter: CircularSpectrumPainter(fft: _fft),
        ),
        CircularFlare(fft: _fft),
      ],
    );
  }
}

/// Flare central del espectro circular: imagen `flare_01.png` tintada
/// con el color de la banda más fuerte del anillo exterior, pulsando
/// con los graves. Se superpone al pintor en música y radio.
class CircularFlare extends StatelessWidget {
  const CircularFlare({super.key, required this.fft});

  final Float32List fft;

  @override
  Widget build(BuildContext context) {
    final bass = CircularSpectrumPainter.bassLevel(fft);
    return LayoutBuilder(
      builder: (context, constraints) {
        final baseR =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.34;
        if (baseR <= 0) return const SizedBox.shrink();
        final size = baseR * 2.1 * (1 + bass * 0.25);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Image.asset(
              'assets/images/flares/flare_01.png',
              color: CircularSpectrumPainter.dominantColor(fft),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
