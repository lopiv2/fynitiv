import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/game_ost_track.dart';
import '../domain/romm_music_facet.dart';
import '../domain/romm_soundtrack_track.dart';
import 'romm_providers.dart';

/// Consulta de temas del Jukebox: filtros de `GET /api/music/tracks`
/// (o de `/favorites` con [favoritesOnly]).
class JukeboxTracksQuery {
  const JukeboxTracksQuery({
    this.search = '',
    this.artist,
    this.album,
    this.genre,
    this.year,
    this.minYear,
    this.maxYear,
    this.platformIds,
    this.favoritesOnly = false,
  });

  final String search;
  final String? artist;
  final String? album;
  final String? genre;
  final int? year;
  final int? minYear;
  final int? maxYear;
  final List<int>? platformIds;
  final bool favoritesOnly;

  @override
  bool operator ==(Object other) {
    return other is JukeboxTracksQuery &&
        other.search == search &&
        other.artist == artist &&
        other.album == album &&
        other.genre == genre &&
        other.year == year &&
        other.minYear == minYear &&
        other.maxYear == maxYear &&
        other.favoritesOnly == favoritesOnly &&
        _listEq(other.platformIds, platformIds);
  }

  bool _listEq(List<int>? a, List<int>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    search,
    artist,
    album,
    genre,
    year,
    minYear,
    maxYear,
    favoritesOnly,
    platformIds == null ? null : Object.hashAll(platformIds!),
  );
}

GameOstTrack _toOstTrack(RommSoundtrackTrack t) => GameOstTrack(
  name: t.displayName,
  url: t.streamUrl,
  duration: t.displayDuration,
  artist: t.artist,
  album: t.album,
  romFileId: t.romFileId,
  isFavorite: t.isFavorite,
  gameName: t.gameName,
);

/// Totales globales del Jukebox (`GET /api/music/stats`).
final jukeboxStatsProvider = FutureProvider<MusicStats>((ref) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) throw StateError('No hay sesión ROMM');
  return repo.getMusicStats();
});

/// Juegos con banda sonora (`GET /api/music/games`), filtrados por [search].
final jukeboxGamesProvider =
    FutureProvider.family<List<MusicGameEntry>, String>((ref, search) async {
      final repo = ref.watch(rommRepositoryProvider);
      if (repo == null) return [];
      return repo.getMusicGames(search: search.isEmpty ? null : search);
    });

/// Facet de tags (`GET /api/music/artists|albums|genres|years`).
/// [field] es el segmento de la ruta.
final jukeboxFacetProvider =
    FutureProvider.family<List<MusicFacetValue>, String>((ref, field) async {
      final repo = ref.watch(rommRepositoryProvider);
      if (repo == null) return [];
      if (field == 'platforms') return repo.getMusicPlatforms();
      return repo.getMusicFacet(field);
    });

/// Temas del Jukebox según [JukeboxTracksQuery] (máx. 300 por tanda).
final jukeboxTracksProvider =
    FutureProvider.family<List<GameOstTrack>, JukeboxTracksQuery>((
      ref,
      query,
    ) async {
      final repo = ref.watch(rommRepositoryProvider);
      if (repo == null) return [];
      final search = query.search.isEmpty ? null : query.search;
      final List<RommSoundtrackTrack> items = query.favoritesOnly
          ? await repo.getMusicFavorites(search: search)
          : await repo.getMusicTracks(
              search: search,
              artist: query.artist,
              album: query.album,
              genre: query.genre,
              year: query.year,
              minYear: query.minYear,
              maxYear: query.maxYear,
              platformIds: query.platformIds,
              orderBy: (query.minYear != null || query.maxYear != null)
                  ? 'year'
                  : 'title',
              limit: 300,
            );
      return [for (final t in items) _toOstTrack(t)];
    });
