import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lrclib_repository.dart';

final lrclibRepositoryProvider = Provider<LrclibRepository>((ref) => LrclibRepository());

class LrcQuery {
  const LrcQuery({required this.artist, required this.track, this.album, this.duration});
  final String artist;
  final String track;
  final String? album;
  final Duration? duration;

  @override
  bool operator ==(Object other) =>
      other is LrcQuery && other.artist == artist && other.track == track && other.album == album && other.duration == duration;

  @override
  int get hashCode => Object.hash(artist, track, album, duration);
}

final lrcLyricsProvider = FutureProvider.family<LrcResult?, LrcQuery>((ref, q) async {
  final repo = ref.watch(lrclibRepositoryProvider);
  // Cache 10 min
  ref.keepAlive();
  return repo.fetch(artist: q.artist, track: q.track, album: q.album, duration: q.duration);
});

// Toggle para mostrar/ocultar lyrics en el player fullscreen
class ShowLyricsNotifier extends Notifier<bool> {
  @override
  bool build() => true; // por defecto ON

  void toggle() => state = !state;
  void set(bool v) => state = v;
}

final showLyricsProvider = NotifierProvider<ShowLyricsNotifier, bool>(ShowLyricsNotifier.new);
