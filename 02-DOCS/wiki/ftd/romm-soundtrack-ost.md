# OST del detalle vía Music API de ROMM (jukebox)

## Intent
Eliminar la lógica de OST vía archive.org (inconsistente: adivinaba bandas sonoras por nombre en una fuente externa) y servir la música desde la propia biblioteca ROMM: el NAS guarda `soundtrack/` junto a cada ROM y ROMM lo expone por su Music/Jukebox API. Más fiable y más legal (solo suena lo que el usuario tiene).

## Scope
- In: `RommRepository.getSoundtrackTracks` con `GET /api/music/tracks?rom_id=&order_by=track&order_dir=asc` (+paginación); streaming autenticado pasando `httpClient` con Bearer a `SoLoud.loadUrl` (soportado en `flutter_soloud 5.1.1`); borrar `data/archive_ost/`; reescribir `ost_providers.dart`; campo `artist` en `GameOstTrack` + subtítulo en lista; mensaje informativo si no hay OST (claves ARB EN+ES).
- Out: facets/stats/playlists de la Music API (`/music/albums`, `/music/playlists`…); cambios en `GameBgPlayer`/`ItemThemePlayer`.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] `getSoundtrackTracks` mapea `MusicTrackSchema` (title/artist/duration_seconds/stream_url) — `flutter analyze` sin issues
- [x] `playUrl` acepta `httpClient`; `GameOstPlayer` configura Bearer del repo — `flutter analyze` sin issues
- [x] `archive_ost/` eliminado y provider reescrito sin referencias — `grep archive` solo devuelve comentarios históricos + este doc; `flutter analyze` sin issues
- [x] UI: artista en lista + mensaje vacío con ARB `ostNoSoundtrack`/`ostNoSoundtrackHint` — `flutter analyze` sin issues
- [ ] Servidor ROMM 5.3 del usuario confirma `/api/music/tracks?rom_id=` — pendiente prueba del usuario en runtime

## Evidence
- Spec ROMM 5.1.0 (demo.romm.app/openapi.json): `GET /api/music/tracks` con param `rom_id` ("Restrict to one rom's tracks"), respuesta `MusicPage[MusicTrackSchema]` con `stream_url` requerido. Facets de 5.3 (`/music/games`, `/music/stats`) no están en ese spec; solo se usa `/music/tracks`.
- `flutter_soloud 5.1.1` (`lib/src/soloud.dart:2167`): `loadUrl(url, {mode, httpClient, autoDispose})` — el cliente custom inyecta `Authorization`.
- `flutter analyze` (7 ficheros: game_ost_player, soloud_single_player, romm_repository, game_ost_track, romm_soundtrack_track, ost_providers, game_detail_screen) → "No issues found!"
- `flutter gen-l10n` regeneró `ostNoSoundtrack`/`ostNoSoundtrackHint` (verificado en `app_localizations.dart`).
- `flutter pub get` tras añadir `http: ^1.6.0` directa → OK.

## Next
Implementar `getSoundtrackTracks` en `RommRepository`.
