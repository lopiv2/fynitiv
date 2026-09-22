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
- [x] El usuario no puede aportar el JSON manual — se pasa a autodiagnóstico en app
- [x] Resolve autodiagnóstico: `files[]` + `GET /api/roms/{id}/files` + probe HEAD→GET(Range) con más variantes + log `[ROMM-3D]` siempre (hit o miss) — implementado, `flutter analyze` sin issues
- [x] Log usuario 22/09/2026 (rom 28901 Monkey Island 2): `files[]=115` son ficheros del juego/soundtrack (keys: file_name/file_path/full_path/category…), no artwork; probe trasera/lomo/box3d todo miss → el servidor solo tiene frontal. Conclusión: exigir trasera deja el 3D muerto siempre en este servidor.
- [x] 3D con solo frontal: `can3D` = hay frontal; trasera/lomo ausentes → cantos sólidos (el visor ya lo soporta); `has3DFaces` se conserva para el caso con trasera real — `flutter analyze` sin issues
- [x] Crash al abrir detalle con 3D: `Tried to modify a provider while the widget tree was building` — `_suspendVideo()` mutaba `gameVideoSuspendedProvider` en `initState`/`didUpdateWidget`; antes nunca se ejecutaba (`has3DFaces` siempre falso) y con `can3D` sí. Fix: diferir el `set(true)` a post-frame — `flutter analyze` sin issues.
- [x] Descarga+decode OK (`[ROMM-3D-TEX] ok bytes=642307`) pero la frontal sigue sin verse. Tubería Dart verificada entera (BoxGeometry crea 6 grupos px/nx/py/ny/pz/nz, renderer reparte GroupMaterial por grupo, `map` llega al material, upload usa `image.data`). Resta la parte GPU/driver: se simplifica el material de cara a `MeshBasicMaterial` (sin luces/normales, colores exactos de la carátula, programa distinto al de los cantos Standard), se quita el override de anisotropía y se loguean dimensiones de la textura — `flutter analyze` sin issues.
- [x] La frontal sale en negro. Dimensiones del log: 517x680 = NPOT → la generación de mipmaps deja la textura incompleta en ANGLE/D3D11 y muestrea negro. Fix como three.js con NPOT: `generateMipmaps=false` + `minFilter=Linear` en las texturas de carátula — `flutter analyze` sin issues.
- [x] Captura usuario: caja renderiza, lomo con sombreado Standard visible, frontal en negro puro sin loader → `map` enlazado pero muestreando 0; geometría/materiales/luces/presentation descartados.
- [x] Verificado `getMipLevels` en el port: con `generateMipmaps=false` devuelve 1 nivel → `texStorage2D(1 nivel)` + subida de nivel 0 + `minFilter=Linear` = textura completa para NPOT. El fix ya está en el repo (`flutter analyze` limpio); el log con dimensiones del usuario es del build anterior (Basic sin fix de mipmaps), así que probablemente corre código stale.
- [ ] El usuario hace REINICIO COMPLETO (no hot reload), reabre el detalle y confirma.
- Pregunta usuario "¿hará falta una luz?": no — las caras usan `MeshBasicMaterial` (unlit, ignora luces) y los cantos Standard SÍ se ven, luego las 3 luces (hemisferio+key+fill) funcionan. Cara negra con Basic = `map` enlazado pero muestreando 0 (upload incompleto/vacío), no falta de luz.
- Comparado con cargadores del paquete (FBX/glTF usan el mismo `TextureLoader.unknown`→`fromBytes`): nuestra ruta es la canónica; el siguiente dato útil es una captura (negro puro vs marrón vs loader visible) para distinguir upload vacío de overlay de carga.
- [ ] El usuario reabre el detalle del 28901 y confirma frontal aplicada

## Evidence
- `DetailedRomSchema.properties` (spec 5.2.0): solo `path_cover_small`, `path_cover_large`, `url_cover` (+manual/video/screenshots).
- `backend/endpoints/responses/rom.py` (master): `RomSchema` confirma lo mismo.
- ROMM web (`GameDetails.vue`+`MediaTab.vue`): sin vista de traseras; los ficheros se sirven por `/api/roms/{file_id}/files/content/{file}`.
- `flutter analyze` (repository, romm_game, box3d_viewer, detail) → "No issues found!"
- Log usuario 22/09/2026: sin línea `[ROMM-3D]` = probe sin hits → `has3DFaces=false` → solo 2D sin toggle; la línea `[ROMM] sample raw keys` aportada es de `/api/platforms`, no del rom.
- Cambio 22/09/2026 (`romm_repository.dart`): `RommResolvedArtwork` + spine; `getGame` loguea siempre; `resolveArtwork` en 3 pasos (files[] → `/api/roms/{id}/files` → probe); `_probeFirst` HEAD + fallback GET Range; `_swapFileName`; `_mapGame` defensivo; `flutter analyze` 3 ficheros → "No issues found!".

## Next
Abrir detalle (p.ej. rom 28901) y pegar líneas `[ROMM-3D]` + `[ROMM-3D-FILES]` de consola. Con ese volcado se fija la ruta real si sigue en miss.
