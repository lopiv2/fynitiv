import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/game_ost_track.dart';
import 'romm_providers.dart';

/// Pistas de la Music API de ROMM para un juego (carpeta `soundtrack/`
/// junto a la ROM en el NAS). Vacío si el juego no tiene banda sonora.
final ostTracksProvider = FutureProvider.family<List<GameOstTrack>, int>((
  ref,
  gameId,
) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) return [];
  final items = await repo.getSoundtrackTracks(gameId);
  return [
    for (final t in items)
      GameOstTrack(
        name: t.displayName,
        url: t.streamUrl,
        duration: t.displayDuration,
        artist: t.artist,
        album: t.album,
        romFileId: t.romFileId,
        isFavorite: t.isFavorite,
        gameName: t.gameName,
      ),
  ];
});
