# Respetar pausa manual del OST al recuperar el foco

## Intent
En el detalle del juego, si el usuario pausaba el OST y la app perdía/recuperaba el foco (en Windows: `inactive → resumed`), la música se reanudaba sola. El `resumeIfNeeded` no distinguía pausa manual de corte del sistema.

## Scope
- In: flag `_userPaused` en `GameOstPlayer` (`lib/core/audio/game_ost_player.dart`); `toggle()` lo marca/limpia; `playQueue/next/previous/playTrack/stop` lo limpian; `setMuted(false)` no auto-arranca si hay pausa manual; `resumeIfNeeded()` retorna early con `_userPaused`. `pauseForExternal()` no toca el flag (corte del sistema sí se recupera).
- Out: mismo patrón en `ItemThemePlayer`/`GameBgPlayer` (no tocados; `GameBgPlayer` no tiene pausa de usuario, solo mute/stop).

## Checklist
- [x] Flag `_userPaused` + getter — `flutter analyze` sin issues en `game_ost_player.dart` y `game_detail_screen.dart`
- [x] Pausa manual sobrevive a perder/recuperar foco; corte del sistema se sigue recuperando — verificado por lectura de `didChangeAppLifecycleState` (detalle solo llama a `resumeIfNeeded` en `resumed`); sin test de dispositivo (el usuario no pide tests)

## Evidence
- `flutter analyze lib/core/audio/game_ost_player.dart lib/features/games/presentation/game_detail_screen.dart` → "No issues found!"

## Next
Preguntado al usuario: aplicar el mismo flag a `ItemThemePlayer`, que comparte el patrón. Pendiente de respuesta.
