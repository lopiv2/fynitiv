import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kEqKey = 'audio_eq_state';

/// dB presets para cada preajuste (10 bandas). 0 = plano (unity gain).
/// Bandas: 31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, 16k.
const Map<String, List<int>> _presetDb = {
  'Plano': [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  'Rock': [4, 2, 0, -2, -1, 0, 1, 2, 3, 4],
  'Graves': [6, 5, 3, 1, 0, 0, 0, 0, 0, 0],
  'Voz': [0, -1, -1, 0, 3, 4, 3, 1, 0, -1],
  'Retro': [-1, 0, 2, 3, 2, 1, 0, -1, -2, -1],
  'Pop': [-1, 0, 2, 3, 4, 3, 2, 1, 0, 1],
  'Jazz': [2, 2, 1, 2, -1, -1, 0, 1, 2, 3],
  'Clásica': [3, 2, 1, 0, -1, -1, 0, 2, 3, 4],
  'Dance': [4, 3, 1, 0, -1, -1, 0, 2, 3, 4],
  'Hip-Hop': [4, 3, 2, 1, 0, 0, 1, 0, 1, 2],
  'Electrónica': [4, 3, 1, 0, -1, 0, 1, 2, 3, 4],
  'Latina': [2, 1, 0, 2, 2, 1, 2, 3, 2, 1],
  'Acústica': [2, 1, 1, 0, 0, 1, 2, 2, 1, 0],
  'Metal': [5, 3, 1, -2, -2, 0, 2, 3, 4, 5],
  'Lounge': [-2, -1, 1, 2, 2, 1, 0, -1, -1, 0],
};

List<String> get eqPresetNames => _presetDb.keys.toList();

/// Normaliza un género para comparar (minúsculas, sin tildes, trim).
String normalizeGenre(String s) {
  var v = s.toLowerCase().trim();
  const from = 'áéíóúüñàèìòùâêîôûäëïöç';
  const to = 'aeiouunaeiooaeiouaeioc';
  for (int i = 0; i < from.length; i++) {
    v = v.replaceAll(from[i], to[i]);
  }
  return v;
}

/// Palabras clave de género (ya normalizadas) que mapean a cada preset.
/// El orden de comprobación sigue el orden de inserción del mapa.
const Map<String, List<String>> _presetGenreKeywords = {
  'Metal': ['metal', 'heavy', 'hardcore', 'punk', 'grind'],
  'Rock': ['rock', 'alternative', 'indie rock', 'pop rock', 'hard rock'],
  'Hip-Hop': ['hip hop', 'hip-hop', 'hiphop', 'rap', 'trap', 'r&b', 'rnb', 'urban'],
  'Electrónica': ['electronic', 'electronica', 'edm', 'techno', 'house', 'trance', 'dubstep', 'drum', 'dnb'],
  'Dance': ['dance', 'disco', 'dance-pop', 'dance pop', 'club'],
  'Latina': ['latin', 'latina', 'latino', 'reggaeton', 'regueton', 'salsa', 'bachata', 'merengue', 'cumbia', 'flamenco'],
  'Jazz': ['jazz', 'blues', 'swing', 'bebop', 'bossa'],
  'Clásica': ['classical', 'clasica', 'clasico', 'classic', 'orchestra', 'opera', 'baroque', 'romantic era'],
  'Pop': ['pop', 'k-pop', 'kpop', 'synthpop', 'synth pop'],
  'Acústica': ['acoustic', 'acustica', 'acustico', 'folk', 'singer', 'cantautor', 'country'],
  'Lounge': ['lounge', 'chill', 'chillout', 'ambient', 'lofi', 'lo-fi', 'bossanova', 'soul', 'funk', 'groove'],
  'Voz': ['vocal', 'voice', 'voz', 'podcast', 'spoken', 'audiobook'],
  'Retro': ['retro', 'oldies', '80s', '70s', '60s', 'vintage', 'rock and roll', 'rock n roll'],
  'Graves': ['bass', 'graves', 'subbass', 'sub bass', 'dembow'],
};

/// Resultado del matching de Auto-EQ: preset a aplicar y género
/// original de la canción con el que coincidió.
class AutoEqMatch {
  const AutoEqMatch({required this.preset, required this.genre});

  final String preset;
  final String genre;
}

/// Devuelve el preset que mejor coincide con la lista de géneros, junto al
/// género original que produjo la coincidencia, o null si no hay match.
AutoEqMatch? presetForGenres(List<String>? genres) {
  if (genres == null || genres.isEmpty) return null;
  final normalized = genres.map(normalizeGenre).where((e) => e.isNotEmpty).toList();
  if (normalized.isEmpty) return null;
  for (final entry in _presetGenreKeywords.entries) {
    if (!_presetDb.containsKey(entry.key)) continue;
    for (int gi = 0; gi < normalized.length; gi++) {
      final g = normalized[gi];
      for (final kw in entry.value) {
        final k = kw.trim().toLowerCase();
        if (k.isEmpty) continue;
        if (g == k || g.contains(k)) {
          return AutoEqMatch(preset: entry.key, genre: genres[gi]);
        }
      }
    }
  }
  return null;
}

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
    this.autoEq = false,
  });

  final bool enabled;
  final String preset;
  final List<double> bands; // 10 linear gains 0..4 (1 = 0dB)
  final bool bassBoost;
  final bool normalize;
  final String reverb; // Ninguna, Habitación, Catedral...
  final double speed; // 0.5 .. 2.0
  final bool autoEq;

  List<int> get bandsDb => bands.map(_linearToDb).toList();

  AudioEqState copyWith({
    bool? enabled,
    String? preset,
    List<double>? bands,
    bool? bassBoost,
    bool? normalize,
    String? reverb,
    double? speed,
    bool? autoEq,
  }) {
    return AudioEqState(
      enabled: enabled ?? this.enabled,
      preset: preset ?? this.preset,
      bands: bands ?? this.bands,
      bassBoost: bassBoost ?? this.bassBoost,
      normalize: normalize ?? this.normalize,
      reverb: reverb ?? this.reverb,
      speed: speed ?? this.speed,
      autoEq: autoEq ?? this.autoEq,
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
        'autoEq': autoEq,
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
      autoEq: json['autoEq'] as bool? ?? false,
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
    // si edita manualmente, preset pasa a Custom y se desactiva el Auto-EQ
    // para que la siguiente canción no pise el ajuste.
    final isPreset = _presetMatches(next);
    state = state.copyWith(
      bands: next,
      preset: isPreset ?? 'Custom',
      autoEq: false,
    );
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

  /// Aplica las bandas del preset sin tocar el flag de Auto-EQ.
  /// La ruta automática la usa; la manual pasa por [applyPreset].
  void _applyPresetBands(String name) {
    final db = _presetDb[name];
    if (db == null) return;
    final linear = db.map(_dbToLinear).toList();
    state = state.copyWith(preset: name, bands: linear);
    _persist();
  }

  void applyPreset(String name) {
    if (!_presetDb.containsKey(name)) return;
    // Ajuste manual: manda sobre el Auto-EQ y lo desactiva para que la
    // siguiente canción no pise lo que acaba de elegir el usuario.
    final wasAuto = state.autoEq;
    _applyPresetBands(name);
    if (wasAuto) {
      state = state.copyWith(autoEq: false);
      _persist();
    }
  }

  void setAutoEq(bool v) {
    if (!v) {
      // Al quitar el Auto-EQ: Sonido OFF + preset Plano (sonido neutro).
      final flat = _presetDb['Plano']!.map(_dbToLinear).toList();
      state = state.copyWith(
        autoEq: false,
        enabled: false,
        preset: 'Plano',
        bands: flat,
      );
      _persist();
      return;
    }
    // Al encenderlo: Sonido ON para que el preset detectado suene.
    // El preset lo aplica el llamador según el género (ver
    // applyAutoEqForGenres).
    state = state.copyWith(autoEq: true, enabled: true);
    _persist();
  }

  /// Aplica el preset correspondiente a los géneros si [autoEq] está activo.
  /// Devuelve el match (preset + género coincidente), o null si no hay
  /// coincidencia (o si autoEq está desactivado).
  AutoEqMatch? applyAutoEqForGenres(List<String>? genres) {
    if (!state.autoEq) return null;
    final match = presetForGenres(genres);
    if (match == null) return null;
    // Ruta automática: no toca el flag (ver _applyPresetBands).
    _applyPresetBands(match.preset);
    return match;
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
