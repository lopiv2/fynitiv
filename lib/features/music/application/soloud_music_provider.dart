import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:media_kit/media_kit.dart';

import 'dart:developer' as developer;

import '../../library/application/image_url.dart';
import '../../player/application/playback_provider.dart';
import '../../../core/audio/game_bg_player.dart';
import '../../../core/audio/game_ost_player.dart';
import '../../../core/audio/soloud_initializer.dart';
import '../../../core/audio/app_volume_provider.dart';
import '../../games/domain/game_ost_track.dart';
import 'audio_eq_provider.dart';

/// Cliente HTTP que inyecta el Bearer de ROMM (las `stream_url` de su
/// Music API lo exigen y `SoLoud.loadUrl` no pone cabeceras solo).
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

/// Pista encolada del provider compartido: sesión + item visible + auth.
class _QueuedTrack {
  const _QueuedTrack({
    required this.session,
    required this.item,
    this.authToken,
    this.isFavorite = false,
    this.coverUrl,
  });

  final PlaybackSession session;
  final BaseItemDto? item;
  final String? authToken;
  final bool isFavorite;

  /// Portada del juego dueño (OST ROMM sin cover propio).
  final String? coverUrl;
}

/// Motor activo para playback de música.
enum PlaybackEngine { soloud, mediaKit, none }

/// Estado unificado para música (SoLoud primario, MediaKit fallback).
class SoloudMusicState {
  const SoloudMusicState({
    this.item,
    this.session,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.error,
    this.completed = false,
    this.engine = PlaybackEngine.none,
    this.isFavorite = false,
    this.ostCoverUrl,
  });

  final BaseItemDto? item;
  final PlaybackSession? session;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final double volume; // 0..100
  final String? error;
  final bool completed;
  final PlaybackEngine engine;

  /// Favorita ROMM de la pista en curso (solo Jukebox/OST; Jellyfin no usa).
  final bool isFavorite;

  /// Portada del juego dueño para pistas ROMM (las OST no traen cover).
  final String? ostCoverUrl;

  bool get hasItem => item != null && session != null;
  bool get isSoloud => engine == PlaybackEngine.soloud;
  bool get isMediaKit => engine == PlaybackEngine.mediaKit;

  /// Pista servida por ROMM (`romm-<romFileId>`): sin carátula Jellyfin.
  bool get isRomm => session?.itemId.startsWith('romm-') == true;

  String get coverUrl {
    if (item == null || session == null) return '';
    if (isRomm) return ostCoverUrl ?? '';
    return itemImageUrl(session!.serverUrl, item!, maxWidth: 400);
  }

  String get title => item?.name ?? session?.itemName ?? '';
  String get artist => item?.artists?.join(', ') ?? '';

  SoloudMusicState copyWith({
    BaseItemDto? item,
    PlaybackSession? session,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    double? volume,
    String? error,
    bool clearError = false,
    bool? completed,
    PlaybackEngine? engine,
    bool? isFavorite,
    String? ostCoverUrl,
    bool clearOstCover = false,
  }) {
    return SoloudMusicState(
      item: item ?? this.item,
      session: session ?? this.session,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      error: clearError ? null : (error ?? this.error),
      completed: completed ?? this.completed,
      engine: engine ?? this.engine,
      isFavorite: isFavorite ?? this.isFavorite,
      ostCoverUrl: clearOstCover ? null : (ostCoverUrl ?? this.ostCoverUrl),
    );
  }
}

class SoloudMusicController extends Notifier<SoloudMusicState> {
  AudioSource? _source;
  SoundHandle? _handle;
  Player? _fallbackPlayer;
  final List<StreamSubscription> _fallbackSubs = [];
  Timer? _posTimer;
  Timer? _completionTimer;
  bool _disposed = false;

  // Cola del provider compartido (Jukebox/OST): orden de reproducción y
  // posición en él. Vacía = single Jellyfin/radio (comportamiento previo).
  List<_QueuedTrack> _queue = [];
  List<int> _order = [];
  int _orderPos = -1;
  // Generación de carga: solo la última petición lanza voz (evita huérfanas
  // al pulsar siguiente rápido con FLACs lentos).
  int _playGen = 0;

  bool get _queueActive => _queue.isNotEmpty && _order.isNotEmpty;

  bool get _soloudReady => SoloudInitializer.isInitialized && SoLoud.instance.isInitialized;

  Player get _fallback {
    _fallbackPlayer ??= Player();
    _ensureFallbackSubs();
    return _fallbackPlayer!;
  }

  void _ensureFallbackSubs() {
    if (_fallbackSubs.isNotEmpty) return;
    final p = _fallbackPlayer!;
    _fallbackSubs.add(p.stream.playing.listen((v) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(playing: v);
    }));
    _fallbackSubs.add(p.stream.position.listen((pos) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(position: pos);
    }));
    _fallbackSubs.add(p.stream.duration.listen((dur) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(duration: dur);
    }));
    _fallbackSubs.add(p.stream.buffering.listen((b) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(buffering: b);
    }));
    _fallbackSubs.add(p.stream.completed.listen((c) {
      if (_disposed || !c || state.engine != PlaybackEngine.mediaKit) return;
      _onTrackEnded(state.duration);
    }));
    _fallbackSubs.add(p.stream.error.listen((e) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(error: e);
    }));
    _fallbackSubs.add(p.stream.volume.listen((v) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(volume: v);
    }));
  }

  void _stopPosTimer() {
    _posTimer?.cancel();
    _posTimer = null;
    _completionTimer?.cancel();
    _completionTimer = null;
  }

  void _startSoloudPosTimer() {
    _stopPosTimer();
    _posTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed || _handle == null || state.engine != PlaybackEngine.soloud) return;
      try {
        final pos = SoLoud.instance.getPosition(_handle!);
        final len = _source != null ? SoLoud.instance.getLength(_source!) : state.duration;
        // Detect completed: handle invalid or near end
        bool isValid = false;
        try {
          isValid = SoLoud.instance.getIsValidVoiceHandle(_handle!);
        } catch (_) {
          isValid = false;
        }
        // Si el handle ya no es válido y estábamos playing => fin de pista:
        // avanza la cola o marca completado (y devuelve el fondo).
        if (!isValid && state.playing) {
          _onTrackEnded(len);
          return;
        }
        // También detectar por posición cerca del final
        if (len > Duration.zero && pos >= len - const Duration(milliseconds: 300) && state.playing) {
          // Esperar un poco para confirmar que se detiene
        }
        state = state.copyWith(position: pos, duration: len);
      } catch (_) {}
    });
  }

  Duration? _durationFromTicks(int? ticks) {
    if (ticks == null || ticks <= 0) return null;
    return Duration(microseconds: ticks ~/ 10);
  }

  @override
  SoloudMusicState build() {
    ref.keepAlive();
    ref.onDispose(() {
      _disposed = true;
      _stopPosTimer();
      for (final s in _fallbackSubs) {
        s.cancel();
      }
      _fallbackSubs.clear();
      // No dispose SoLoud source here, se hace en stop
      try {
        _fallbackPlayer?.dispose();
      } catch (_) {}
    });
    // Reaplicar EQ cuando cambie el estado (incluido al iniciar)
    ref.listen<AudioEqState>(audioEqProvider, (prev, next) => _applyEq(next));
    // Volumen universal: aplica al estado y al motor en vivo sin reescribir
    // el global (evita bucles: este camino nunca llama a setVolume global).
    ref.listen<double>(appVolumeProvider, (prev, next) => _applyGlobalVolume(next));
    return const SoloudMusicState();
  }

  void _applyGlobalVolume(double v) {
    final clamped = v.clamp(0, 100).toDouble();
    state = state.copyWith(volume: clamped);
    if (state.engine == PlaybackEngine.soloud && _handle != null) {
      try {
        SoLoud.instance.setVolume(_handle!, clamped / 100.0);
      } catch (_) {}
    } else if (state.engine == PlaybackEngine.mediaKit) {
      try {
        _fallbackPlayer?.setVolume(clamped);
      } catch (_) {}
    }
  }

  void _applyEq(AudioEqState eq) {
    if (!_soloudReady || _source == null || _handle == null) return;
    if (state.engine != PlaybackEngine.soloud) return;
    try {
      final f = _source!.filters;
      // NOTA: activate() lanza SoLoudFilterAlreadyAddedException si el filtro
      // ya está añadido (solo uno de cada tipo en C++). Por eso todo activate/
      // deactivate va protegido con isActive.
      // Activar / desactivar EQ principal
      if (!eq.enabled) {
        try { final x = f.parametricEqFilter; if (x.isActive) x.deactivate(); } catch (_) {}
        try { final x = f.bassBoostFilter; if (x.isActive) x.deactivate(); } catch (_) {}
        try { final x = f.freeverbFilter; if (x.isActive) x.deactivate(); } catch (_) {}
        try { final x = f.limiterFilter; if (x.isActive) x.deactivate(); } catch (_) {}
        // Reset velocidad
        try { SoLoud.instance.setRelativePlaySpeed(_handle!, 1.0); } catch (_) {}
        return;
      }
      // --- EQ 10 bandas ---
      try {
        final eqF = f.parametricEqFilter;
        if (!eqF.isActive) eqF.activate();
        eqF.numBands(soundHandle: _handle).value = 10;
        eqF.wet(soundHandle: _handle).value = 1.0;
        for (int i = 0; i < 10; i++) {
          final g = eq.bands[i].clamp(0.0, 4.0);
          eqF.bandGain(i, soundHandle: _handle).value = g;
        }
      } catch (_) {}
      // --- Bass boost ---
      try {
        final bb = f.bassBoostFilter;
        if (eq.bassBoost) {
          if (!bb.isActive) bb.activate();
          bb.wet(soundHandle: _handle).value = 1.0;
          bb.boost(soundHandle: _handle).value = 3.0;
        } else {
          if (bb.isActive) bb.deactivate();
        }
      } catch (_) {}
      // --- Normalizar (limiter) ---
      try {
        final lim = f.limiterFilter;
        if (eq.normalize) {
          if (!lim.isActive) lim.activate();
          lim.wet(soundHandle: _handle).value = 1.0;
        } else {
          if (lim.isActive) lim.deactivate();
        }
      } catch (_) {}
      // --- Reverb ---
      try {
        final rv = f.freeverbFilter;
        if (eq.reverb == 'Ninguna') {
          if (rv.isActive) rv.deactivate();
        } else {
          if (!rv.isActive) rv.activate();
          rv.wet(soundHandle: _handle).value = 0.5;
          // Mapear preset a roomSize/damp
          double room = 0.5, damp = 0.5;
          switch (eq.reverb) {
            case 'Habitación':
              room = 0.4; damp = 0.5; break;
            case 'Catedral':
              room = 0.85; damp = 0.3; break;
            case 'Placa':
              room = 0.6; damp = 0.7; break;
            case 'Eco':
              room = 0.7; damp = 0.4; break;
          }
          rv.roomSize(soundHandle: _handle).value = room;
          rv.damp(soundHandle: _handle).value = damp;
          rv.width(soundHandle: _handle).value = 1.0;
        }
      } catch (_) {}
      // --- Velocidad ---
      try {
        SoLoud.instance.setRelativePlaySpeed(_handle!, eq.speed.clamp(0.5, 2.0));
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> playFromSession(PlaybackSession session, BaseItemDto? item, {Duration? start, double? volume}) async {
    _clearQueue();
    // Anti-solape: el OST del detalle y el fondo usan la misma voz SoLoud.
    try {
      await GameOstPlayer.instance.stop();
    } catch (_) {}
    try {
      await GameBgPlayer.instance.suspendForDetail();
    } catch (_) {}
    state = state.copyWith(item: item, session: session, error: null, clearError: true, completed: false, buffering: true, volume: volume ?? state.volume, clearOstCover: true);
    final isHls = session.streamUrl.contains('master.m3u8') || session.streamUrl.contains('.m3u8');

    // Intento SoLoud si no es HLS y está inicializado
    if (!isHls && _soloudReady) {
      try {
        // Limpiar fallback si estaba activo
        try {
          await _fallbackPlayer?.stop();
        } catch (_) {}
        // Limpiar soloud previo
        if (_handle != null) {
          try {
            SoLoud.instance.stop(_handle!);
          } catch (_) {}
          _handle = null;
        }
        if (_source != null) {
          try {
            SoLoud.instance.disposeSource(_source!);
          } catch (_) {}
          _source = null;
        }
        _stopPosTimer();

        // Habilitar visualización
        try {
          SoLoud.instance.setVisualizationEnabled(true);
        } catch (_) {}

        _source = await SoLoud.instance.loadUrl(session.streamUrl);
        final vol = (volume ?? state.volume).clamp(0, 100) / 100.0;
        _handle = SoLoud.instance.play(_source!, volume: vol);

        Duration? startPos = start ??
            (session.start != null && session.start! > Duration.zero ? session.start : null) ??
            _durationFromTicks(item?.userData?.playbackPositionTicks);

        if (startPos != null && startPos > Duration.zero) {
          try {
            SoLoud.instance.seek(_handle!, startPos);
          } catch (_) {}
        }

        Duration dur = Duration.zero;
        try {
          dur = SoLoud.instance.getLength(_source!);
        } catch (_) {}

        state = state.copyWith(playing: true, buffering: false, completed: false, duration: dur, engine: PlaybackEngine.soloud, volume: volume ?? state.volume);
        _startSoloudPosTimer();
        // Aplicar EQ / filtros actuales al nuevo handle
        try { _applyEq(ref.read(audioEqProvider)); } catch (_) {}
        return;
      } catch (e) {
        // Fallback a MediaKit: limpiar soloud parcial
        if (_handle != null) {
          try {
            SoLoud.instance.stop(_handle!);
          } catch (_) {}
          _handle = null;
        }
        if (_source != null) {
          try {
            SoLoud.instance.disposeSource(_source!);
          } catch (_) {}
          _source = null;
        }
        // Continuar a fallback
      }
    }

    // Fallback MediaKit (HLS o error SoLoud): aplicar siempre el volumen
    // efectivo (global si no se pasa explícito), no el 100 del Player nuevo.
    try {
      final p = _fallback;
      final startVol = (volume ?? state.volume).clamp(0, 100).toDouble();
      try {
        await p.setVolume(startVol);
      } catch (_) {}
      await p.open(
        Media(
          session.streamUrl,
          httpHeaders: const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
          },
        ),
      );
      await p.play();
      final startPos = start ?? (session.start != null && session.start! > Duration.zero ? session.start : null) ?? _durationFromTicks(item?.userData?.playbackPositionTicks);
      if (startPos != null && startPos > Duration.zero) {
        try {
          await p.stream.duration.firstWhere((d) => d > Duration.zero).timeout(const Duration(seconds: 5));
        } catch (_) {}
        await p.seek(startPos);
      }
      state = state.copyWith(playing: true, buffering: false, engine: PlaybackEngine.mediaKit, volume: volume ?? state.volume);
    } catch (e) {
      state = state.copyWith(error: '$e', buffering: false, engine: PlaybackEngine.none);
    }
  }

  /// Cola OST del Jukebox en el provider compartido (misma barra global).
  /// Cada pista abre su `stream_url` de ROMM con Bearer ([authToken]).
  /// Para el OST del detalle y el fondo antes de sonar (una sola voz).
  Future<void> playOstQueue({
    required List<GameOstTrack> tracks,
    int startIndex = 0,
    required String serverUrl,
    String? authToken,
    bool shuffle = false,
  }) async {
    if (tracks.isEmpty) return;
    try {
      await GameOstPlayer.instance.stop();
    } catch (_) {}
    try {
      await GameBgPlayer.instance.suspendForDetail();
    } catch (_) {}
    try {
      await _fallbackPlayer?.stop();
    } catch (_) {}
    _queue = [
      for (final t in tracks)
        _QueuedTrack(
          session: PlaybackSession(
            itemId: 'romm-${t.romFileId}',
            itemName: t.name,
            serverUrl: serverUrl,
            streamUrl: t.url,
          ),
          item: BaseItemDto(
            name: t.name,
            artists: t.artist?.isNotEmpty == true ? [t.artist!] : null,
          ),
          authToken: authToken,
          isFavorite: t.isFavorite,
          coverUrl: t.coverUrl?.isNotEmpty == true ? t.coverUrl : null,
        ),
    ];
    _order = List<int>.generate(_queue.length, (i) => i);
    if (shuffle) _order.shuffle();
    await _playQueuePos(
      shuffle ? 0 : startIndex.clamp(0, _queue.length - 1),
    );
  }

  /// Reproduce la posición [pos] del orden de cola.
  Future<void> _playQueuePos(int pos) async {
    if (_disposed || pos < 0 || pos >= _order.length) return;
    final myGen = ++_playGen;
    final entry = _queue[_order[pos]];
    state = state.copyWith(
      item: entry.item,
      session: entry.session,
      isFavorite: entry.isFavorite,
      ostCoverUrl: entry.coverUrl,
      clearOstCover: entry.coverUrl == null,
      error: null,
      clearError: true,
      completed: false,
      buffering: true,
    );
    try {
      await _fallbackPlayer?.stop();
    } catch (_) {}
    if (_handle != null) {
      try {
        SoLoud.instance.stop(_handle!);
      } catch (_) {}
      _handle = null;
    }
    if (_source != null) {
      try {
        SoLoud.instance.disposeSource(_source!);
      } catch (_) {}
      _source = null;
    }
    _stopPosTimer();
    if (!_soloudReady) {
      state = state.copyWith(
        error: 'Audio no disponible',
        buffering: false,
        engine: PlaybackEngine.none,
      );
      return;
    }
    try {
      try {
        SoLoud.instance.setVisualizationEnabled(true);
      } catch (_) {}
      final token = entry.authToken?.trim() ?? '';
      final client = token.isNotEmpty ? _RommAuthHttpClient(token) : null;
      try {
        _source = await SoLoud.instance.loadUrl(
          entry.session.streamUrl,
          httpClient: client,
        );
      } finally {
        try {
          client?.close();
        } catch (_) {}
      }
      if (_disposed || myGen != _playGen) {
        final fresh = _source;
        _source = null;
        if (fresh != null) {
          try {
            SoLoud.instance.disposeSource(fresh);
          } catch (_) {}
        }
        return;
      }
      final vol = state.volume.clamp(0, 100) / 100.0;
      _handle = SoLoud.instance.play(_source!, volume: vol);
      Duration dur = Duration.zero;
      try {
        dur = SoLoud.instance.getLength(_source!);
      } catch (_) {}
      _orderPos = pos;
      state = state.copyWith(
        playing: true,
        buffering: false,
        completed: false,
        duration: dur,
        engine: PlaybackEngine.soloud,
      );
      _startSoloudPosTimer();
      try {
        _applyEq(ref.read(audioEqProvider));
      } catch (_) {}
    } catch (e) {
      if (myGen != _playGen || _disposed) return;
      // Pista rota: salta a la siguiente como el player del detalle.
      if (pos + 1 < _order.length) {
        unawaited(_playQueuePos(pos + 1));
        return;
      }
      _clearQueue();
      state = state.copyWith(
        error: '$e',
        buffering: false,
        playing: false,
        engine: PlaybackEngine.none,
      );
    }
  }

  void _clearQueue() {
    _queue = [];
    _order = [];
    _orderPos = -1;
  }

  /// Fin de pista: avanza la cola o completa (y devuelve el fondo).
  void _onTrackEnded(Duration len) {
    if (_disposed) return;
    if (_queueActive && _orderPos + 1 < _order.length) {
      unawaited(_playQueuePos(_orderPos + 1));
      return;
    }
    _clearQueue();
    _stopPosTimer();
    state = state.copyWith(
      position: len,
      completed: true,
      playing: false,
      buffering: false,
    );
    try {
      unawaited(GameBgPlayer.instance.returnFromDetail());
    } catch (_) {}
  }

  /// Siguiente: avanza la cola si hay; si no, +10s (singles Jellyfin).
  void next() {
    if (!_queueActive) {
      seekBy(const Duration(seconds: 10));
      return;
    }
    if (_orderPos + 1 < _order.length) {
      unawaited(_playQueuePos(_orderPos + 1));
    } else {
      _onTrackEnded(state.duration);
    }
  }

  /// Anterior: retrocede la cola si hay; si no, −10s (singles Jellyfin).
  void previous() {
    if (!_queueActive) {
      seekBy(const Duration(seconds: -10));
      return;
    }
    unawaited(_playQueuePos((_orderPos - 1).clamp(0, _order.length - 1)));
  }

  /// Actualiza solo el estado de favorita (la escritura en ROMM la hace la UI).
  void updateFavorite(bool value) {
    state = state.copyWith(isFavorite: value);
  }

  void pause() {
    if (state.engine == PlaybackEngine.soloud && _handle != null) {
      try {
        SoLoud.instance.pauseSwitch(_handle!);
      } catch (_) {}
      state = state.copyWith(playing: false);
      return;
    }
    if (state.engine == PlaybackEngine.mediaKit) {
      try {
        _fallback.pause();
      } catch (_) {}
      state = state.copyWith(playing: false);
      return;
    }
  }

  /// Vuelve a reproducir desde el inicio tras completarse.
  ///
  /// Al terminar, el voice-handle de SoLoud queda muerto: `seek`/`resume`
  /// sobre él son no-ops y el timer de posición está parado. Hay que
  /// soltar la voz muerta y lanzar `play` de nuevo sobre la fuente ya
  /// cargada (sin recargar la URL).
  Future<void> replay() async {
    if (state.engine == PlaybackEngine.soloud && _source != null) {
      if (_handle != null) {
        try {
          SoLoud.instance.stop(_handle!);
        } catch (_) {}
        _handle = null;
      }
      try {
        final vol = state.volume.clamp(0, 100) / 100.0;
        _handle = SoLoud.instance.play(_source!, volume: vol);
        try {
          _applyEq(ref.read(audioEqProvider));
        } catch (_) {}
        state = state.copyWith(
          playing: true,
          completed: false,
          buffering: false,
          position: Duration.zero,
          error: null,
          clearError: true,
        );
        _startSoloudPosTimer();
      } catch (e) {
        state = state.copyWith(error: '$e', buffering: false, playing: false);
      }
      return;
    }
    if (state.engine == PlaybackEngine.mediaKit) {
      try {
        await _fallback.seek(Duration.zero);
      } catch (_) {}
      try {
        await _fallback.play();
      } catch (_) {}
      state = state.copyWith(
        playing: true,
        completed: false,
        position: Duration.zero,
      );
      return;
    }
  }

  void resume() {
    if (state.completed) {
      replay();
      return;
    }
    if (state.engine == PlaybackEngine.soloud && _handle != null) {
      try {
        SoLoud.instance.pauseSwitch(_handle!);
      } catch (_) {}
      state = state.copyWith(playing: true);
      return;
    }
    if (state.engine == PlaybackEngine.mediaKit) {
      try {
        _fallback.play();
      } catch (_) {}
      state = state.copyWith(playing: true);
      return;
    }
  }

  void toggle() {
    if (state.completed) {
      replay();
      return;
    }
    if (state.playing) {
      pause();
    } else {
      resume();
    }
  }

  void stop({bool resumeBackground = true}) {
    _clearQueue();
    _playGen++;
    _stopPosTimer();
    final keptVolume = state.volume;
    if (_handle != null) {
      try {
        SoLoud.instance.stop(_handle!);
      } catch (_) {}
      _handle = null;
    }
    if (_source != null) {
      try {
        SoLoud.instance.disposeSource(_source!);
      } catch (_) {}
      _source = null;
    }
    try {
      _fallbackPlayer?.stop();
    } catch (_) {}
    // Parar no resetea el volumen universal: la siguiente canción lo hereda.
    state = SoloudMusicState(volume: keptVolume);
    if (resumeBackground) {
      try {
        unawaited(GameBgPlayer.instance.returnFromDetail());
      } catch (_) {}
    }
  }

  void seek(Duration pos) {
    if (state.engine == PlaybackEngine.soloud && _handle != null) {
      try {
        SoLoud.instance.seek(_handle!, pos);
      } catch (_) {}
      state = state.copyWith(position: pos);
      return;
    }
    if (state.engine == PlaybackEngine.mediaKit) {
      try {
        _fallback.seek(pos);
      } catch (_) {}
      state = state.copyWith(position: pos);
      return;
    }
  }

  void setVolume(double v) {
    final clamped = v.clamp(0, 100).toDouble();
    // Publica al volumen universal (el listener lo reaplica sin bucle).
    try {
      ref.read(appVolumeProvider.notifier).setVolume(clamped);
    } catch (_) {}
    if (state.engine == PlaybackEngine.soloud && _handle != null) {
      try {
        SoLoud.instance.setVolume(_handle!, clamped / 100.0);
      } catch (_) {}
      state = state.copyWith(volume: clamped);
      return;
    }
    if (state.engine == PlaybackEngine.mediaKit) {
      try {
        _fallback.setVolume(clamped);
      } catch (_) {}
      state = state.copyWith(volume: clamped);
      return;
    }
    // Sin engine activo: solo guarda volumen
    state = state.copyWith(volume: clamped);
    // También aplica a ambos para siguiente play
    try {
      if (_handle != null) SoLoud.instance.setVolume(_handle!, clamped / 100.0);
    } catch (_) {}
    try {
      _fallbackPlayer?.setVolume(clamped);
    } catch (_) {}
  }

  void seekBy(Duration delta) {
    var ms = (state.position + delta).inMilliseconds;
    if (ms < 0) ms = 0;
    if (state.duration.inMilliseconds > 0 && ms > state.duration.inMilliseconds) ms = state.duration.inMilliseconds;
    seek(Duration(milliseconds: ms));
  }

  Future<void> playRadioUrl({required String url, required String title, String artist = '', String coverUrl = '', double? volume}) async {
    _clearQueue();
    try {
      await GameOstPlayer.instance.stop();
    } catch (_) {}
    try {
      await GameBgPlayer.instance.suspendForDetail();
    } catch (_) {}
    final session = PlaybackSession(serverUrl: '', streamUrl: url, itemId: 'radio', itemName: title);
    // La radio siempre va directa por MediaKit: SoLoud no maneja estos
    // streams (los efectos visuales usan la señal sintética).
    developer.log('[Radio] MediaKit open: $url', name: 'Radio');
    state = state.copyWith(session: session, item: null, error: null, clearError: true, completed: false, buffering: true, volume: volume ?? state.volume, engine: PlaybackEngine.mediaKit);
    if (_handle != null) { try { SoLoud.instance.stop(_handle!); } catch (_) {} _handle = null; }
    if (_source != null) { try { SoLoud.instance.disposeSource(_source!); } catch (_) {} _source = null; }
    _stopPosTimer();
    try {
      final p = _fallback;
      if (volume != null) { try { await p.setVolume(volume); } catch (_) {} }
      await p.open(Media(url, httpHeaders: const {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'}));
      await p.play();
      developer.log('[Radio] MediaKit playing OK', name: 'Radio');
      state = state.copyWith(playing: true, buffering: false, engine: PlaybackEngine.mediaKit, volume: volume ?? state.volume);
    } catch (e) {
      developer.log('[Radio] MediaKit fallo: $e', name: 'Radio');
      state = state.copyWith(error: '$e', buffering: false, engine: PlaybackEngine.none);
    }
  }

  /// Para AudioFlux: expone si SoLoud está activo y sonando.
  bool get isSoloudActive => state.isSoloud && state.playing && _handle != null && _soloudReady;
}

final soloudMusicProvider = NotifierProvider<SoloudMusicController, SoloudMusicState>(SoloudMusicController.new);
