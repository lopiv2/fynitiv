import 'dart:async';
import 'dart:math';

import 'soloud_single_player.dart';

import '../constants/theme_music.dart';

/// Reproductor de música de fondo para la rama de juego online.
/// Shuffle al entrar, recorre sin repetir hasta agotar, luego loop al inicio.
/// Si se sale y se vuelve a entrar hace shuffle nuevo.
/// Volumen fijo 0.5 independiente del FX de hover.
class GameBgPlayer {
  GameBgPlayer._();
  static final GameBgPlayer instance = GameBgPlayer._();

  final SoloudSinglePlayer _player = SoloudSinglePlayer(volume: 0.5);
  List<String> _queue = [];
  int _index = 0;
  bool _inside = false;
  bool _muted = false;
  bool _initialized = false;
  // Token anti-carreras: si se sale (leave) mientras una pista se está
  // cargando, el play tardío debe abortarse y no sonar fuera de /games.
  int _session = 0;

  void _ensureInit() {
    if (_initialized) return;
    _initialized = true;
    _player.onComplete = _onComplete;
  }

  Future<void> _onComplete() async {
    if (!_inside || _muted || _queue.isEmpty) return;
    _index = (_index + 1) % _queue.length;
    await _playCurrent(_session);
  }

  Future<void> _playCurrent(int session) async {
    if (session != _session || _queue.isEmpty || _muted) return;
    final asset = _queue[_index];
    try {
      await _player.playAsset(asset, volume: 0.5);
      if (session != _session) {
        // Se suspendió o salió durante la carga: no debe sonar.
        await _player.stop();
        return;
      }
    } catch (e) {
      if (session != _session) return;
      // Si falla (ej. espacio en nombre), prueba siguiente
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        if (session != _session) return;
        _index = (_index + 1) % _queue.length;
        if (_index != 0) await _playCurrent(session);
      } catch (_) {}
    }
  }

  /// Llamado al entrar en /games (hub o lista). Hace shuffle nuevo.
  Future<void> enter() async {
    _ensureInit();
    if (_inside) return;
    _inside = true;
    _session++;
    _queue = List<String>.from(kThemeTracks)..shuffle(Random());
    _index = 0;
    if (_muted) return;
    await _playCurrent(_session);
  }

  /// Llamado al salir completamente de /games (no hub ni lista). Corta música.
  Future<void> leave() async {
    if (!_inside) return;
    _inside = false;
    _session++;
    try {
      await _player.stop();
    } catch (_) {}
    _queue = [];
    _index = 0;
  }

  /// Suspende la voz actual sin salir del estado: para entrar al detalle
  /// del juego, donde suena el OST propio (Khinsider) y no debe solaparse.
  /// Es determinista (no depende del timing de rebuild del shell).
  Future<void> suspendForDetail() async {
    _session++;
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Vuelve del detalle: para el OST ajeno quien lo llame y retoma el
  /// fondo con reshuffle si seguíamos dentro de juegos.
  Future<void> returnFromDetail() async {
    if (!_inside || _muted || _queue.isEmpty) return;
    _session++;
    _queue.shuffle(Random());
    _index = 0;
    await _playCurrent(_session);
  }

  Future<void> setMuted(bool muted) async {
    _ensureInit();
    _muted = muted;
    _session++;
    if (muted) {
      try {
        await _player.stop();
      } catch (_) {}
    } else if (_inside && _queue.isNotEmpty) {
      // Al reactivar el sonido, reshuffle y empieza de cero.
      _queue.shuffle(Random());
      _index = 0;
      await _playCurrent(_session);
    }
  }

  Future<void> pauseForExternal() async {
    // En la pantalla de juegos la música debe seguir sonando aunque la app
    // pierda el foco (inactive/paused). Si seguimos dentro de /games, no pausar.
    if (_inside && !_muted) return;
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resumeIfNeeded() async {
    if (!_inside || _muted) return;
    try {
      if (_player.state == SoloudSingleState.paused) {
        await _player.resume();
      } else if (_player.state == SoloudSingleState.idle ||
          _player.state == SoloudSingleState.completed) {
        await _playCurrent(_session);
      }
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}
