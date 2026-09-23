import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../features/games/domain/game_ost_track.dart';
import 'soloud_single_player.dart';

/// Cliente HTTP que inyecta el Bearer de ROMM (las `stream_url` de su
/// Music API exigen autenticación y `SoLoud.loadUrl` no pone cabeceras).
class _RommAuthHttpClient extends http.BaseClient {
  _RommAuthHttpClient(this._token);

  final String _token;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Player para OST del detalle de juego (Music API de ROMM).
/// Streaming con Bearer por URL, queue en orden de pista (o shuffle),
/// volumen 0.5, respeta mute de GameBg y soporta Now Playing via stream.
class GameOstPlayer {
  GameOstPlayer._();
  static final GameOstPlayer instance = GameOstPlayer._();

  final SoloudSinglePlayer _player = SoloudSinglePlayer(volume: 0.5);
  List<GameOstTrack> _queue = [];
  List<GameOstTrack> _shuffled = [];
  int _index = 0;
  bool _muted = false;
  bool _shuffleEnabled = true;
  bool _initialized = false;
  // Volumen 0..1 de la voz OST. Lo fija el detalle desde el volumen
  // universal (`appVolumeProvider` 0..100); 0.5 conserva el nivel previo
  // hasta que la UI lo sincroniza al abrir.
  double _volume = 0.5;
  // Pausa explícita del usuario (botón play/pausa). `resumeIfNeeded` no debe
  // reanudar en ese caso: solo recupera cortes del sistema (llamada, etc.).
  bool _userPaused = false;
  // Token Bearer de ROMM para el streaming de la Music API.
  http.Client? _authClient;
  String _authToken = '';
  // Token anti-carreras: si se sale del detalle mientras se carga la
  // pista, el play tardío debe abortarse.
  int _session = 0;
  // Sesión con carga en curso: una re-entrada con la MISMA sesión (p.ej.
  // `resumeIfNeeded` por un `resumed` durante la descarga lenta) no debe
  // lanzar otra voz; la carga vigente manda.
  int _loadingSession = -1;
  // Carga en curso de una pista (true entre _current asignado y
  // playUrl resuelto con éxito). Sirve para mostrar loader en vez de
  // pausa/play y bloquear toggle hasta que suene.
  bool _loading = false;
  final StreamController<GameOstTrack?> _currentTrackController =
      StreamController<GameOstTrack?>.broadcast();
  final StreamController<bool> _loadingController =
      StreamController<bool>.broadcast();
  GameOstTrack? _current;

  Stream<GameOstTrack?> get currentTrackStream =>
      _currentTrackController.stream;
  Stream<bool> get loadingStream => _loadingController.stream;
  GameOstTrack? get currentTrack => _current;
  bool get isPlaying => _queue.isNotEmpty;
  bool get shuffleEnabled => _shuffleEnabled;
  bool get isMuted => _muted;
  bool get userPaused => _userPaused;

  /// Configura el Bearer de ROMM para el streaming (llamar antes de
  /// reproducir; al cerrar sesión pasar null para no reutilizarlo).
  void setAuthToken(String? token) {
    final t = token?.trim() ?? '';
    if (t == _authToken) return;
    _authToken = t;
    try {
      _authClient?.close();
    } catch (_) {}
    _authClient = t.isNotEmpty ? _RommAuthHttpClient(t) : null;
  }
  bool get sounding =>
      _player.state == SoloudSingleState.playing;
  bool get isLoading => _loading;

  /// Volumen actual 0..1 (para pintar el slider).
  double get volume => _volume;

  /// Fija el volumen (0..1) y lo aplica en vivo si está sonando.
  /// Síncrono a propósito: los `ref.listen` lo llaman sin await y no
  /// reescribe el provider global (evita bucles).
  void setVolume(double v) {
    _ensureInit();
    final next = v.clamp(0.0, 1.0);
    if ((next - _volume).abs() < 0.0001) return;
    _volume = next;
    _player.applyVolume(next);
  }

  void _setLoading(bool value) {
    if (_loading == value) return;
    _loading = value;
    _loadingController.add(value);
  }

  /// Posición actual de la pista en curso.
  Duration get position => _player.position;

  /// Duración de la pista en curso (cero si aún carga).
  Duration get trackLength => _player.sourceLength;

  static int _indexOfUrl(List<GameOstTrack> list, GameOstTrack? track) {
    if (track == null) return -1;
    for (var i = 0; i < list.length; i++) {
      if (list[i].url == track.url) return i;
    }
    return -1;
  }

  /// Activa/desactiva el aleatorio conservando la pista actual en su sitio
  /// (no reinicia la reproducción).
  Future<void> setShuffle(bool enabled) async {
    _ensureInit();
    if (enabled == _shuffleEnabled) return;
    _shuffleEnabled = enabled;
    if (_queue.isEmpty) return;
    final current = _current;
    _shuffled = enabled
        ? (List<GameOstTrack>.from(_queue)..shuffle(Random()))
        : List<GameOstTrack>.from(_queue);
    if (current != null) {
      final i = _indexOfUrl(_shuffled, current);
      _index = i >= 0 ? i : 0;
    } else {
      _index = 0;
    }
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
    if (_loadingSession == session) return;
    _loadingSession = session;
    final track = _shuffled[_index];
    _current = track;
    _currentTrackController.add(track);
    _setLoading(true);
    try {
      await _player.playUrl(
        track.url,
        volume: _volume,
        httpClient: _authClient,
      );
      if (session != _session || _loadingSession != session) {
        // Otra llamada tomó el mando (o se salió del detalle): no tocar
        // su voz. Salir del detalle pasa por stop(), que ya cancela la
        // carga pendiente dentro del player.
        return;
      }
      _loadingSession = -1;
      _setLoading(false);
    } catch (_) {
      if (_loadingSession == session) _loadingSession = -1;
      _setLoading(false);
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
  Future<void> playQueue(List<GameOstTrack> tracks) async {
    _ensureInit();
    if (tracks.isEmpty) return;
    _session++;
    _userPaused = false;
    _shuffleEnabled = true;
    _queue = List<GameOstTrack>.from(tracks);
    _shuffled = List<GameOstTrack>.from(tracks)..shuffle(Random());
    _index = 0;
    if (_muted) {
      _current = _shuffled.first;
      _currentTrackController.add(_current);
      return;
    }
    await _playCurrent(_session);
  }

  /// Salta a la siguiente pista de la queue (respeta el orden actual:
  /// aleatorio o secuencial). Corta la pista en curso.
  Future<void> next() async {
    _ensureInit();
    if (_shuffled.isEmpty) {
      return;
    }
    _session++;
    _userPaused = false;
    _index = (_index + 1) % _shuffled.length;
    if (_muted) {
      _current = _shuffled[_index];
      _currentTrackController.add(_current);
      return;
    }
    await _playCurrent(_session);
  }

  /// Vuelve a la pista anterior de la queue.
  Future<void> previous() async {
    _ensureInit();
    if (_shuffled.isEmpty) return;
    _session++;
    _userPaused = false;
    _index = (_index - 1) % _shuffled.length;
    if (_index < 0) _index += _shuffled.length;
    if (_muted) {
      _current = _shuffled[_index];
      _currentTrackController.add(_current);
      return;
    }
    await _playCurrent(_session);
  }

  /// Reproduce una pista concreta de la queue sin alterar el orden.
  Future<void> playTrack(GameOstTrack track) async {
    _ensureInit();
    if (_shuffled.isEmpty) return;
    final i = _indexOfUrl(_shuffled, track);
    if (i < 0) {
      return;
    }
    _session++;
    _userPaused = false;
    _index = i;
    if (_muted) {
      _current = track;
      _currentTrackController.add(_current);
      return;
    }
    await _playCurrent(_session);
  }

  /// Alterna pausa/reproducción de la pista en curso.
  Future<void> toggle() async {
    _ensureInit();
    if (_shuffled.isEmpty || _loading) return;
    if (_player.state == SoloudSingleState.playing) {
      try {
        await _player.pause();
        _userPaused = true;
      } catch (_) {}
    } else if (_player.state == SoloudSingleState.paused) {
      try {
        await _player.resume();
        _userPaused = false;
      } catch (_) {}
    } else {
      _session++;
      _userPaused = false;
      await _playCurrent(_session);
    }
  }

  /// Salta a una posición de la pista en curso.
  void seek(Duration position) => _player.seek(position);

  Future<void> stop() async {
    _setLoading(false);
    _session++;
    _userPaused = false;
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
    } else if (_shuffled.isNotEmpty && !_userPaused) {
      await _playCurrent(_session);
    }
  }

  Future<void> pauseForExternal() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  Future<void> resumeIfNeeded() async {
    if (_muted || _userPaused || _shuffled.isEmpty) return;
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
    try {
      _authClient?.close();
    } catch (_) {}
    _authClient = null;
    _currentTrackController.close();
    _loadingController.close();
  }
}
