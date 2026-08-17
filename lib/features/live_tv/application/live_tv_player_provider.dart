import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../player/application/playback_provider.dart';
import '../domain/channel.dart';
import '../domain/media_source_type.dart';

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
  late final Player _player;
  late final VideoController _videoController;
  StreamSubscription<bool>? _playingSub;

  Player get player => _player;
  VideoController get videoController => _videoController;

  @override
  LiveTvPlayerState build() {
    _player = Player();
    _videoController = VideoController(_player);
    _playingSub = _player.stream.playing.listen((playing) {
      final id = state.channelId;
      if (id == null) return;
      state = state.copyWith(
        playing: playing,
        buffering: false,
        error: () => null,
      );
    });
    ref.onDispose(() {
      _playingSub?.cancel();
      _player.dispose();
    });
    return const LiveTvPlayerState();
  }

  /// Abre el canal en el motor compartido. La preview arranca en silencio.
  Future<void> playChannel(Channel channel) async {
    if (channel.id == state.channelId && _player.state.playing) return;
    state = LiveTvPlayerState(channelId: channel.id, buffering: true);

    String? url = channel.streamUrl;
    if (url == null && channel.sourceType == MediaSourceType.jellyfin) {
      final session =
          await ref.read(playbackSessionProvider(channel.sourceId).future);
      url = session?.streamUrl;
    }
    if (url == null || url.isEmpty) {
      state = state.copyWith(
        buffering: false,
        error: () => Exception('Sin URL de stream'),
      );
      return;
    }
    try {
      await _player.open(Media(url));
      await _player.setVolume(0);
      await _player.play();
    } catch (e) {
      state = state.copyWith(buffering: false, error: () => e);
    }
  }

  Future<void> setMuted(bool muted) => _player.setVolume(muted ? 0 : 100);

  Future<void> togglePlay() {
    if (_player.state.playing) return _player.pause();
    return _player.play();
  }

  Future<void> stop() {
    state = const LiveTvPlayerState();
    return _player.stop();
  }
}

final liveTvPlayerProvider =
    NotifierProvider<LiveTvPlayerController, LiveTvPlayerState>(
  LiveTvPlayerController.new,
);
