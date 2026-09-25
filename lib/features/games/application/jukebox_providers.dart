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

GameOstTrack _toOstTrack(RommSoundtrackTrack t, [String? coverUrl]) => GameOstTrack(
  name: t.displayName,
  url: t.streamUrl,
  duration: t.displayDuration,
  artist: t.artist,
  album: t.album,
  romFileId: t.romFileId,
  isFavorite: t.isFavorite,
  gameName: t.gameName,
  gameId: t.romId,
  coverUrl: coverUrl,
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

/// Juegos recientes para la card `Recientes` dentro de Biblioteca: sin
/// filtro de búsqueda, para no contaminar con el texto del buscador.
final jukeboxRecentGamesProvider = FutureProvider<List<MusicGameEntry>>((
  ref,
) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) return [];
  // Sin `search`: lista estable para la card Recientes en Biblioteca.
  // Si el BE expone orden por fecha, se puede pasar orderBy aquí.
  return repo.getMusicGames(limit: 12);
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
      // Orden por número de fichero/título para álbum/juego, como en
      // `RommRepository.getSoundtrackTracks` y `ost-sort-filename-number.md`:
      // numeradas primero por `sortNumber` (desempate alfabético), no numeradas
      // después por `displayName`. Solo para vistas por álbum (y por juego si
      // viniera vía `album`/`artist`); búsqueda/favoritas mantienen orden servidor.
      if (query.album != null && query.album!.isNotEmpty) {
        items.sort((a, b) {
          final an = a.sortNumber;
          final bn = b.sortNumber;
          if (an != null && bn != null) {
            final byNum = an.compareTo(bn);
            if (byNum != 0) return byNum;
          } else if (an != null) {
            return -1;
          } else if (bn != null) {
            return 1;
          }
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });
      }
      // Las pistas no traen cover: se mapea la portada del juego dueño
      // (`cover_url` de GET /api/music/games) por `rom_id`.
      Map<int, String> covers = const {};
      try {
        final games = await repo.getMusicGames();
        covers = {
          for (final g in games)
            if (g.coverUrl?.isNotEmpty == true) g.romId: g.coverUrl!,
        };
      } catch (_) {}
      return [for (final t in items) _toOstTrack(t, covers[t.romId])];
    });
