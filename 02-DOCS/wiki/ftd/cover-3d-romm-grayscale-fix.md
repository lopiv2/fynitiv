# Intent
Eliminar el aspecto gris/apagado de las caratulas ROMM en el visor 3D (`GameCoverViewer`), donde la caratula se ve correcta en 2D. Causa raiz verificada en `three_js_angle_renderer 0.0.1`: la textura se sube con `colorSpace = NoColorSpace` (formato interno `RGBA8`) porque `TextureLoader.fromBytes` fija `needsUpdate = true` antes de que `_loadFace` pueda asignar `SRGBColorSpace`; el shader `physical` (MeshStandardMaterial) cierra con `linearToOutputTexel` (OETF sRGB) y vuelve a codificar pixeles que ya venian en sRGB, aplicando un `pow(x, 2.2)` extra que oscurece los tonos medios hacia gris/negro.

# Scope
- In: `lib/features/games/presentation/widgets/game_box3d_viewer.dart` — `_normalizedCoverBytes` decodifica, detecta placeholder negro y devuelve un PNG con los pixeles convertidos sRGB->linear (via `ui.ImageDescriptor.raw` + `toByteData(png)`); `_loadFace` usa `TextureLoader.fromBytes` (pipeline verificado) con ese PNG.
- Out: `three_js`/`three_js_angle_renderer` (no se forkea), geometria/materiales/luces, ARB, tests.
- Nota: el 2D mantiene su ruta original (`Image.memory` con los bytes tal cual).

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] `_normalizedCoverBytes` devuelve PNG de pixeles lineales (`ImageDescriptor.raw`)
- [x] `_loadFace` usa `TextureLoader.fromBytes` (ruta verificada de subida)
- [x] LUT sRGB->linear cacheada (evita `pow` por pixel)
- [x] `flutter analyze` sin issues
- [ ] Prueba del usuario: abrir detalle con can3D y comparar 3D vs 2D

# Evidence (verificacion)
- Causa raiz (color): `three_js_core-0.3.0/lib/textures/texture.dart:42` (`NoColorSpace` default) + `three_js_core_loaders-0.3.0/lib/loaders/texture_loader.dart:33-34` (`needsUpdate` inmediato) + `three_js_angle_renderer-0.0.1/lib/angle/angle_textures.dart:147` (`RGBA8` si transfer != SRGB) + `.../shaders/shader_lib/meshphysical_frag.glsl.dart:162` (`colorspace_fragment` -> `linearToOutputTexel`) + `.../angle_program_extra.dart:49-59` (`sRGBTransferOETF`).
- Log usuario (game=27107): `mesh: groups=6 materials=6 maps=[true,true,false,false,true,true]` — el emparejamiento material/grupo era correcto; el fallo estaba en la subida.
- Log usuario (game=28897): `Created a new texture 1680x979` confirma que el motor si sube texturas de superficie; descarta problema general de render.
- Regresion 1 (corregida): `ui.instantiateImageCodec` con pixeles crudos lanza `Invalid image data` (solo acepta imagen codificada).
- Regresion 2 (corregida): `DataTexture` + `texImage2DIf` no-web pasa `image.width`/`height` (num/double) a un `gl.texImage2D(int width, int height, ...)`; el tipo no casa y la subida no completa de forma fiable (las caras quedaban sin map, visible tambien con 1 sola material).
- Regresion 3 (corregida): el bucle de `needsUpdate` estaba tras `scene.add`; mutar el material despues del primer render no llega al puente nativo. Movido antes de construir `Mesh`/`GroupMaterial`.
- `flutter analyze lib/features/games/presentation/widgets/game_box3d_viewer.dart` → "No issues found!" (iteracion final).

# Next
1. Reinicio completo, abrir detalle de un juego con `can3D` y comprobar que la portada 3D coincide en color con el 2D.
2. Si sigue sin textura, revisar orden de `flipY` (el PNG lineal re-codificado ya no pasa por `flipVertical`) y confirmarlo con un caso conocido.
3. Si funciona, limpiar los `debugPrint('[Box3D] ...')` de diagnostico y cerrar los FTD de diagnostico.
