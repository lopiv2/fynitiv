# Front/back cover desde ss_metadata y gamelist_metadata

## Intent
El visor 3D se queda sin trasera/lomo porque `_mapGame` solo mira claves top-level (`path_backcover`, `spine_path`...) que RomM no expone en `RomSchema`. RomM sí envía el arte en los blobs anidados `ss_metadata` (ScreenScraper) y `gamelist_metadata` (ES-DE): usarlos para rellenar `coverBackUrl`/`coverSpineUrl`/`box3dUrl` sin romper el fallback por sondeo actual.

## Scope
- In: `lib/features/games/data/romm_repository.dart` (`_mapGame` + helper de metadatos); log `[ROMM-3D-META]` de autodiagnóstico.
- Out: cambios en el visor three.js, UI nueva, claves ARB, otros providers (LaunchBox/IGDB).

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Helper `_metaArtworkUrl` que recorre `ss_metadata` → `gamelist_metadata`: `*_path` prefijado con `/assets/romm/resources` (crudo en resources), luego `*_url` salvo `file://`
- [x] `_mapGame` rellena back/spine/box3d vacíos a top-level con el helper (frontal intacto)
- [x] Log `[ROMM-3D-META]` con hits por provider (sin JSON manual del usuario)
- [x] `flutter analyze` sin issues en los ficheros tocados
- [x] Fix 401: `*_path` iba sin prefijo (`/roms/...` → 401) y `assetUrl` con doble `//`; ahora `/assets/romm/resources/...` + base sin barra final — `flutter analyze` sin issues
- [x] Limpieza de logs de diagnóstico (`[ROMM-3D]`, `[ROMM-3D-FILES]`, `[ROMM-3D-META]`, `[ROMM-3D-TEX]`, `[OST]`): solo queda `[ROMM] GET /api/music/tracks` — `flutter analyze` sin issues
- [x] 2D con frontal plana por defecto (`coverLarge` > `coverSmall` > `box3d` como último recurso); la 3D vive solo en el modo 3D — `flutter analyze` sin issues
- [x] Limpieza de logs de plataformas (`GET /api/platforms`, por plataforma, `zero-count`, `sample raw keys`, fallbacks) — `flutter analyze` sin issues
- [x] Encuadre inicial 3D con más presencia: cámara `(1.6, 0.35, 4.1)` → `(1.25, 0.3, 3.2)` y FOV `32` → `27`; `minDistance` intacto (2.4) — `flutter analyze` sin issues
- [x] Caras sin textura teñidas del predominante del lomo (histograma 4 bits/canal sobre miniatura, transparentes ignorados; sin lomo, marrón sólido) — `flutter analyze` sin issues
- [x] Lomo texturizado solo en el lateral (+x/-x); superior e inferior (+y/-y) tintados con el predominante (verificado orden en `three_js_core@0.3.0`: 0=px,1=nx,2=py,3=ny,4=pz,5=nz) — `flutter analyze` sin issues

## Evidence
- `backend/endpoints/responses/rom.py` (master RomM): `RomSchema` expone `ss_metadata` y `gamelist_metadata` en lista y detalle.
- `backend/handler/metadata/ss_handler.py`: `SSMetadata` con `box2d_back_url/_path`, `box2d_side_url/_path`, `box3d_url/_path`, `box2d_url/_path`, `fullbox_url`.
- `backend/handler/metadata/gamelist_handler.py`: `GamelistMetadata` con `box2d_back_url/_path` (`<backcover>`), `box3d_url/_path` (`<box3d>`); `_url` en formato `file://` no cargable.
- Estado previo: `02-DOCS/wiki/ftd/game-3d-covers.md` — probe por HEAD todo miss en servidor con solo frontal; `can3D` con cantos sólidos ya soportado.
- Implementación 23/09/2026: `_metaArtworkUrl` + relleno en `_mapGame` + `norm` defensivo anti-`file://`; `flutter analyze lib/features/games/data/romm_repository.dart` → "No issues found!".
- Log usuario 23/09/2026 (rom 28901): `[ROMM-3D-META] back=true spine=true box3d=true` pero `back=https://...//roms/15/28901/box2d_back/...` → `asset bytes failed 401` en back/spine (frontal OK 517x680). Causa: `*_path` crudo sin `FRONTEND_RESOURCES_PATH` (`/assets/romm/resources`, ver `backend/config/__init__.py`) + `assetUrl` con doble `//`. Fix aplicado; `flutter analyze` → "No issues found!".
- `box3d=https://...//roms/...` también iba mal prefijado; queda cubierto por el mismo fix.

## Next
Consola limpia: solo `[ROMM] GET /api/music/tracks?rom_id=... → N pistas` (más `[ROMM] asset bytes failed` solo si una descarga falla). Nada pendiente.
