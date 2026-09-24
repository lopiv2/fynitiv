# Jukebox de bandas sonoras en Juego online

## Intent
Añadir a la pantalla de juego online (`/games`) un botón a la izquierda del toggle de audio que abra un Jukebox con todas las bandas sonoras de la biblioteca, al estilo del Jukebox de ROMM 5.3 (pestañas Juegos/Artistas/Álbumes/Géneros/Años/Favoritas + aleatorio global), adaptado a móvil, desktop y TV.

## Scope
- In: botón `jukeboxOpen` en el header de `GamesScreen`; ruta `/games/jukebox`; `RommRepository`: `getMusicGames`, `getMusicFacet` (artists/albums/genres/years), `getMusicStats`, `getMusicTracks` global (filtros + paginación), `getMusicFavorites`, campo `gameName` en `RommSoundtrackTrack`; `jukebox_providers.dart`; `OstFavoriteButton` extraído y reutilizado en `_OstTrackList` + Jukebox; `JukeboxScreen` adaptativa (compacto 1 columna con chips, ancho maestro-detalle) con reproducción vía `GameOstPlayer`, aleatorio global, `AppLoader`/`EasyLoading`, ARB EN+ES.
- Out: CRUD de playlists propias (`/music/playlists`), covers embebidas, ecualizador, facets `platforms`/`game-genres` (v2).

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] Facets/stats/tracks/favoritas en repo + providers — `flutter analyze` sin issues
- [x] `OstFavoriteButton` compartido (detalle + jukebox) — `flutter analyze` sin issues
- [x] Pantalla + ruta + botón header, adaptativa TV/móvil/desktop — `flutter analyze` sin issues
- [x] ARB EN+ES + `flutter gen-l10n` — `flutter analyze` sin issues

## Evidence
- Doc ROMM 5.3-beta Jukebox: `GET /music/tracks`, `/music/games|platforms|game-genres`, `/music/albums|artists|genres|years`, `/music/stats`, `GET+POST /music/favorites`, `/music/playlists`.
- Schemas backend (`rommapp/romm@master`): `MusicGameFacetSchema {rom_id, name, platform_*, cover_url, count}`, `FacetValueSchema {value, count}`, `MusicStatsSchema {total_tracks, total_duration_seconds}`, `MusicTrackSchema` con `game_name` + `is_favorite`.
- Base app: header online `games_screen.dart:328`, rutas `/games` en `app_router.dart:231`, `GameOstPlayer` con colas+shuffle, corazón con `POST/DELETE /music/favorites` en el detalle.
- `flutter analyze` (12 ficheros: jukebox_screen, games_screen, game_detail_screen, ost_favorite_button, jukebox_providers, ost_providers, romm_repository, romm_music_facet, game_ost_track, romm_soundtrack_track, game_ost_player, app_router) → "No issues found!"
- `flutter gen-l10n` regeneró las 13 claves `jukebox*` (verificado en `app_localizations.dart`).

## Next
Probar en runtime contra el servidor 5.3 del usuario (facets con counts, aleatorio, favoritas) y decidir playlists en v2.
