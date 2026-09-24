# OST favoritas con corazón en lista (ROMM Music API)

## Intent
Añadir un botón de corazón en cada fila de la lista OST del detalle de juego y que al pulsarlo marque/desmarque la canción como favorita contra la ROMM API (`POST`/`DELETE /api/music/favorites`), con estado visible y funcional.

## Scope
- In: campo `is_favorite` en `RommSoundtrackTrack`/`GameOstTrack` (+ `romFileId` en `GameOstTrack`); `POST`/`DELETE /api/music/favorites` con `{"rom_file_ids": [...]}` en `RommRepository`; corazón por fila en `_OstTrackList` (`game_detail_screen.dart`) con optimistic update, `AppLoader` durante la petición DIO y `flutter_easyloading` (`showSuccess`/`showError`) para el resultado; claves ARB EN+ES reutilizando `addToFavorites`/`removeFromFavorites` + nuevas `ostFavoriteAdded`/`ostFavoriteRemoved`/`ostFavoriteError`; foco TV intacto (botón focusable, sin robar foco de la fila).
- Out: pantalla de "canciones favoritas", facets/stats/playlists (`/music/games`, `/music/stats`…), corazón en `_OstNowPlayingCard` o en skins de música, sincronización global de favoritas entre juegos.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] `RommSoundtrackTrack`/`GameOstTrack` exponen `isFavorite` (+ `romFileId`) — `flutter analyze` sin issues
- [x] `RommRepository.addMusicFavorites/removeMusicFavorites` (`POST`/`DELETE /api/music/favorites`) — `flutter analyze` sin issues
- [x] ARB EN+ES (`ostFavoriteAdded`/`ostFavoriteRemoved`/`ostFavoriteError`) + `flutter gen-l10n` — `flutter analyze` sin issues
- [x] Corazón en cada fila OST con toggle real, loader en petición y toast EasyLoading — `flutter analyze` sin issues

## Evidence
- Spec real backend ROMM (`backend/endpoints/music.py` en `rommapp/romm@master`): `MusicTrackIdsPayload { rom_file_ids: list[int] }`; `POST /favorites` → `{"added": n}`; `DELETE /favorites` → `{"removed": n}`; `MusicTrackSchema` incluye `rom_file_id: int` + `is_favorite: bool` (el `GET /tracks` ya lo devuelve con `is_favorite_user_id`).
- Base actual: `_OstTrackList` en `lib/features/games/presentation/game_detail_screen.dart:1232` sin botón de favorita; `getSoundtrackTracks` en `lib/features/games/data/romm_repository.dart:859` no mapea `is_favorite`.
- `flutter analyze` (5 ficheros: romm_soundtrack_track, game_ost_track, romm_repository, ost_providers, game_detail_screen) → "No issues found!"
- `flutter gen-l10n` regeneró `ostFavoriteAdded`/`ostFavoriteRemoved`/`ostFavoriteError` (verificado en `app_localizations.dart`).

## Next
Confirmar en runtime contra el servidor del usuario (ROMM 5.3) que el corazón persiste y `GET /api/music/favorites` devuelve la pista marcada.
