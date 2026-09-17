import 'dart:async';
import 'dart:math';

import 'package:fynitiv/features/games/data/khinsider/khinsider_scraper.dart';

import '../../features/games/data/khinsider/khinsider_models.dart';
import 'soloud_single_player.dart';

/// Player para OST de Khinsider en detalle de juego.
/// Streaming directo por URL, queue completa en shuffle, volumen 0.5,
/// respeta mute de GameBg y soporta Now Playing via stream.
class KhinsiderPlayer {
  KhinsiderPlayer._();
  static final KhinsiderPlayer instance = KhinsiderPlayer._();

  final SoloudSinglePlayer _player = SoloudSinglePlayer(volume: 0.5);
  final KhinsiderScraper _scraper = KhinsiderScraper();
  final Map<String, String> _resolvedUrlCache = {};
  List<KhinsiderTrack> _queue = [];
  List<KhinsiderTrack> _shuffled = [];
  int _index = 0;
  bool _muted = false;
  bool _initialized = false;
  // Token anti-carreras: si se sale del detalle mientras se resuelve la
  // URL (red) o se carga la pista, el play tardío debe abortarse.
  int _session = 0;
  final StreamController<KhinsiderTrack?> _currentTrackController =
      StreamController<KhinsiderTrack?>.broadcast();
  KhinsiderTrack? _current;

  Stream<KhinsiderTrack?> get currentTrackStream =>
      _currentTrackController.stream;
  KhinsiderTrack? get currentTrack => _current;
  bool get isPlaying => _queue.isNotEmpty;

  Future<String?> _resolveUrl(KhinsiderTrack track) async {
    final cached = _resolvedUrlCache[track.pageUrl];
    if (cached != null) return cached;
    final real = await _scraper.resolveDownloadUrl(track.pageUrl);
    if (real != null) _resolvedUrlCache[track.pageUrl] = real;
    return real;
  }

  void _ensureInit() {
    if (_initialized) return;
    _initialized = true;
    _player.onComplete = _onComplete;
  }

  Future<void> _onComplete() async {
    if (_muted || _shuffled.isEmpty) return;
    _index = (_index + 1) % _shuffled.length;
    await _playCurrent(_session);
  }

  Future<void> _playCurrent(int session) async {
    if (session != _session || _shuffled.isEmpty || _muted) return;
    final track = _shuffled[_index];
    _current = track;
    _currentTrackController.add(track);
    try {
      final realUrl = await _resolveUrl(track);
      if (session != _session) return;
      if (realUrl == null) {
        // no se pudo resolver esta pista, salta a la siguiente
        _index = (_index + 1) % _shuffled.length;
        if (_shuffled.length > 1) await _playCurrent(session);
        return;
      }
      await _player.playUrl(realUrl, volume: 0.5);
      if (session != _session) {
        // Se salió del detalle durante la carga: no debe sonar fuera.
        await _player.stop();
        return;
      }
    } catch (_) {
      if (session != _session) return;
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        if (session != _session) return;
        _index = (_index + 1) % _shuffled.length;
        if (_shuffled.length > 1 && _index != 0) {
          await _playCurrent(session);
        }
      } catch (_) {}
    }
  }

  /// Reproduce queue completa en shuffle. Corta cualquier reproducción previa.
  Future<void> playQueue(List<KhinsiderTrack> tracks) async {
    _ensureInit();
    if (tracks.isEmpty) return;
    _session++;
    _queue = List<KhinsiderTrack>.from(tracks);
    _shuffled = List<KhinsiderTrack>.from(tracks)..shuffle(Random());
    _index = 0;
    if (_muted) {
      _current = _shuffled.first;
      _currentTrackController.add(_current);
      return;
    }
    await _playCurrent(_session);
  }

  Future<void> stop() async {
    _session++;
    _queue = [];
    _shuffled = [];
    _index = 0;
    _current = null;
    _currentTrackController.add(null);
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<void> setMuted(bool muted) async {
    _ensureInit();
    _muted = muted;
    _session++;
    if (muted) {
      try {
        await _player.stop();
      } catch (_) {}
    } else if (_shuffled.isNotEmpty) {
      await _playCurrent(_session);
    }
  }

  Future<void> pauseForExternal() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resumeIfNeeded() async {
    if (_muted || _shuffled.isEmpty) return;
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
    _currentTrackController.close();
  }
}
