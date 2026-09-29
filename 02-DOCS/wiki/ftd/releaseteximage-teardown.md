# Intent
Eliminar el FATAL `egl::Surface::releaseTexImage: context` al desactivar el vídeo de fondo: el `Video` se desmontaba (vuelta a `DashboardBackground`) antes de que el teardown nativo terminara y mpv liberaba la textura contra un contexto muerto.

# Scope
- Nuevo `lib/core/video/mpv_teardown.dart`: `disposeMpvPlayer` (pause → stop → gracia 300 ms → dispose, todo tolerante a fallos).
- `game_video_background.dart`: usa el helper en la puerta global + flag `_tearingDown` que mantiene el `Video` montado hasta fin del teardown.
- Trailers (`featured_slider`, `item_detail`), `player_screen._stopPlayer`, `live_tv._disposePlayer`: usan el helper (mismo drenaje).
- Sin `flutter build`; verificación con `flutter analyze`.

# Checklist
- [x] Diagnosticar: desmontaje del `Video` antes del teardown nativo + sin drenaje previo
- [x] Helper `disposeMpvPlayer` compartido (`lib/core/video/mpv_teardown.dart`)
- [x] Fondo: controller vivo hasta fin del teardown + `Video` montado mientras tanto (se descartó el flag `_tearingDown`, redundante: controller no-nulo ya lo marca)
- [x] Helper en los otros 4 teardowns (`featured_slider`, `item_detail`, `player_screen`, `live_tv`)
- [x] `flutter analyze` sin errores nuevos

# Evidence
- `flutter analyze --no-pub` (28/09/2026): `No issues found!` (en el camino se cazó un `unused_field` y se eliminó el flag redundante).
- Prueba real pendiente con proceso fresco: activar y desactivar el fondo repetidamente en Windows debug.

# Next
- Si persiste: fijar `vo`/`gpu-api` de libmpv o mantener un `Player` de fondo reutilizado (sin destruir al desactivar).
