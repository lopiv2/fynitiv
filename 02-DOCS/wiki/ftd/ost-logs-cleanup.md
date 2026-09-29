# Intent
Borrar los logs de consola de la OST (ruido `[Ost]` / `[ROMM] GET /api/music/...` en cada apertura del detalle y cada carga del jukebox). Se conserva el log de error de descarga de assets (no es OST y sirve para diagnosticar la caratula 3D).

# Scope
- In: `lib/core/audio/game_ost_player.dart` (5 `debugPrint('[Ost]...')` + import foundation si queda sin uso), `lib/features/games/presentation/game_detail_screen.dart:101` (`[Ost] _maybeStartOst`), `lib/features/games/data/romm_repository.dart` (4 logs `GET /api/music/...` de games/platforms/facet/tracks).
- Out: resto de logs (`[Theme]`, `[GameVideoBackground]`, `asset bytes failed`), cambios de comportamiento, ARB, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Logs `[Ost]` eliminados de `game_ost_player.dart` y `game_detail_screen.dart`
- [x] Logs `GET /api/music/...` eliminados de `romm_repository.dart`
- [x] `flutter analyze` sin issues

# Evidence (verificacion)
- `flutter analyze` (4 ficheros: game_ost_player, game_detail_screen, romm_repository, game_box3d_viewer) → "No issues found!".

# Evidence
- `game_ost_player.dart:173,191,196,202,228` — `debugPrint('[Ost] ...')` en `_playCurrent`/`playQueue`.
- `game_detail_screen.dart:101` — `debugPrint('[Ost] _maybeStartOst ...')`.
- `romm_repository.dart:985,1020,1047,1094` — `debugPrint('[ROMM] GET /api/music/...')`.
- Se conserva `romm_repository.dart:1150` (`asset bytes failed`, via de error para la caratula 3D).

# Next
Abrir el detalle de un juego y el jukebox y comprobar que la consola ya no muestra lineas `[Ost]` ni `GET /api/music`.
