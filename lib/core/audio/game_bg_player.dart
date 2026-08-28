import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

import '../constants/theme_music.dart';

/// Reproductor de música de fondo para la rama de juego online.
/// Shuffle al entrar, recorre sin repetir hasta agotar, luego loop al inicio.
/// Si se sale y se vuelve a entrar hace shuffle nuevo.
/// Volumen fijo 0.5 independiente del FX de hover.
class GameBgPlayer {
  GameBgPlayer._();
  static final GameBgPlayer instance = GameBgPlayer._();

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<void>? _completeSub;
  List<String> _queue = [];
  int _index = 0;
  bool _inside = false;
  bool _muted = false;
  bool _initialized = false;

  void _ensureInit() {
    if (_initialized) return;
    _initialized = true;
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setVolume(0.5);
    _completeSub = _player.onPlayerComplete.listen((_) => _onComplete());
  }

  Future<void> _onComplete() async {
    if (!_inside || _muted || _queue.isEmpty) return;
    _index = (_index + 1) % _queue.length;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_queue.isEmpty || _muted) return;
    final asset = _queue[_index];
    try {
      await _player.stop();
      await _player.setVolume(0.5);
      await _player.play(AssetSource(asset));
    } catch (e) {
      // Si falla (ej. espacio en nombre), prueba siguiente
      try {
        await Future.delayed(const Duration(milliseconds: 200));
        _index = (_index + 1) % _queue.length;
        if (_index != 0) await _playCurrent();
      } catch (_) {}
    }
  }

  /// Llamado al entrar en /games (hub o lista). Hace shuffle nuevo.
  Future<void> enter() async {
    _ensureInit();
    if (_inside) return;
    _inside = true;
    _queue = List<String>.from(kThemeTracks)..shuffle(Random());
    _index = 0;
    if (_muted) return;
    await _playCurrent();
  }

  /// Llamado al salir completamente de /games (no hub ni lista). Corta música.
  Future<void> leave() async {
    if (!_inside) return;
    _inside = false;
    try {
      await _player.stop();
    } catch (_) {}
    _queue = [];
    _index = 0;
  }

  Future<void> setMuted(bool muted) async {
    _ensureInit();
    _muted = muted;
    if (muted) {
      try {
        await _player.stop();
      } catch (_) {}
    } else if (_inside && _queue.isNotEmpty) {
      await _playCurrent();
    }
  }

  Future<void> pauseForExternal() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resumeIfNeeded() async {
    if (!_inside || _muted) return;
    try {
      final state = _player.state;
      if (state == PlayerState.paused) {
        await _player.resume();
      } else if (state == PlayerState.stopped || state == PlayerState.completed) {
        await _playCurrent();
      }
    } catch (_) {}
  }

  void dispose() {
    _completeSub?.cancel();
    _player.dispose();
  }
}
