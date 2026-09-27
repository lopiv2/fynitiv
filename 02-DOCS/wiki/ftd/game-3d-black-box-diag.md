# Caja 3D negra en todas las plataformas (2D OK) — diagnóstico con logs

## Intent
Saber por qué el visor 3D muestra la caja en negro puro en todas las plataformas cuando el 2D sí muestra la carátula. El código 3D es idéntico al commit `6d67590` donde funcionaba (diff vacío en `game_box3d_viewer.dart`, `romm_repository.dart`, `romm_game.dart` entre `6d67590` y HEAD; el cambio de `pubspec.yaml` es solo el pin de `flutter_recorder`), así que la causa es de datos/runtime, no de código 3D: hace falta evidencia de consola.

## Scope
- In: logs temporales `debugPrint` en `game_box3d_viewer.dart` (`_loadFace`, `_setup`, `_waitForVideoStop`) + params de textura explícitos (clamp/linear, sin cambio de comportamiento); `flutter analyze`.
- Out: cambios de geometría/materiales/luces, toques a providers o al pipeline de vídeo hasta tener los logs.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [ ] Verificado en fuentes `three_js* 0.3.0`: orden de grupos `BoxGeometry` (px,nx,py,ny,pz,nz) OK; defaults `Texture` ya clamp; `TextureLoader.fromBytes` crea con defaults y `needsUpdate` inmediato
- [x] Logs `[BOX3D]` añadidos (bytes, dimensiones, nulls, contador de vídeo, fallback)
- [x] Params explícitos en `_loadFace` (wrapS/wrapT clamp, mag/min linear, sin mipmaps)
- [x] `flutter analyze` sin issues
- [x] Usuario hace REINICIO COMPLETO, abre detalle y pega líneas `[BOX3D]`
- [x] Limpieza: logs `[BOX3D]` retirados; se mantienen los params explícitos de textura (clamp/linear/sin mipmaps) como endurecido

## Evidence
- `git diff 6d67590 HEAD -- lib` no toca nada del pipeline 3D; `pubspec.yaml` solo pin `flutter_recorder 2.0.4`.
- `box_geometry.dart` (three_js_core 0.3.0): grupos 0..5 = px,nx,py,ny,pz,nz — coincide con el orden de `materials` en `_setup`.
- `texture.dart`: defaults `wrapS/wrapT=ClampToEdgeWrapping`, `magFilter=Linear` — el NPOT no debería fallar por wrap.
- `texture_loader.dart:_textureProcess`: crea `Texture()` con defaults (`generateMipmaps=true`) y marca `needsUpdate` antes de que `_loadFace` ajuste params — posible primer upload con mipmaps.
- `flutter analyze lib/features/games/presentation/widgets/game_box3d_viewer.dart` → "No issues found!" (también tras retirar los logs).
- Resolución 27/09/2026: el usuario confirma que el 3D vuelve a verse; causa probable carga incompleta/transitoria de texturas desde ROMM (el código 3D era idéntico al commit funcional `6d67590`). Sin cambios de geometría/materiales: solo endurecido de params + instrumentación temporal ya retirada.

## Next
- Cerrado: si la caja negra vuelve, reintroducir los logs `[BOX3D]` de este FTD y pedir consola tras reinicio completo antes de tocar materiales/GL.
