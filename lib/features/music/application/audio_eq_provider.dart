import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kEqKey = 'audio_eq_state';

/// dB presets para cada preajuste (10 bandas). 0 = plano (unity gain).
const Map<String, List<int>> _presetDb = {
  'Plano': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'Rock': [4, 2, 0, -2, -1, 0, 1, 2, 3, 4],
  'Graves': [6, 5, 3, 1, 0, 0, 0, 0, 0, 0],
  'Voz': [0, -1, -1, 0, 3, 4, 3, 1, 0, -1],
  'Retro': [-1, 0, 2, 3, 2, 1, 0, -1, -2, -1],
};

List<String> get eqPresetNames => _presetDb.keys.toList();

double _dbToLinear(int db) => math.pow(10, db / 20).toDouble().clamp(0.0, 4.0);
int _linearToDb(double linear) {
  if (linear <= 0) return -24;
  final db = 20 * (math.log(linear) / math.ln10);
  return db.round().clamp(-12, 12);
}

class AudioEqState {
  const AudioEqState({
    this.enabled = true,
    this.preset = 'Plano',
    this.bands = const [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    this.bassBoost = false,
    this.normalize = true,
    this.reverb = 'Ninguna',
    this.speed = 1.0,
  });

  final bool enabled;
  final String preset;
  final List<double> bands; // 10 linear gains 0..4 (1 = 0dB)
  final bool bassBoost;
  final bool normalize;
  final String reverb; // Ninguna, Habitación, Catedral...
  final double speed; // 0.5 .. 2.0

  List<int> get bandsDb => bands.map(_linearToDb).toList();

  AudioEqState copyWith({
    bool? enabled,
    String? preset,
    List<double>? bands,
    bool? bassBoost,
    bool? normalize,
    String? reverb,
    double? speed,
  }) {
    return AudioEqState(
      enabled: enabled ?? this.enabled,
      preset: preset ?? this.preset,
      bands: bands ?? this.bands,
      bassBoost: bassBoost ?? this.bassBoost,
      normalize: normalize ?? this.normalize,
      reverb: reverb ?? this.reverb,
      speed: speed ?? this.speed,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'preset': preset,
        'bands': bands,
        'bassBoost': bassBoost,
        'normalize': normalize,
        'reverb': reverb,
        'speed': speed,
      };

  factory AudioEqState.fromJson(Map<String, dynamic> json) {
    final bandsRaw = json['bands'] as List?;
    return AudioEqState(
      enabled: json['enabled'] as bool? ?? true,
      preset: json['preset'] as String? ?? 'Plano',
      bands: bandsRaw != null
          ? bandsRaw.map((e) => (e as num).toDouble().clamp(0.0, 4.0)).toList().cast<double>()
          : const [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
      bassBoost: json['bassBoost'] as bool? ?? false,
      normalize: json['normalize'] as bool? ?? true,
      reverb: json['reverb'] as String? ?? 'Ninguna',
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class AudioEqController extends Notifier<AudioEqState> {
  @override
  AudioEqState build() {
    _load();
    return const AudioEqState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kEqKey);
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        state = AudioEqState.fromJson(map);
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kEqKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void setEnabled(bool v) {
    state = state.copyWith(enabled: v);
    _persist();
  }

  void setBand(int index, double linearGain) {
    final next = List<double>.from(state.bands);
    next[index] = linearGain.clamp(0.0, 4.0);
    // si edita manualmente, preset pasa a Custom
    final isPreset = _presetMatches(next);
    state = state.copyWith(bands: next, preset: isPreset ?? 'Custom');
    _persist();
  }

  void setBandDb(int index, int db) {
    setBand(index, _dbToLinear(db));
  }

  String? _presetMatches(List<double> bands) {
    for (final entry in _presetDb.entries) {
      final presetLinear = entry.value.map(_dbToLinear).toList();
      bool same = true;
      for (int i = 0; i < 10; i++) {
        if ((presetLinear[i] - bands[i]).abs() > 0.05) {
          same = false;
          break;
        }
      }
      if (same) return entry.key;
    }
    return null;
  }

  void applyPreset(String name) {
    final db = _presetDb[name];
    if (db == null) return;
    final linear = db.map(_dbToLinear).toList();
    state = state.copyWith(preset: name, bands: linear);
    _persist();
  }

  void setBassBoost(bool v) {
    state = state.copyWith(bassBoost: v);
    _persist();
  }

  void setNormalize(bool v) {
    state = state.copyWith(normalize: v);
    _persist();
  }

  void setReverb(String v) {
    state = state.copyWith(reverb: v);
    _persist();
  }

  void setSpeed(double v) {
    state = state.copyWith(speed: v.clamp(0.5, 2.0));
    _persist();
  }

  void reset() {
    state = const AudioEqState();
    _persist();
  }

  List<double> presetLinear(String name) {
    final db = _presetDb[name];
    if (db == null) return List.filled(10, 1.0);
    return db.map(_dbToLinear).toList();
  }
}

final audioEqProvider = NotifierProvider<AudioEqController, AudioEqState>(AudioEqController.new);

class EqDrawerNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void open() => state = true;
  void close() => state = false;
  void toggle() => state = !state;
}

final eqDrawerOpenProvider = NotifierProvider<EqDrawerNotifier, bool>(EqDrawerNotifier.new);
