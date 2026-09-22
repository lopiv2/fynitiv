import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:http/http.dart' as http;

import 'soloud_initializer.dart';

/// Estado de un reproductor monofónico simple.
enum SoloudSingleState { idle, playing, paused, completed }

/// Reproductor monofónico sobre la instancia global de SoLoud.
///
/// Sustituye los usos puntuales de `audioplayers` (splash, hover, fondos de
/// juego, OST del detalle): una sola voz, volumen propio, callback de fin
/// vía sondeo del handle (como `soloud_music_provider`) y reutilización de
/// la fuente cargada entre pistas iguales.
///
/// Los assets comparten una caché global: precalentarla con
/// [preloadAssets] al arrancar elimina el delay de decodificación del
/// primer `play` (los mp3 se decodifican completos en `loadAsset`).
class SoloudSinglePlayer {
  SoloudSinglePlayer({this.volume = 1.0});

  /// Volumen por defecto 0..1 para las reproducciones.
  double volume;

  /// Se invoca una vez cuando la voz actual termina de forma natural.
  VoidCallback? onComplete;

  /// Caché compartida de assets (vive toda la app, no se libera).
  static final Map<String, AudioSource> _assetCache = {};

  AudioSource? _source;
  String? _sourceId; // 'asset:<ruta>' | 'url:<url>'
  bool _ownsSource = false; // true = URL propia (hay que liberarla)
  SoundHandle? _handle;
  Timer? _endTimer;
  SoloudSingleState state = SoloudSingleState.idle;
  bool _disposed = false;
  // Generación de carga: solo la última llamada a playAsset/playUrl puede
  // lanzar la voz. Sin esto, dos cargas solapadas (p.ej. resume durante la
  // descarga lenta de un FLAC) lanzan DOS voces y solo una queda trackeada:
  // la otra suena huérfana y `stop()` ya no la alcanza.
  int _loadGen = 0;

  bool get _ready =>
      SoloudInitializer.isInitialized && SoLoud.instance.isInitialized;

  /// Decodifica assets a la caché compartida para que el primer `play`
  /// arranque sin delay. No bloquea: llamar sin `await`.
  Future<void> preloadAssets(List<String> assets) async {
    if (!_ready) return;
    for (final a in assets) {
      if (_disposed || a.isEmpty || _assetCache.containsKey(a)) continue;
      try {
        _assetCache[a] = await SoLoud.instance.loadAsset('assets/$a');
      } catch (_) {}
    }
  }

  /// Reproduce un asset (ruta relativa estilo AssetSource, sin 'assets/').
  Future<void> playAsset(String asset, {double? volume}) async {
    if (_disposed || !_ready || asset.isEmpty) return;
    final myGen = ++_loadGen;
    try {
      await stopVoice();
      if (_source == null || _sourceId != 'asset:$asset') {
        await _disposeOwned();
        if (myGen != _loadGen || _disposed) return;
        _source = _assetCache[asset] ??
            await SoLoud.instance.loadAsset('assets/$asset');
        if (myGen != _loadGen || _disposed) return;
        _assetCache[asset] = _source!;
        _sourceId = 'asset:$asset';
        _ownsSource = false;
      }
      if (myGen != _loadGen || _disposed) return;
      _launch(volume ?? this.volume);
    } catch (_) {}
  }

  /// Reproduce una URL (streaming). No se cachea: se libera al cambiar
  /// de pista o con [disposeSource]/[dispose].
  /// [httpClient] permite inyectar cabeceras (p. ej. Bearer de ROMM).
  /// Solo la última llamada concurrente lanza voz: las adelantadas abortan
  /// y liberan su fuente recién cargada sin tocar la vigente.
  Future<void> playUrl(
    String url, {
    double? volume,
    http.Client? httpClient,
  }) async {
    if (_disposed || !_ready || url.isEmpty) return;
    final myGen = ++_loadGen;
    try {
      await stopVoice();
      if (_source == null || _sourceId != 'url:$url') {
        await _disposeOwned();
        if (myGen != _loadGen || _disposed) return;
        final fresh = await SoLoud.instance.loadUrl(
          url,
          httpClient: httpClient,
        );
        if (myGen != _loadGen || _disposed) {
          try {
            await SoLoud.instance.disposeSource(fresh);
          } catch (_) {}
          return;
        }
        _source = fresh;
        _sourceId = 'url:$url';
        _ownsSource = true;
      }
      if (myGen != _loadGen || _disposed) return;
      _launch(volume ?? this.volume);
    } catch (_) {}
  }

  void _launch(double vol) {
    _handle = SoLoud.instance.play(_source!, volume: vol.clamp(0.0, 1.0));
    state = SoloudSingleState.playing;
    _startEndTimer();
  }

  /// Fija el volumen base y, si hay voz sonando, lo aplica en vivo.
  /// No toca el estado ni la fuente: sirve para sliders globales.
  void applyVolume(double vol) {
    final next = vol.clamp(0.0, 1.0);
    volume = next;
    final h = _handle;
    if (_disposed || state != SoloudSingleState.playing || h == null) return;
    try {
      SoLoud.instance.setVolume(h, next);
    } catch (_) {}
  }

  /// Detiene la voz actual sin cambiar de estado final (uso interno).
  Future<void> stopVoice() async {
    _endTimer?.cancel();
    _endTimer = null;
    final h = _handle;
    _handle = null;
    if (h != null) {
      try {
        await SoLoud.instance.stop(h);
      } catch (_) {}
    }
  }

  /// Detiene y vuelve a idle (conserva la fuente). Cancela además las
  /// cargas en curso: su lanzamiento tardío quedaría huérfano.
  Future<void> stop() async {
    _loadGen++;
    await stopVoice();
    if (!_disposed) state = SoloudSingleState.idle;
  }

  Future<void> pause() async {
    if (_disposed || state != SoloudSingleState.playing || _handle == null) {
      return;
    }
    try {
      SoLoud.instance.setPause(_handle!, true);
      state = SoloudSingleState.paused;
    } catch (_) {}
    _endTimer?.cancel();
    _endTimer = null;
  }

  Future<void> resume() async {
    if (_disposed || state != SoloudSingleState.paused || _handle == null) {
      return;
    }
    try {
      SoLoud.instance.setPause(_handle!, false);
      state = SoloudSingleState.playing;
      _startEndTimer();
    } catch (_) {}
  }

  void _startEndTimer() {
    _endTimer?.cancel();
    _endTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_disposed ||
          state != SoloudSingleState.playing ||
          _handle == null) {
        return;
      }
      var valid = false;
      try {
        valid = SoLoud.instance.getIsValidVoiceHandle(_handle!);
      } catch (_) {}
      if (!valid) {
        _endTimer?.cancel();
        _endTimer = null;
        _handle = null;
        state = SoloudSingleState.completed;
        try {
          onComplete?.call();
        } catch (_) {}
      }
    });
  }

  Future<void> _disposeOwned() async {
    if (!_ownsSource) {
      _source = null;
      _sourceId = null;
      return;
    }
    final s = _source;
    _source = null;
    _sourceId = null;
    _ownsSource = false;
    if (s != null) {
      try {
        await SoLoud.instance.disposeSource(s);
      } catch (_) {}
    }
  }

  /// Libera la fuente cargada si es propia (streams URL). Los assets
  /// cacheados nunca se liberan.
  Future<void> disposeSource() => _disposeOwned();

  /// Posición actual de la voz en curso (cero si no hay).
  Duration get position {
    final h = _handle;
    if (h == null) return Duration.zero;
    try {
      return SoLoud.instance.getPosition(h);
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Duración de la fuente cargada (cero si no hay).
  Duration get sourceLength {
    final s = _source;
    if (s == null) return Duration.zero;
    try {
      return SoLoud.instance.getLength(s);
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Salta a una posición de la voz en curso.
  void seek(Duration position) {
    final h = _handle;
    if (h == null) return;
    try {
      SoLoud.instance.seek(h, position);
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    _endTimer?.cancel();
    _endTimer = null;
    final h = _handle;
    _handle = null;
    if (h != null) {
      try {
        SoLoud.instance.stop(h);
      } catch (_) {}
    }
    if (_ownsSource) {
      final s = _source;
      if (s != null) {
        try {
          SoLoud.instance.disposeSource(s);
        } catch (_) {}
      }
    }
    _source = null;
    _ownsSource = false;
  }
}
