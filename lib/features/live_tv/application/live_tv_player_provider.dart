import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' hide MediaSourceType;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/debug/live_tv_log.dart';
import '../../../core/di/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../library/application/library_providers.dart'
    hide jellyfinClientProvider;
import '../domain/channel.dart';
import '../domain/media_source_type.dart';

/// Sondea la URL del stream con el propio cliente autenticado de la app y
/// registra qué responde el servidor (manifiesto m3u8, error HTML/JSON o
/// binario). Solo lee el master (inofensivo): no re-consume variantes porque
/// Jellyfin gestiona una sola sesión por LiveStreamId y una segunda lectura
/// rompería la reproducción real.
Future<void> probeStreamUrl(Ref ref, String url) async {
  final client = ref.watch(jellyfinClientProvider);
  if (client == null) return;
  final sw = Stopwatch()..start();
  try {
    final response = await client.dio.get<Object?>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
      ),
    );
    final headers = response.headers;
    final contentType =
        headers.value(Headers.contentTypeHeader) ?? '<sin content-type>';
    liveTvLog(
      'probe ${redactUrl(url)}: status=${response.statusCode} '
      'content-type=$contentType (${sw.elapsedMilliseconds}ms)',
    );

    final streamed = response.data;
    if (streamed is ResponseBody) {
      final first = <int>[];
      await for (final chunk in streamed.stream) {
        first.addAll(chunk);
        if (first.length >= 1500) break;
      }
      final head = latin1
          .decode(first.take(1500).toList())
          .replaceAll(RegExp(r'[^\x20-\x7E\r\n]'), '.')
          .trim();
      liveTvLog(
        'probe cuerpo (primeros bytes): ${head.replaceAll('\n', ' | ')}',
      );
    }
  } on DioException catch (e) {
    liveTvLog(
      'probe ${redactUrl(url)}: DioException '
      'status=${e.response?.statusCode} ${e.type.name} ${e.message}',
    );
  } catch (e) {
    liveTvLog('probe ${redactUrl(url)}: error inesperado: $e');
  }
}

/// Resuelve la URL del stream de un canal de Live TV de Jellyfin. A diferencia
/// de los VOD, aquí hay que abrir el live stream explícitamente con
/// `autoOpenLiveStream` para que el servidor asigne un `LiveStreamId`.
///
/// Es una función plana (no un provider) para no notificar estado mientras se
/// construye el widget tree: `playChannel` la invoca directamente.
Future<String?> resolveLiveChannelStreamUrl(Ref ref, String channelId) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  final serverUrl = ref.watch(authServerUrlProvider);
  if (client == null || userId == null || serverUrl == null) return null;

  final info = await client.getMediaInfoApi().getPostedPlaybackInfo(
    itemId: channelId,
    playbackInfoDto: PlaybackInfoDto(
      userId: userId,
      autoOpenLiveStream: true,
      enableDirectPlay: true,
      enableDirectStream: true,
      enableTranscoding: true,
    ),
  );
  final source = info.data?.mediaSources?.firstOrNull;
  if (source == null || source.id == null) {
    liveTvLog(
      'resolveLiveChannelStreamUrl: sin media source para $channelId '
      '(sources=${info.data?.mediaSources?.length ?? 0})',
    );
    return null;
  }
  liveTvLog(
    'PlaybackInfo $channelId: container=${source.container} '
    'liveStreamId=${source.liveStreamId} directPlay=${source.supportsDirectPlay} '
    'protocol=${source.protocol}',
  );

  final token = await ref.read(sessionStorageProvider).readToken();
  final apiKey = (token == null || token.isEmpty) ? '' : '&api_key=$token';
  final liveStream = (source.liveStreamId ?? '').isNotEmpty
      ? '&LiveStreamId=${source.liveStreamId}'
      : '';

  // Con contenedor HLS, el "direct play" estático devuelve el master del
  // proveedor IPTV con URLs de variante RELATIVAS (p.ej. "WildEarth360.m3u8")
  // que mpv resuelve contra la URL de Jellyfin -> 404 -> sin pistas. En
  // Jellyfin web funciona porque hls.js las resuelve contra el proveedor. El
  // HLS generado por Jellyfin (`master.m3u8`) tampoco sirve: sus variantes
  // (`live.m3u8?...`) salen SIN `api_key` y la auth por cabecera de media_kit
  // no se aplica -> 500. Para canales HLS probamos el stream directo NO
  // estático (`/Videos/{id}/stream`), que Jellyfin remuxea a un flujo continuo
  // (MPEG-TS) con la auth solo en la URL inicial, sin sub-requests.
  final isHlsContainer = (source.container ?? '').toLowerCase() == 'hls';
  if (source.supportsDirectPlay == true && !isHlsContainer) {
    final url =
        '$serverUrl/Videos/$channelId/stream?static=true'
        '&MediaSourceId=${source.id}$liveStream$apiKey';
    liveTvLog('URL direct-play: ${redactUrl(url)}');
    return url;
  }
  if (isHlsContainer) {
    final url =
        '$serverUrl/Videos/$channelId/stream'
        '?MediaSourceId=${source.id}$liveStream$apiKey';
    liveTvLog('URL stream continuo (HLS): ${redactUrl(url)}');
    return url;
  }
  final url =
      '$serverUrl/Videos/$channelId/master.m3u8'
      '?MediaSourceId=${source.id}$liveStream$apiKey';
  liveTvLog('URL transcode: ${redactUrl(url)}');
  return url;
}

/// Estado del reproductor compartido de Live TV.
class LiveTvPlayerState {
  const LiveTvPlayerState({
    this.channelId,
    this.buffering = false,
    this.playing = false,
    this.error,
  });

  final String? channelId;
  final bool buffering;
  final bool playing;
  final Object? error;

  LiveTvPlayerState copyWith({
    String? Function()? channelId,
    bool? buffering,
    bool? playing,
    Object? Function()? error,
  }) {
    return LiveTvPlayerState(
      channelId: channelId != null ? channelId() : this.channelId,
      buffering: buffering ?? this.buffering,
      playing: playing ?? this.playing,
      error: error != null ? error() : this.error,
    );
  }
}

/// Motor de vídeo compartido: un único `Player`/`VideoController` de media_kit
/// sirve a la preview, al reproductor flotante y a la pantalla completa.
class LiveTvPlayerController extends Notifier<LiveTvPlayerState> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<Tracks>? _tracksSub;
  StreamSubscription<VideoParams>? _videoParamsSub;
  StreamSubscription<AudioParams>? _audioParamsSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerLog>? _logSub;
  int _lastLogMinute = -1;

  Player get player {
    _ensurePlayer();
    return _player!;
  }

  VideoController get videoController {
    _ensurePlayer();
    return _videoController!;
  }

  void _ensurePlayer() {
    if (_player != null) return;
    // Con kLiveTvVerbose se sube el nivel de log de mpv para diagnosticar
    // fallos de red/demux; en uso normal se deja el nivel por defecto (error).
    _player = Player(
      configuration: kLiveTvVerbose
          ? const PlayerConfiguration(logLevel: MPVLogLevel.v)
          : const PlayerConfiguration(),
    );
    // El arranque de la transcodificación en vivo de Jellyfin puede tardar más
    // del `network-timeout` por defecto de media_kit (5s): sin esto, mpv aborta
    // el master.m3u8 con "Failed to open" aunque el servidor responda bien.
    final platform = _player!.platform;
    if (platform is NativePlayer) {
      unawaited(platform.setProperty('network-timeout', '30'));
    }
    _videoController = VideoController(
      _player!,
      configuration: const VideoControllerConfiguration(
        hwdec: 'auto-copy',
        // Sin esto, media_kit_video depende de que el primer `Video` widget
        // montado reporte su tamaño de layout para negociar la superficie
        // Direct3D con la textura nativa. Ese primer reporte está llegando
        // en 0x0 de forma consistente (en frío, en dos pantallas distintas
        // que comparten este mismo controller) — probablemente porque el
        // controller se crea al leer `.videoController` ANTES de que exista
        // ningún `Video` widget real en el árbol (p. ej. en LivePreview,
        // incluso con `channel == null`). Fijar un tamaño de textura
        // explícito evita depender de esa negociación automática: el widget
        // `Video` sigue escalando el contenido a su propio tamaño de
        // pantalla (BoxFit.contain por defecto), esto solo fija la
        // resolución de la textura interna.
        width: 1920,
        height: 1080,
      ),
    );
    _playingSub = _player!.stream.playing.listen((playing) {
      if (state.channelId == null) return;
      liveTvLog('playing=${state.channelId} $playing');
      state = state.copyWith(playing: playing, buffering: false);
    });
    // Sin esto, un fallo del stream (URL inválida, formato rechazado,
    // transcodificación fallida...) se pierde en silencio: nunca llega
    // `playing = true`, así que `buffering` se quedaba en `true` para
    // siempre y el spinner de LivePreview tapaba el vídeo indefinidamente
    // sin ninguna pista de qué había fallado.
    _errorSub = _player!.stream.error.listen((e) {
      if (state.channelId == null) return;
      liveTvLog('error stream=${state.channelId}: $e');
      state = state.copyWith(buffering: false, error: () => e);
    });
    // El stream de `buffering` nativo cubre también los cortes momentáneos
    // una vez ya en reproducción (no solo el arranque inicial del canal).
    _bufferingSub = _player!.stream.buffering.listen((b) {
      if (state.channelId == null) return;
      if (b) liveTvLog('buffering=${state.channelId} true');
      state = state.copyWith(buffering: b);
    });
    // Pistas detectadas por mpv. Con HLS de Jellyfin conviene confirmar que
    // hay una pista de VÍDEO real: si solo llega audio, el stream se reproduce
    // (playing=true) pero no hay imagen que pintar.
    _tracksSub = _player!.stream.tracks.listen((tracks) {
      if (state.channelId == null) return;
      liveTvLog(
        'tracks ${state.channelId}: video=['
        '${tracks.video.map((v) => '${v.codec} ${v.w}x${v.h}').join(', ')}] '
        'audio=[${tracks.audio.map((a) => a.codec).join(', ')}]',
      );
    });
    // Parámetros del vídeo YA decodificado: si no emite, mpv no está sacando
    // fotogramas (decoder o hwdec fallando).
    _videoParamsSub = _player!.stream.videoParams.listen((vp) {
      if (state.channelId == null) return;
      liveTvLog(
        'videoParams ${state.channelId}: ${vp.w}x${vp.h} '
        'pixel=${vp.pixelformat} hw=${vp.hwPixelformat} aspect=${vp.aspect}',
      );
    });
    _audioParamsSub = _player!.stream.audioParams.listen((ap) {
      if (state.channelId == null) return;
      liveTvLog(
        'audioParams ${state.channelId}: ${ap.format} '
        '${ap.sampleRate}Hz ${ap.channels}',
      );
    });
    // La posición avanzando confirma que el demuxer decodifica; si se queda
    // clavada en 0 con playing=true, el stream no está entregando frames.
    _positionSub = _player!.stream.position.listen((pos) {
      if (state.channelId == null) return;
      final minute = pos.inMinutes;
      if (minute != _lastLogMinute) {
        _lastLogMinute = minute;
        liveTvLog('position ${state.channelId}: ${pos.inSeconds}s');
      }
    });
    // Logs internos de mpv: los de nivel warn/error suelen explicar fallos de
    // decode, hwdec o red que `stream.error` no captura.
    _logSub = _player!.stream.log.listen((pl) {
      if (kLiveTvVerbose) {
        if (pl.level == 'fatal' ||
            pl.level == 'error' ||
            pl.level == 'warn' ||
            pl.text.toLowerCase().contains('http') ||
            pl.text.toLowerCase().contains('open') ||
            pl.text.toLowerCase().contains('fail')) {
          liveTvLog('mpv[${pl.level}] ${pl.text.trim()}');
        }
      } else if (pl.level == 'warn' ||
          pl.level == 'error' ||
          pl.level == 'fatal') {
        liveTvLog('mpv[${pl.level}] ${pl.text.trim()}');
      }
    });
  }

  @override
  LiveTvPlayerState build() {
    ref.onDispose(() {
      _disposePlayer();
    });
    return const LiveTvPlayerState();
  }

  Future<void> _disposePlayer() async {
    _playingSub?.cancel();
    _playingSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    _bufferingSub?.cancel();
    _bufferingSub = null;
    _tracksSub?.cancel();
    _tracksSub = null;
    _videoParamsSub?.cancel();
    _videoParamsSub = null;
    _audioParamsSub?.cancel();
    _audioParamsSub = null;
    _positionSub?.cancel();
    _positionSub = null;
    _logSub?.cancel();
    _logSub = null;
    final p = _player;
    _player = null;
    _videoController = null;
    if (p != null) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }

  /// Abre el canal en el motor compartido. La preview arranca en silencio.
  Future<void> playChannel(Channel channel) async {
    if (channel.id == state.channelId && _player?.state.playing == true) return;
    liveTvLog(
      'playChannel: ${channel.name} (id=${channel.id} '
      'type=${channel.sourceType.name} streamUrl=${redactUrl(channel.streamUrl)})',
    );
    state = LiveTvPlayerState(channelId: channel.id, buffering: true);

    String? url = channel.streamUrl;
    if (url == null && channel.sourceType == MediaSourceType.jellyfin) {
      url = await resolveLiveChannelStreamUrl(ref, channel.sourceId);
    }
    if (url == null || url.isEmpty) {
      liveTvLog('playChannel ${channel.name}: sin URL de stream');
      state = state.copyWith(
        buffering: false,
        error: () => Exception('Sin URL de stream'),
      );
      return;
    }
    try {
      liveTvLog('playChannel ${channel.name}: abriendo ${redactUrl(url)}');
      // Diagnóstico (solo con kLiveTvVerbose): mira qué devuelve el servidor
      // en esa URL sin esperar el arranque de reproducción.
      if (kLiveTvVerbose && channel.sourceType == MediaSourceType.jellyfin) {
        unawaited(probeStreamUrl(ref, url));
      }
      await player.open(Media(url));
      liveTvLog('playChannel ${channel.name}: open OK');
      await player.setVolume(0);
      await player.play();
      liveTvLog('playChannel ${channel.name}: play OK');
    } catch (e, st) {
      liveTvLog(
        'playChannel ${channel.name}: fallo al reproducir',
        error: e,
        stack: st,
      );
      state = state.copyWith(buffering: false, error: () => e);
    }
  }

  Future<void> setMuted(bool muted) => player.setVolume(muted ? 0 : 100);

  Future<void> togglePlay() {
    if (player.state.playing) return player.pause();
    return player.play();
  }

  Future<void> stop() async {
    state = const LiveTvPlayerState();
    final p = _player;
    if (p != null) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  /// Libera todos los recursos nativos del reproductor. El provider sigue vivo
  /// y recreará el player bajo demanda la próxima vez que se acceda a él.
  Future<void> close() async {
    state = const LiveTvPlayerState();
    await _disposePlayer();
  }
}

final liveTvPlayerProvider =
    NotifierProvider<LiveTvPlayerController, LiveTvPlayerState>(
      LiveTvPlayerController.new,
    );
