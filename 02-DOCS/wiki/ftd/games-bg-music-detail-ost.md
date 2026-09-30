# Intent
Que la música de fondo de la rama de juegos siga la regla pedida: suena en las pantallas de juegos; al abrir un detalle con OST se calla y suena el OST; si el juego NO tiene OST, el fondo sigue sonando; al volver a la pantalla de juegos el fondo vuelve a sonar (play, no pause); con el switch de música apagado no suena ni fondo ni OST. El switch de vídeo mantiene la misma semántica.

# Scope
- In: `lib/core/audio/game_bg_player.dart` (`enter()` retoma si quedó pausado; retirada del veto `enterDetail`/`exitDetail`/`detailOpen`); `lib/router/home_shell.dart` (`_isInsideGames` incluye `/games/rom`; veto del shell solo cuando el OST del detalle está activo); `lib/features/games/presentation/game_detail_screen.dart` (no suspender el fondo al entrar; suspenderlo solo si hay OST; sin OST forzar `enter()`; reanudar al salir).
- Out: OST/jukebox, `soloud_music_provider`, ARB, tests, vídeo (solo verificación del switch).

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] `game_bg_player.dart` sin `detailOpen`; `enter()` retoma si pausado
- [x] `home_shell.dart` incluye detalle como dentro y veta solo con OST activo
- [x] `game_detail_screen.dart` suspende el fondo solo si hay OST y lo reanuda al salir
- [x] Switch de vídeo verificado (misma semántica)
- [x] `flutter analyze` sin issues

# Evidence (verificacion)
- Causa del silencio: el `initState` del detalle llamaba `enterDetail()` + `suspendForDetail()` SIEMPRE, así que un juego sin OST dejaba la música de fondo parada (el shell además veía `/games/rom/...` como fuera de la rama y hacía `leave()`).
- `home_shell._isInsideGames` ahora incluye `/games/rom` (el detalle decide su audio) y `_syncMusic` no toca el fondo mientras `GameOstPlayer.instance.isPlaying` (el detalle manda). El jukebox sigue fuera.
- `game_detail_screen`: el fondo no se corta al entrar; `_maybeStartOst` hace `enter()` si no hay pistas o `suspendForDetail()` + `playQueue` si las hay; el `dispose` solo reanuda (`resumeListsAfterDetail`) si `_bgSuspended`.
- `GameBgPlayer.enter()` retoma si la voz quedó en pausa al re-entrar en `/games` (play, no pause).
- Switch de vídeo: `GameVideoBackground` ya reacciona a `gameVideoDisabledProvider` (teardown/creación) y persiste en sesión; misma semántica que el de música (apagado = sin fondo).
- `flutter analyze lib` → "No issues found! (ran in 5.4s)".

# Next
- Prueba manual en Windows: (1) entrar en Juegos con switch ON → suena; (2) abrir detalle sin OST → sigue sonando; (3) abrir detalle con OST → calla y suena OST; (4) volver → vuelve a sonar (play); (5) apagar switch → silencio total (fondo y OST); (6) mismo con el switch de vídeo.
