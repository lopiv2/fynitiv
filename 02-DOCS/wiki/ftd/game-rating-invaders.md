# Rating geek (invaders) en el detalle del juego

## Intent
Mostrar el rating en la vista de detalle del juego sin estrellas genéricas: nota media de la comunidad (lectura) + voto personal interactivo, ambos con iconos de marcianito invader pixel-art dibujados a medida, integrados en la fila de stats del hero.

## Scope
- In: `averageRating`/`userRating` en `RommGame` (+ parseo en `_mapGame`: `metadatum.average_rating` con normalización defensiva a 0–10, `rom_user.rating` 0–10); `RommRepository.setUserRating` (`PUT /api/roms/{id}/props`, body `{"rating": N}`); widget `game_rating_row.dart` (invader `CustomPainter` 11×8 con relleno parcial, fila comunitaria + 5 invaders votables con optimistic update, mini `AppLoader` y `EasyLoading` en error); cableado en el `Wrap` de stats de `_GameHeroInfo`; ARB EN+ES (`gameRatingCommunity`, `gameRatingYours`, `gameRatingUnrated`, `gameRatingError`).
- Out: medias en tarjetas/listas, dificultad/completion de ROMM, medios votos personales (ROMM solo acepta enteros; se envían pares 2–10).

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] `RommGame` + `_mapGame` exponen ambos ratings — `flutter analyze` sin issues
- [x] `setUserRating` escribe en ROMM — `flutter analyze` sin issues
- [x] Invaders comunitarios + voto personal en la fila de stats, foco TV intacto — `flutter analyze` sin issues
- [x] ARB EN+ES + `flutter gen-l10n` — `flutter analyze` sin issues

## Evidence
- Backend `rommapp/romm@master`: `RomMetadataSchema.average_rating: float | None` y `RomUserSchema.rating: int` en `backend/endpoints/responses/rom.py`; `PUT /roms/{id}/props` acepta body `RomUserData {rating 0–10}` con scope `ROMS_USER_WRITE` en `backend/endpoints/roms/__init__.py:2282` (`update_rom_user`).
- Base actual: `RommGame` en `lib/features/games/domain/romm_game.dart` sin rating; `_mapGame` ya lee `rom_user.last_played` del mismo objeto; stats en `_GameHeroInfo` (`lib/features/games/presentation/game_detail_screen.dart:604`).
- `flutter analyze` (4 ficheros: romm_game, romm_repository, game_detail_screen, game_rating_row) → "No issues found!"
- `flutter gen-l10n` regeneró `gameRatingCommunity`/`gameRatingYours`/`gameRatingUnrated`/`gameRatingError` (verificado en `app_localizations.dart`).

## Next
Probar en runtime: media visible en un juego con metadatos IGDB y voto persistido tras recargar el detalle.
