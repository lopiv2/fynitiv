import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Espectro LED 2D adaptado del shader de Shadertoy "2D LED Spectrum"
/// (uNiversal, basado en simesgreen), replicado con `CustomPainter` en
/// lugar de un shader de Flutter.
///
/// Reglas del shader original:
/// - Coordenadas cuantizadas en `bands` × `segs` (una celda = un led).
/// - FFT por banda leída de la primera fila de la textura.
/// - Color `mix(verde, rojo, sqrt(uv.y))`: verde abajo, rojo arriba,
///   pasando por amarillo/naranja.
/// - Máscara `p.y < fft ? 1.0 : 0.1`: leds encendidos a pleno color,
///   apagados tenues al 10%.
/// - Celda led redondeada con hueco oscuro entre celdas (smoothstep).
///
/// Se alimenta de FFT real de SoLoud cuando está disponible (música) o de
/// FFT sintética en radio (ver `FakeLedSpectrumVisualizer` en
/// `audio_waveform.dart`).
class LedSpectrumPainter extends CustomPainter {
  LedSpectrumPainter({
    required this.fft,
    this.barCount = 30,
    this.segments = 28,
    this.audioScale = 1.8,
    this.minBin = 1,
    this.maxBin = 120,
  });

  final Float32List fft;
  final int barCount;
  final int segments;
  final double audioScale;
  final int minBin;
  final int maxBin;

  static const Color _green = Color(0xFF00FF00);
  static const Color _red = Color(0xFFFF0000);

  /// Color led del shader: `mix(vec3(0,2,0), vec3(2,0,0), sqrt(uv.y))`
  /// (t = 0 abajo, 1 arriba; se recorta a rango visible).
  static Color ledColor(double t) {
    final k = math.sqrt(t.clamp(0.0, 1.0));
    return Color.lerp(_green, _red, k)!;
  }

  double _barValue(int bar) {
    if (fft.isEmpty || barCount <= 0) return 0;
    final effMax = maxBin.clamp(0, fft.length - 1);
    final effMin = minBin.clamp(0, effMax);
    final range = (effMax - effMin + 1).clamp(1, fft.length);
    final chunk = range / barCount;
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
    if (size.isEmpty || barCount <= 0 || segments <= 0) return;
    final barWidth = size.width / barCount;
    // Celda led con hueco oscuro alrededor (smoothstep del shader).
    final ledW = (barWidth * 0.8).clamp(2.0, barWidth);
    final segH = size.height / segments;
    final ledH = segH * 0.7;
    final radius = Radius.circular((ledH * 0.28).clamp(1.0, 3.0));
    for (var i = 0; i < barCount; i++) {
      final value = _barValue(i);
      // Máscara del shader: segmentos por debajo del nivel FFT encendidos.
      final lit = (value * segments).floor().clamp(0, segments);
      final x = i * barWidth + (barWidth - ledW) / 2;
      for (var s = 0; s < segments; s++) {
        final t = segments == 1 ? 1.0 : s / (segments - 1);
        final color = ledColor(t);
        // Segmento 0 abajo: y crece hacia arriba.
        final y = size.height - (s + 1) * segH + (segH - ledH) / 2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, ledW, ledH), radius),
          Paint()
            ..color = s < lit ? color : color.withValues(alpha: 0.1),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant LedSpectrumPainter oldDelegate) => true;
}

/// Visualizador LED con FFT real de SoLoud (música / music player).
class LedSpectrumVisualizer extends StatefulWidget {
  const LedSpectrumVisualizer({super.key, this.audioScale = 1.1});

  final double audioScale;

  @override
  State<LedSpectrumVisualizer> createState() => _LedSpectrumVisualizerState();
}

class _LedSpectrumVisualizerState extends State<LedSpectrumVisualizer> {
  StreamSubscription? _sub;
  Float32List _fft = Float32List(256);

  @override
  void initState() {
    super.initState();
    try {
      SoLoud.instance.setVisualizationEnabled(true);
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
    return CustomPaint(
      size: Size.infinite,
      painter: LedSpectrumPainter(fft: _fft, audioScale: widget.audioScale),
    );
  }
}
