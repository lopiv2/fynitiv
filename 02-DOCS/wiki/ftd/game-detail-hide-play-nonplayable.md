# Intent
En el detalle de juego, ocultar el botón de jugar cuando la plataforma no es jugable en el navegador (sin core EmulatorJS) y dejar solo el botón de descargar.

# Scope
- In: `lib/features/games/presentation/game_detail_screen.dart` — `_GameHeroInfo` calcula `isEmulatorJsPlayable(game.platformSlug)` y muestra el botón Play solo si es jugable; import de `../data/emulatorjs_playable.dart`.
- Out: tarjetas/listas (`games_screen` ya usa el helper para el badge), lógica de descarga/streaming, ARB, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Play oculto si la plataforma no es EmulatorJS-playable
- [x] Descargar siempre visible
- [x] `flutter analyze lib` sin issues

# Evidence (verificacion)
- `_GameHeroInfo` decide con `isEmulatorJsPlayable(game.platformSlug)` (mismo helper que el badge de `games_screen`): si false, no se construye `_OriginButton` de Jugar; Descargar se mantiene.
- `flutter analyze lib` → "No issues found! (ran in 15.4s)".

# Next
- Probar en el detalle de una plataforma no jugable (p. ej. GameCube/Wii) → solo Descargar; y en una jugable (NES, SNES, PSX…) → Jugar + Descargar.
