# Fecha de lanzamiento en detalle del videojuego (ROMM)

## Intent
El detalle del juego mostraba "—" en "Fecha de lanzamiento" aunque ROMM la envía por API (`metadatum.first_release_date`). Mapearla y mostrarla.

## Scope
- In: parsear `first_release_date` en `RommRepository._mapGame` (principal `metadatum`, fallbacks `igdb/ss/launchbox/gamelist/flashpoint_metadata` y top-level), añadir `firstReleaseDate` a `RommGame`, mostrarlo en `GameDetailScreen`.
- Out: formato localizado (feature aparte), otros metadatos (rating, compañías).

## Checklist
- [x] `RommGame.firstReleaseDate` + `copyWith` — verificado en `lib/features/games/domain/romm_game.dart`
- [x] `_parseReleaseDate` en repositorio (segundos vs ms vs ISO) — verificado con esquema `RomMetadataSchema` del `openapi.json` de demo.romm.app
- [x] Detalle muestra la fecha o "—" si no hay dato — `flutter analyze` sin issues en los 3 ficheros

## Evidence
- `flutter analyze lib/features/games/domain/romm_game.dart lib/features/games/data/romm_repository.dart lib/features/games/presentation/game_detail_screen.dart` → "No issues found!"
- Esquema observado: `RomMetadataSchema.first_release_date` = integer|null (Unix segundos); `gamelist/flashpoint` = string ISO.

## Next
Ninguno pendiente; formato localizado se hizo en feature aparte (`localized-date-format.md`).
