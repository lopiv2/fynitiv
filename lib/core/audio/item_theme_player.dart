import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import 'soloud_initializer.dart';
import 'soloud_single_player.dart';

/// Player singleton para themes/OST de items Jellyfin (solo detalle).
///
/// Una sola voz sobre SoLoud, volumen bajo de fondo (0.35), con token
/// anti-carreras como [GameOstPlayer]: si se sale del detalle o cambia el
/// hover mientras se carga la pista, el play tardío se aborta y no suena
/// fuera de contexto.
class ItemThemePlayer {
  ItemThemePlayer._();
  static final ItemThemePlayer instance = ItemThemePlayer._();

  final SoloudSinglePlayer _player = SoloudSinglePlayer(volume: 0.35);

  /// Fallback MediaKit (libmpv) por si SoLoud no abre el mp3.
  Player? _fallback;

  final StreamController<String?> _currentController =
      StreamController<String?>.broadcast();

  String? _currentUrl;
  String? get currentUrl => _currentUrl;
  Stream<String?> get currentStream => _currentController.stream;

  bool _muted = false;
  bool get isMuted => _muted;

  /// True mientras una ficha detalle tiene el theme en propiedad: el hover
  /// no debe pisarlo ni cortarlo.
  bool _inDetail = false;

  int _session = 0;
  bool _initialized = false;

  void _ensureInit() {
    if (_initialized) return;
    _initialized = true;
    _player.onComplete = () {
      _currentUrl = null;
      _currentController.add(null);
    };
  }

  /// Reproduce una URL directa (mp3 Jellyfin del theme del item).
  /// Intenta SoLoud primero y cae a MediaKit si no arranca.
  Future<void> play(String url, {bool inDetail = false}) async {
    _ensureInit();
    debugPrint(
      '[Theme] player.play inDetail=$inDetail muted=$_muted '
      'soloudInit=${SoloudInitializer.isInitialized} '
      'url=${_short(url)}',
    );
    if (url.isEmpty || _muted) {
      debugPrint('[Theme] player.play ABORTADO (vacío/mute)');
      if (inDetail) _inDetail = true;
      return;
    }
    _session++;
    final session = _session;
    if (inDetail) _inDetail = true;
    _currentUrl = url;
    _currentController.add(url);
    try {
      await _stopFallback();
      await _player.playUrl(url, volume: 0.35);
      if (session != _session) {
        debugPrint('[Theme] player.play tardío abortado (sesión $session caducada)');
        await _player.stop();
        return;
      }
      if (_player.state == SoloudSingleState.playing) {
        debugPrint('[Theme] player.play OK via SoLoud');
        return;
      }
      debugPrint(
        '[Theme] SoLoud no arrancó (state=${_player.state}), fallback MediaKit',
      );
      await _playFallback(url, session);
    } catch (error) {
      debugPrint('[Theme] player.play ERROR: $error');
      if (session == _session) {
        _currentUrl = null;
        _currentController.add(null);
      }
    }
  }

  void _scheduleDiag(Player p, int session) {
    // Diagnóstico diferido: si position no avanza, mpv no renderiza;
    // si avanza sin oírse, es mezcla/salida del sistema.
    Future.delayed(const Duration(seconds: 3), () {
      if (session != _session) return;
      try {
        final st = p.state;
        debugPrint(
          '[Theme] MediaKit diag playing=${st.playing} '
          'pos=${st.position} dur=${st.duration} vol=${st.volume} '
          'audio=${st.audioParams} completed=${st.completed} '
          'playlistMode=${st.playlistMode}',
        );
      } catch (error) {
        debugPrint('[Theme] MediaKit diag error: $error');
      }
    });
  }

  Future<void> _playFallback(String url, int session) async {
    try {
      final p = _fallback ??= Player();
      await p.open(
        Media(
          url,
          httpHeaders: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
          },
        ),
      );
      if (session != _session) {
        await p.stop();
        return;
      }
      await p.play();
      // Volumen de fondo (0-100 en MediaKit).
      try {
        await p.setVolume(35);
      } catch (_) {}
      debugPrint('[Theme] player.play OK via MediaKit playing=${p.state.playing}');
      _scheduleDiag(p, session);
    } catch (error) {
      debugPrint('[Theme] MediaKit fallback ERROR: $error');
      if (session == _session) {
        _currentUrl = null;
        _currentController.add(null);
      }
    }
  }

  Future<void> _stopFallback() async {
    final p = _fallback;
    if (p == null) return;
    try {
      await p.stop();
    } catch (_) {}
  }

  static String _short(String url) =>
      url.length > 90 ? '${url.substring(0, 90)}…' : url;

  /// Preview de hover: no pisa el theme de un detalle abierto.
  Future<void> playPreview(String url) async {
    if (_inDetail) return;
    await play(url);
  }

  /// Corta solo si no hay un detalle en propiedad (el unhover no debe
  /// matar el theme del detalle).
  Future<void> stopPreview() async {
    if (_inDetail) return;
    await stop();
  }

  Future<void> stop() async {
    debugPrint('[Theme] player.stop (inDetail=$_inDetail)');
    _session++;
    _inDetail = false;
    _currentUrl = null;
    _currentController.add(null);
    try {
      await _player.stop();
    } catch (_) {}
    await _stopFallback();
  }

  /// Al salir del detalle se libera la propiedad pero se mantiene la voz
  /// si el hover la reutiliza justo después (el stop explícito la corta).
  Future<void> leaveDetail() async {
    _session++;
    _inDetail = false;
    _currentUrl = null;
    _currentController.add(null);
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> setMuted(bool muted) async {
    _ensureInit();
    debugPrint('[Theme] player.setMuted $muted');
    _muted = muted;
    _session++;
    if (muted) {
      try {
        await _player.stop();
      } catch (_) {}
      await _stopFallback();
      _currentUrl = null;
      _currentController.add(null);
    }
  }

  Future<void> pauseForExternal() async {
    try {
      await _player.pause();
    } catch (_) {}
    try {
      await _fallback?.pause();
    } catch (_) {}
  }

  Future<void> resumeIfNeeded() async {
    if (_muted || _currentUrl == null) return;
    try {
      if (_player.state == SoloudSingleState.paused) {
        await _player.resume();
        return;
      }
    } catch (_) {}
    // Si SoLoud no tiene la voz (idle/completed o era fallback),
    // re-lanza por el mismo camino que play (SoLoud -> MediaKit).
    try {
      final fb = _fallback;
      if (fb != null && _player.state != SoloudSingleState.playing) {
        await fb.play();
        debugPrint('[Theme] resume via MediaKit');
        return;
      }
      if (_player.state == SoloudSingleState.idle ||
          _player.state == SoloudSingleState.completed) {
        final url = _currentUrl;
        if (url != null) {
          await play(url, inDetail: _inDetail);
        }
      }
    } catch (_) {}
  }

  /// ¿Sigue sonando esta URL concreta? Evita re-resolver en cada rebuild.
  bool isPlayingUrl(String url) => _currentUrl == url && url.isNotEmpty;
}
