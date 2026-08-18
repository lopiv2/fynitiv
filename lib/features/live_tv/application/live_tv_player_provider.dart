import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart'
    hide MediaSourceType;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/di/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../library/application/library_providers.dart'
    hide jellyfinClientProvider;
import '../domain/channel.dart';
import '../domain/media_source_type.dart';

/// Resuelve la URL del stream de un canal de Live TV de Jellyfin. A diferencia
/// de los VOD, aquí hay que abrir el live stream explícitamente con
/// `autoOpenLiveStream` para que el servidor asigne un `LiveStreamId`.
///
/// Es una función plana (no un provider) para no notificar estado mientras se
/// construye el widget tree: `playChannel` la invoca directamente.
Future<String?> resolveLiveChannelStreamUrl(
  Ref ref,
  String channelId,
) async {
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
  if (source == null || source.id == null) return null;

  final token = await ref.read(sessionStorageProvider).readToken();
  final apiKey = (token == null || token.isEmpty) ? '' : '&api_key=$token';
  final liveStream = (source.liveStreamId ?? '').isNotEmpty
      ? '&LiveStreamId=${source.liveStreamId}'
      : '';

  if (source.supportsDirectPlay == true) {
    return '$serverUrl/Videos/$channelId/stream?static=true'
        '&MediaSourceId=${source.id}$liveStream$apiKey';
  }
  return '$serverUrl/Videos/$channelId/master.m3u8'
      '?MediaSourceId=${source.id}$liveStream$apiKey';
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
    _player = Player();
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
      state = state.copyWith(playing: playing, buffering: false);
    });
    // Sin esto, un fallo del stream (URL inválida, formato rechazado,
    // transcodificación fallida...) se pierde en silencio: nunca llega
    // `playing = true`, así que `buffering` se quedaba en `true` para
    // siempre y el spinner de LivePreview tapaba el vídeo indefinidamente
    // sin ninguna pista de qué había fallado.
    _errorSub = _player!.stream.error.listen((e) {
      if (state.channelId == null) return;
      state = state.copyWith(buffering: false, error: () => e);
    });
    // El stream de `buffering` nativo cubre también los cortes momentáneos
    // una vez ya en reproducción (no solo el arranque inicial del canal).
    _bufferingSub = _player!.stream.buffering.listen((b) {
      if (state.channelId == null) return;
      state = state.copyWith(buffering: b);
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
    state = LiveTvPlayerState(channelId: channel.id, buffering: true);

    String? url = channel.streamUrl;
    if (url == null && channel.sourceType == MediaSourceType.jellyfin) {
      url = await resolveLiveChannelStreamUrl(ref, channel.sourceId);
    }
    if (url == null || url.isEmpty) {
      state = state.copyWith(
        buffering: false,
        error: () => Exception('Sin URL de stream'),
      );
      return;
    }
    try {
      await player.open(Media(url));
      await player.setVolume(0);
      await player.play();
    } catch (e) {
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