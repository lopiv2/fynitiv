# Intent
Eliminar el abort nativo `mutex.cpp(150): unlock of unowned mutex` al entrar a juego online: el log muestra `Free Texture` + `open/play` sobre un `Player` ya liberado y teardown nativo en vuelo mientras nace otra superficie. Confirmado que el usuario prueba con hot restart (los nativos huérfanos agravan), pero hay carreras reales en el teardown Dart.

# Scope
- `game_video_background.dart`: puerta global mpv (esperar el dispose en marcha antes de crear `Player`) + guards `_disposed` antes de cada `open/play`.
- `featured_slider.dart` e `item_detail_screen.dart` (trailers): `stop()` antes de `dispose()` + reclamo síncrono + guard para no re-liberar desde `dispose()` del widget.
- `player_screen.dart` (`_stopPlayer`) y `live_tv_player_provider.dart` (`_disposePlayer`): `stop()` antes de `dispose()`.
- Verificado en el fuente de `media_kit_video-2.0.1`: `VideoController` NO tiene `dispose()` (la textura la libera `Player.dispose()`), así que no se añade dispose de controllers.
- Sin `flutter build`; verificación con `flutter analyze`. La prueba real exige proceso fresco (hot restart inválido para nativo) y se documenta abajo.

# Checklist
- [x] Verificar `VideoController.dispose` en `media_kit_video-2.0.1` (NO existe; se descarta ese punto)
- [x] Puerta global mpv + guards en `game_video_background.dart`
- [x] `stop`+reclamo+guard en trailers (`featured_slider`, `item_detail`)
- [x] `stop` antes de `dispose` en `player_screen` y `live_tv`
- [x] `flutter analyze` sin errores nuevos

# Evidence
- `flutter analyze --no-pub` (28/09/2026): `No issues found!`.
- Pendiente prueba real con proceso fresco (ver `Next`).

# Next
- Protocolo de prueba: matar el proceso y `flutter run -d windows` desde cero (nunca hot restart tras cambios nativos); entrar/salir de juegos y del detalle rápido; si debug aborta, probar el exe release (el assert es de CRT debug). Si persiste: fijar `vo`/`gpu-api` de libmpv.
