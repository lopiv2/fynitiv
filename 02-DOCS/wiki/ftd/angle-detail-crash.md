# Intent
Eliminar el FATAL de ANGLE (`gl::Context::unMakeCurrent: mIsCurrent`) al entrar al detalle de un juego: el fondo de vídeo (libmpv) y el visor 3D (three_js) crean sus dos superficies GL a la vez.

# Scope
- Solo `game_video_background.dart` (reservar el slot del contador al crear el `Player`, no al terminar `open+play`; liberar también en la ruta huérfana) y `game_box3d_viewer.dart` (gracia de asentamiento tras contador 0 antes de crear la superficie GL).
- No se tocan ARB, skins, `PrimeCardBadge`, ni el runner. Sin `flutter build`; verificación con `flutter analyze`.

# Checklist
- [x] Diagnosticar: `gameVideoActiveCount` solo contaba vídeos en `playing`; durante `open()` el contador es 0 y el 3D crea su superficie mientras mpv negocia la suya → abort. Sin gracia de entrada (la de salida de 300 ms sí existe).
- [x] `_incActive()` tras construir `Player`/`VideoController` (cubre open+play+dispose); huérfanos liberan vía `_dispose()`
- [x] Gracia ~400 ms tras contador 0 antes de `_createThree()` (con cancelación al desmontar)
- [x] `flutter analyze` sin errores nuevos

# Evidence
- `flutter analyze --no-pub` (28/09/2026): `No issues found!`.
- El crash nativo no es reproducible en analyze; pendiente prueba real: entrar al detalle de un juego con `can3D` con el vídeo de fondo activo en Windows (idealmente clicando rápido tras abrir la sección, que era la ventana de carrera).

# Next
- Si el FATAL persiste, siguiente paso: `vo=gpu-next`/`gpu-api=d3d11` explícito en libmpv o diferir el `open()` del fondo hasta salir del detalle.
