# Carátulas 3D: la API no expone trasera/lomo en el esquema ROM

## Intent
El detalle se queda en 2D aunque el servidor tiene las imágenes. Verificado en fuentes: `DetailedRomSchema`/`RomSchema` (master de ROMM, posterior a 5.3) solo exponen `path_cover_small`, `path_cover_large`, `url_cover` — no hay `path_backcover`/`spine`/`box3d`. Los nombres que mapeaba `_mapGame` no existen: `has3DFaces` siempre falso. El usuario apunta a `GET /api/roms/{id}/files` como vía.

## Scope
- In: descubrir dónde viajan trasera/lomo (volcado de `files[]` del servidor del usuario) y mapearlos a `coverBackUrl`/`coverSpineUrl`; solo `romm_repository.dart` + log temporal.
- Out: cambios en el visor three.js (verificado correcto: orden de caras, GroupMaterial, decode).

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] Verificado spec 5.2.0 + `responses/rom.py` de master: sin campos backcover/spine/box3d
- [x] Volcado `files[]` del servidor 5.3 del usuario — recursos en `/assets/romm/resources/roms/{plat}/{rom}/cover/*.png`; sin campos trasera en el JSON
- [x] Sondeo autenticado HEAD (`cover` → `backcover`/`backcovers`, `box3d`/`3dbox`/`3dboxes`) con caché por rom; `has3DFaces` = frontal+trasera (lomo opcional, cantos sólidos) — `flutter analyze` sin issues
- [ ] El usuario confirma qué URLs responden 200 en su servidor (línea `[ROMM-3D]` al abrir detalle)

## Evidence
- `DetailedRomSchema.properties` (spec 5.2.0): solo `path_cover_small`, `path_cover_large`, `url_cover` (+manual/video/screenshots).
- `backend/endpoints/responses/rom.py` (master): `RomSchema` confirma lo mismo.
- ROMM web (`GameDetails.vue`+`MediaTab.vue`): sin vista de traseras; los ficheros se sirven por `/api/roms/{file_id}/files/content/{file}`.
- `flutter analyze` (repository, romm_game, box3d_viewer, detail) → "No issues found!"

## Next
Pegar salida `[ROMM-3D]` de consola al abrir un detalle.
