# Intent
Que la música de fondo de juego online suene en las pantallas de juego (`/games` y listas `/games/platform/*`) pero NUNCA en el detalle, ni al entrar ni al volver de otra rama. Al salir del detalle a la lista, el fondo debe retomarse.

# Scope v3 (vuelta atrás parcial: plataforma sí tiene fondo + resume explícito)
- La v1/v2 dejaron la plataforma sin fondo y `returnFromDetail()` (protegido por `_inside` vacío tras el `leave()`) ya no retomaba nada al hacer pop del detalle. Se restaura plataforma como dentro (como el diseño original "hub o lista") y el `dispose` del detalle retoma con método nuevo dedicado.
- In v3: `_isInsideGames` (shell + scope) vuelve a incluir `/games/platform`; `GameBgPlayer.resumeListsAfterDetail()` (retoma con reshuffle aunque la cola esté vacía, salvo mute); el `dispose` del detalle llama `exitDetail()` + `resumeListsAfterDetail()` en vez de `returnFromDetail()`; se mantiene el veto `detailOpen` (restaura desde Ajustes sin `initState`) y la URI real en el shell.
- Seguro porque el detalle solo se abre con `push` desde listas (jukebox nunca abre detalles: solo autoplay), así que su `dispose` siempre vuelve a una lista con fondo.

# Scope
- In: `lib/router/home_shell.dart` (`_isInsideGames` + `_syncMusic`: usar la URI completa de `routeInformationProvider` en vez del `matchedLocation` del shell, que se queda stale en `/games`, y exigir `/games` exacto) y `lib/features/games/presentation/widgets/game_music_scope.dart` (`_isInsideGames`: `/games` exacto para no pelearse con el shell); comentarios que decían "hub o lista".
- Out: cambios en OST/jukebox, ARB, tests.

# Scope v2 (el detalle veta el fondo aunque la ruta llegue tarde)
- La v1 quitó una protección accidental (antes plataforma contaba como dentro y el guard `nowInside==_inside` bloqueaba re-enters tardíos; además `GameMusicScope` está muerto — sin usos — así que el shell decide solo). Si un rebuild del shell lee `/games` stale DESPUÉS del `suspendForDetail` del detalle, nada lo para.
- In v2: `GameBgPlayer` suma contador `_detailDepth` + `detailOpen` + `enterDetail()`/`exitDetail()` (solo los toca el detalle, nunca el jukebox); `game_detail_screen.dart` los llama en `initState`/`dispose`; `_syncMusic` veta `enter()` con `detailOpen` (solo `leave`). Regla intacta: solo `/games` suena.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Shell usa URI real y solo `/games` exacto
- [x] Scope solo `/games` exacto (sin pelea enter/leave)
- [x] `flutter analyze` sin issues
- [x] v2: veto `detailOpen` (enter/exitDetail + gate en `_syncMusic`)
- [x] v3: plataforma vuelve a dentro + `resumeListsAfterDetail()` en el `dispose` del detalle
- [x] `flutter analyze` v3 sin issues

# Evidence (verificacion)
- `flutter analyze` (home_shell + game_music_scope + game_bg_player) → "No issues found!".
- v2: `flutter analyze` (game_bg_player + home_shell + game_detail_screen) → "No issues found!".

# Evidence
- Doble control: `home_shell.dart:98` (`_syncMusic`) y `game_music_scope.dart:75` (`_checkLocation`), ambos con `_inside` + `enter()`/`leave()`.
- El propio shell admite el stale: `home_shell.dart:255` ("matchedLocation en el shell puede quedarse en '/games' aunque el inner navigator esté en '/games/jukebox'").
- Secuencia del bug: Ajustes → rama games (restaura detalle, State preservado sin `initState` ni `suspendForDetail`) → shell ve `/games` stale → `enter()`; el scope ve `/games/rom/123` pero su `_inside` ya era false → no compensa.
- Regla pedida: solo la principal (`/games`); plataforma/detalle/jukebox sin fondo.

# Next
Probar: Ajustes → Juego online (detalle) sin música; volver a `/games` con música; plataforma y jukebox sin fondo.
