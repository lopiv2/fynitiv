import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../music/application/soloud_music_provider.dart';

bool _isRadioPlaying(Ref ref) {
  final s = ref.read(soloudMusicProvider);
  return s.playing && s.session?.itemId == 'radio';
}

/// Señal de audio sintética para la radio (FFT).
///
/// La radio suele reproducirse vía MediaKit (HLS o fallback de SoLoud),
/// por lo que no hay FFT real de SoLoud para el efecto `frequency`.
/// Este provider emite una FFT falsa suavizada (~16fps) con envolvente
/// de "beat". Solo avanza cuando la radio está en play; en pausa congela
/// el último frame.
class RadioFakeSignalController extends Notifier<Float32List> {
  Timer? _timer;
  final _rng = math.Random();
  double _beatPhase = 0;

  @override
  Float32List build() {
    ref.keepAlive();
    _timer ??= Timer.periodic(const Duration(milliseconds: 60), (_) => _tick());
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return Float32List.fromList(List.filled(64, 0.25));
  }

  void _tick() {
    if (!_isRadioPlaying(ref)) return;
    _beatPhase += 60 / 1000 * 2 * math.pi * 2.0; // ~120bpm
    final beat = (0.5 + 0.5 * math.sin(_beatPhase)) * 0.45;
    final prev = state;
    final next = Float32List(64);
    for (var i = 0; i < 64; i++) {
      final bass = i < 10 ? beat * (1 - i / 10) : 0.0;
      final target = (_rng.nextDouble() * 0.55 + 0.12 + bass).clamp(0.0, 1.0);
      // Random-walk suavizado: evita el jitter del random puro.
      next[i] = (prev[i] + (target - prev[i]) * 0.35).clamp(0.05, 1.0);
    }
    state = next;
  }
}

final radioFakeSignalProvider =
    NotifierProvider<RadioFakeSignalController, Float32List>(
      RadioFakeSignalController.new,
    );

/// Señal de onda sintética para la radio (dominio temporal, -1..1).
///
/// Alimenta el mismo pintor `Waveform` de audio_flux que usa el Music
/// player (`FluxType.waveform`), para que el efecto `audioFlux` se vea
/// idéntico aunque la radio vaya por MediaKit sin SoLoud. Suma de senos
/// con envolvente de beat; solo avanza en play.
class RadioFakeWaveController extends Notifier<Float32List> {
  Timer? _timer;
  final _rng = math.Random();
  double _t = 0;

  @override
  Float32List build() {
    ref.keepAlive();
    _timer ??= Timer.periodic(const Duration(milliseconds: 60), (_) => _tick());
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    return Float32List(512);
  }

  void _tick() {
    if (!_isRadioPlaying(ref)) return;
    _t += 0.06;
    final beat = 0.55 + 0.45 * math.sin(_t * 2 * math.pi * 2.0);
    final next = Float32List(512);
    for (var i = 0; i < 512; i++) {
      final v =
          math.sin(i * 0.15 + _t * 3.0) * 0.4 +
          math.sin(i * 0.05 - _t * 1.7) * 0.3 +
          math.sin(i * 0.30 + _t * 5.2) * 0.15 +
          (_rng.nextDouble() - 0.5) * 0.08;
      next[i] = (v * (0.45 + beat * 0.55)).clamp(-1.0, 1.0);
    }
    state = next;
  }
}

final radioFakeWaveProvider =
    NotifierProvider<RadioFakeWaveController, Float32List>(
      RadioFakeWaveController.new,
    );
