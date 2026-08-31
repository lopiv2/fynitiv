import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:fynitiv/features/games/data/khinsider/khinsider_scraper.dart';

import '../../features/games/data/khinsider/khinsider_models.dart';

/// Player para OST de Khinsider en detalle de juego.
/// Streaming directo via UrlSource, queue completa en shuffle, volumen 0.5,
/// respeta mute de GameBg y soporta Now Playing via stream.
class KhinsiderPlayer {
  KhinsiderPlayer._();
  static final KhinsiderPlayer instance = KhinsiderPlayer._();

  final AudioPlayer _player = AudioPlayer();
  final KhinsiderScraper _scraper = KhinsiderScraper();
  final Map<String, String> _resolvedUrlCache = {};
  StreamSubscription<void>? _completeSub;
  List<KhinsiderTrack> _queue = [];
  List<KhinsiderTrack> _shuffled = [];
  int _index = 0;
  bool _muted = false;
  bool _initialized = false;
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
    _player.setReleaseMode(ReleaseMode.stop);
    _player.setVolume(0.5);
    _completeSub = _player.onPlayerComplete.listen((_) => _onComplete());
  }

  Future<void> _onComplete() async {
    if (_muted || _shuffled.isEmpty) return;
    _index = (_index + 1) % _shuffled.length;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_shuffled.isEmpty || _muted) return;
    final track = _shuffled[_index];
    _current = track;
    _currentTrackController.add(track);
    try {
      final realUrl = await _resolveUrl(track);
      if (realUrl == null) {
        // no se pudo resolver esta pista, salta a la siguiente
        _index = (_index + 1) % _shuffled.length;
        if (_shuffled.length > 1) await _playCurrent();
        return;
      }
      await _player.stop();
      await _player.setVolume(0.5);
      await _player.play(UrlSource(realUrl));
    } catch (_) {
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        _index = (_index + 1) % _shuffled.length;
        if (_shuffled.length > 1 && _index != 0) await _playCurrent();
      } catch (_) {}
    }
  }

  /// Reproduce queue completa en shuffle. Corta cualquier reproducción previa.
  Future<void> playQueue(List<KhinsiderTrack> tracks) async {
    _ensureInit();
    if (tracks.isEmpty) return;
    _queue = List<KhinsiderTrack>.from(tracks);
    _shuffled = List<KhinsiderTrack>.from(tracks)..shuffle(Random());
    _index = 0;
    if (_muted) {
      _current = _shuffled.first;
      _currentTrackController.add(_current);
      return;
    }
    await _playCurrent();
  }

  Future<void> stop() async {
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
    if (muted) {
      try {
        await _player.stop();
      } catch (_) {}
    } else if (_shuffled.isNotEmpty) {
      await _playCurrent();
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
      final state = _player.state;
      if (state == PlayerState.paused) {
        await _player.resume();
      } else if (state == PlayerState.stopped ||
          state == PlayerState.completed) {
        await _playCurrent();
      }
    } catch (_) {}
  }

  void dispose() {
    _completeSub?.cancel();
    _player.dispose();
    _currentTrackController.close();
  }
}
