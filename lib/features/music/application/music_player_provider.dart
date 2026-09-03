import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:media_kit/media_kit.dart';

import '../../library/application/image_url.dart';
import '../../player/application/playback_provider.dart';

/// Estado del mini reproductor global de música.
class MusicPlayerState {
  const MusicPlayerState({
    this.item,
    this.session,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.error,
    this.completed = false,
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

  bool get hasItem => item != null && session != null;

  String get coverUrl {
    if (item == null || session == null) return '';
    return itemImageUrl(session!.serverUrl, item!, maxWidth: 400);
  }

  String get title => item?.name ?? session?.itemName ?? '';
  String get artist => item?.artists?.join(', ') ?? '';

  MusicPlayerState copyWith({
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
  }) {
    return MusicPlayerState(
      item: item ?? this.item,
      session: session ?? this.session,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      error: clearError ? null : (error ?? this.error),
      completed: completed ?? this.completed,
    );
  }
}

class MusicPlayerController extends Notifier<MusicPlayerState> {
  Player? _player;
  final List<StreamSubscription> _subs = [];
  bool _disposed = false;

  Player get player {
    _player ??= Player();
    _ensureSubs();
    return _player!;
  }

  void _ensureSubs() {
    if (_subs.isNotEmpty) return;
    final p = _player!;
    _subs.add(p.stream.playing.listen((v) {
      if (!_disposed) state = state.copyWith(playing: v);
    }));
    _subs.add(p.stream.position.listen((pos) {
      if (!_disposed) state = state.copyWith(position: pos);
    }));
    _subs.add(p.stream.duration.listen((dur) {
      if (!_disposed) state = state.copyWith(duration: dur);
    }));
    _subs.add(p.stream.buffering.listen((b) {
      if (!_disposed) state = state.copyWith(buffering: b);
    }));
    _subs.add(p.stream.completed.listen((c) {
      if (!_disposed) state = state.copyWith(completed: c, playing: c ? false : state.playing);
    }));
    _subs.add(p.stream.error.listen((e) {
      if (!_disposed) state = state.copyWith(error: e);
    }));
    _subs.add(p.stream.volume.listen((v) {
      if (!_disposed) state = state.copyWith(volume: v);
    }));
  }

  @override
  MusicPlayerState build() {
    // Mantener vivo aunque no haya listeners (para segundo plano)
    ref.keepAlive();
    ref.onDispose(() {
      _disposed = true;
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
      // No dispose del Player aquí para permitir que siga sonando si se
      // navega fuera del shell y se recrea el provider. Se libera con stop().
    });
    return const MusicPlayerState();
  }

  Future<void> playFromSession(PlaybackSession session, BaseItemDto? item, {Duration? start, double? volume}) async {
    final p = player;
    state = state.copyWith(item: item, session: session, error: null, clearError: true, completed: false, volume: volume ?? state.volume);
    try {
      // Aplica volumen heredado antes de abrir para no solapar con el grande
      if (volume != null) {
        try {
          await p.setVolume(volume);
        } catch (_) {}
      }
      await p.open(
        Media(
          session.streamUrl,
          httpHeaders: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
          },
        ),
      );
      await p.play();
      // Seek si hay posición de continuación
      final startPos = start ??
          (session.start != null && session.start! > Duration.zero ? session.start : null) ??
          _durationFromTicks(item?.userData?.playbackPositionTicks);
      if (startPos != null && startPos > Duration.zero) {
        // Esperar a que conozca duración
        try {
          await p.stream.duration.firstWhere((d) => d > Duration.zero).timeout(const Duration(seconds: 5));
        } catch (_) {}
        await p.seek(startPos);
      }
      state = state.copyWith(playing: true, volume: volume ?? state.volume);
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  void pause() {
    try {
      player.pause();
    } catch (_) {}
    state = state.copyWith(playing: false);
  }

  Duration? _durationFromTicks(int? ticks) {
    if (ticks == null || ticks <= 0) return null;
    return Duration(microseconds: ticks ~/ 10);
  }

  void toggle() {
    if (state.completed) {
      player.seek(Duration.zero);
      player.play();
      state = state.copyWith(completed: false);
      return;
    }
    if (state.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  void stop() {
    try {
      player.stop();
    } catch (_) {}
    state = const MusicPlayerState();
  }

  void seek(Duration pos) {
    player.seek(pos);
    state = state.copyWith(position: pos);
  }

  void setVolume(double v) {
    player.setVolume(v);
    state = state.copyWith(volume: v);
  }

  void seekBy(Duration delta) {
    var ms = (state.position + delta).inMilliseconds;
    if (ms < 0) ms = 0;
    if (state.duration.inMilliseconds > 0 && ms > state.duration.inMilliseconds) ms = state.duration.inMilliseconds;
    seek(Duration(milliseconds: ms));
  }
}

final musicPlayerProvider = NotifierProvider<MusicPlayerController, MusicPlayerState>(
  MusicPlayerController.new,
);
