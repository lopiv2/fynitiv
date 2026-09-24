# Jukebox UI completa como foto

## Intent
Toda la interfaz de `jukebox_screen` debe quedar como en la captura: header con buscador integrado, tabs con iconos, tres secciones apiladas (Listas de reproducción 4 cards con fondo, Biblioteca 5 cards, Recientes con covers) y lateral derecho player + lista. El mini global sigue oculto solo dentro de jukebox.

## Scope
- In: `jukebox_screen.dart` rehace `build` para header buscador + `_TabChips` con iconos, `_Section` contenedor, `_MixesRow`/`_LibraryRow` con cards con fondo/overlay/play, nuevo `_RecientesSection`, lateral `JukeboxNowPlayingPanel` ya integrado; reutiliza `AppHover`, `GameVideoBackground`, `jukebox_providers`; `mini_player_bar` y `home_shell` mantienen hide en `/games/jukebox`.
- Out: cambios en providers, `GameOstPlayer`, FAB, skins.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] Panel lateral creado con cover + controles — `flutter analyze` sin issues
- [x] `jukebox_screen` integra panel y mantiene lista — `flutter analyze` sin issues
- [x] Mini global oculto solo dentro de jukebox — `flutter analyze` sin issues
- [x] `flutter analyze` global sin issues

## Evidence
- `jukebox_screen.dart:263` `Row(left 380 + Expanded right)` con `_TrackListView` solo lista; `home_shell.dart:265` `MiniPlayerBar` siempre visible si `hasItem`; `soloud_music_provider.dart:102` `isRomm`, `playing`, `coverUrl` ya resuelve portada juego.

## Next
Ajustar `childAspectRatio` del panel lateral en narrow (`Stack` vs `Row`) y decidir si el volumen va en lateral o se mantiene en mini oculto.
