import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/archive_ost/archive_ost_repository.dart';
import '../domain/game_ost_track.dart';
import 'romm_providers.dart';

final archiveOstRepositoryProvider = Provider<ArchiveOstRepository>(
  (ref) => ArchiveOstRepository(),
);

/// Pistas de OST (archive.org) para un juego por su id (usa su nombre).
final ostTracksProvider = FutureProvider.family<List<GameOstTrack>, int>((
  ref,
  gameId,
) async {
  final game = await ref.watch(rommGameProvider(gameId).future);
  final name = game.name.trim();
  if (name.isEmpty) return [];
  return ref.read(archiveOstRepositoryProvider).searchAndGetTracks(name);
});
