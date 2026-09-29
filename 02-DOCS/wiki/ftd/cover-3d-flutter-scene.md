# Intent
Implementar un visor de caja 3D alternativo con `flutter_scene` en un widget aparte, sin tocar el visor `three_js` actual, para comparar resultados en el detalle de juego.

# Scope
- In: `lib/features/games/presentation/widgets/game_box3d_scene_viewer.dart` (`GameCoverViewerScene`); `pubspec.yaml` (`flutter_scene 0.20.0` + `vector_math`); `windows/runner/main.cpp` (Flutter GPU); `game_detail_screen.dart` (flag `_useSceneViewer` + helper `_coverViewer`).
- Out: `game_box3d_viewer.dart` (three_js) intacto; ARB; tests; rutas; `audio_flux`/`flutter_recorder` sin tocar.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Fase 0: `flutter_scene 0.20.0` resuelve (se descarta 0.23: `audio_flux → flutter_recorder → code_assets ^2` choca con `flutter_scene 0.21+ → code_assets ^1.2.1`)
- [x] Dependencias (`flutter_scene`, `vector_math`); sin `init`: el shader bundle del paquete basta y las texturas son runtime
- [x] Flutter GPU en `windows/runner/main.cpp` (`set_enable_flutter_gpu(true)`)
- [x] Widget `GameCoverViewerScene` con 6 planos (`UnlitMaterial`) + órbita (arrastre horizontal, flechas, auto-rotación)
- [x] Flag `_useSceneViewer = true` en el detalle para alternar A/B
- [x] `flutter analyze lib` sin issues

# Evidence (verificacion)
- API verificada en fuente instalada 0.20.0: `Mesh.primitives`/`MeshPrimitive` (mesh.dart:17-43), `UnlitMaterial({TextureSource? colorTexture})` (unlit_material.dart:27), `Texture2D.fromImage`/`fromPixels` (texture2d.dart:171-189), `PlaneGeometry({width, depth})` (primitives.dart), `PerspectiveCamera({position, target})` + `fovRadiansY` (camera.dart), `Node({name, localTransform, mesh})` con `Matrix4` de `vector_math` (node.dart:30), `SceneView(scene, {cameraBuilder, loadingBuilder})` (scene_view.dart:85-117), `Scene.initializeStaticResources` (scene.dart:122).
- `Node` saca `Matrix4` de `vector_math` (32-bit), no `vector_math_64` → import `as vm` sin prefijo `_64`.
- Shader bundle: `packages/flutter_scene/build/shaderbundles/base.shaderbundle` existe en el paquete → no requiere `dart run flutter_scene:init` para nuestra ruta.
- `flutter pub add` (dry-run y real): resuelve 0.20.0 sin conflicto; `flutter_soloud`/`flutter_recorder 2.0.4` intactos.
- `flutter analyze lib` → "No issues found!" (9.7s).

# Next
1. `flutter run --enable-flutter-gpu` en Windows y abrir el detalle de un juego con `can3D`.
2. Verificar que las 6 caras cierran el cubo (frontal/trasera con textura, cantos sólidos) y el color coincide con el 2D.
3. Ajustar encuadre/FOV/radio de órbita según resultado visual.
4. Si funciona, decidir el siguiente paso (limpiar `three_js`, pulir órbita, hover/sonido del visor).

# Notas de iteración
- Fix cierre del cubo: `PlaneGeometry` es horizontal (plano XZ, normal +Y) y sus rotaciones no cerraban la caja (y la frontal salía con Y invertida). Se sustituyó por **`GeometryBuilder(deduplicate: false)`** con un helper `quad(bl, br, tr, tl, n)` que define cada cara con esquinas CCW vistas desde fuera, UV (0,0)-(1,1) y normal propia. Las 6 caras se construyen con dimensiones explícitas (w×h×d centradas en origen). `flutter analyze` sin issues.
- `deduplicate: false` es obligatorio: el builder deduplica por **posición**, y caras adyacentes comparten esquinas con distinta normal/UV (se corromperían si se fusionaran).
- Winding: `flutter_scene` usa CCW como frente con su propia convención; con `addTriangle(0,1,2)/(0,2,3)` todas las normales salían hacia dentro. Invertido a `(0,2,1)/(0,3,2)`.
- Orientación final: la caja se rota 180° en Y (`box.localTransform = Matrix4.rotationY(π)`) para que la frontal mire a la cámara inicial. `flutter analyze` sin issues; usuario confirma que "todo bien".
