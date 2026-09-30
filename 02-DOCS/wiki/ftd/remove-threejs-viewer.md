# Intent
Eliminar toda la lógica antigua de `three_js` del visor de portada 3D, migrando antes al visor `flutter_scene` la funcionalidad que solo existía en el visor `three_js`: gating `can3D`, toggle 2D/3D (`_ViewToggle`) y fallback 2D validado (`_ValidatedCoverImage`/`_CoverFallback`).

# Scope
- In: `game_box3d_scene_viewer.dart` (portar toggle + fallback 2D + `can3D`); `game_detail_screen.dart` (quitar import, flag `_useSceneViewer` y rama muerta); borrar `game_box3d_viewer.dart`; `pubspec.yaml` (quitar `three_js`); `game_video_controller.dart` + `game_video_background.dart` (quitar `gameVideoSuspendedProvider`/`gameVideoActiveCountProvider`, que solo existían para coordinar la superficie GL de three_js con el vídeo).
- Out: ARB (se reutilizan claves existentes); tests; rutas; geometría/órbita del scene viewer.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] `GameCoverViewerScene`: `_show3D` desde `can3D`, toggle `_ViewToggle`, `_ValidatedCoverImage`/`_CoverFallback`, `_fallback2D`, fallback a 2D en fallo
- [x] `game_detail_screen.dart`: import y `_coverViewer` sin rama three_js
- [x] Borrado `game_box3d_viewer.dart` y dep `three_js` de `pubspec.yaml`
- [x] Quitar providers de suspensión de vídeo y su uso en `game_video_background.dart`
- [x] `flutter analyze` sin issues

# Evidence (verificacion)
- Todo el código `three_js` era muerto en runtime: `_useSceneViewer = true` hacía que `GameCoverViewer` nunca se construyera.
- `flutter pub get` → "Got dependencies!"; `pubspec.lock` ya no contiene ningún paquete `three_js*` (11 transitivos eliminados).
- `flutter analyze lib` → "No issues found! (ran in 12.4s)".
- `grep three_js` en `lib/` solo deja un comentario descriptivo en `game_box3d_scene_viewer.dart:526`; el resto son documentos históricos en `02-DOCS`.

# Next
- Probar en Windows el detalle de un juego con `can3D`: toggle 2D/3D, fallback 2D si falta carátula, órbita y que el vídeo de fondo no aborte (ya no hay coordinación ANGLE con el 3D).
- Limpiar las claves ARB `gameBoxNoData`/`gameBoxLoading` si quedan sin uso (comprobar antes).
