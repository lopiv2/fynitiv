# Fondo del detalle con la primera captura de ROMM

## Intent
En el detalle del juego el fondo usa la carátula (`coverLargeUrl`). Cambiarlo a la primera captura de pantalla que ROMM devuelva para ese juego, con fallback a la carátula si no hay capturas.

## Scope
- In: debug temporal `[ROMM-SHOT]` en `RommRepository.getGame` para ver la forma real del campo de screenshots; después, campo en `RommGame` + mapeo en `_mapGame` y `backdropUrl` en `game_detail_screen.dart` (captura → carátula → color).
- Out: otros usos de capturas (listas, cards), cambios en visor 3D, cadenas ARB (sin texto nuevo).

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Test genérico descartado (`test/romm_dump_test.dart` eliminado a petición: mejor debug en app)
- [x] Debug `[ROMM-SHOT]` en `getGame` + volcado del usuario + debug retirado
- [x] `RommGame.screenshotUrl` (+ `copyWith`) y `_firstScreenshotUrl` en `_mapGame` (top-level `screenshots[0]` → `screenshot_path` → `screenshot_url`)
- [x] Backdrop del detalle con captura y fallback a carátula
- [x] `flutter analyze` sin issues en los 3 ficheros

## Evidence
- Volcado usuario (rom 28897): `ss_metadata` trae `screenshot_url` remota de ScreenScraper (`media=ss`) y `logo_path` local; `miximage_*_path` en null → mapeo con `screenshot_path` primero y `screenshot_url` de fallback cubre ambos casos.
- `flutter analyze` (repository, romm_game, game_detail_screen) → "No issues found!"
- Debug temporal `_debugScreenshots`/`_debugShotValue` eliminado tras fijar el mapeo.

## Next
- Con el volcado, fijar el campo real y mapear `screenshotUrl` en `_mapGame`.
