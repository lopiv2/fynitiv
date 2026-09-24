# Jukebox tarjeta plataforma con LED persistente

## Intent
El `IconButton` de jukebox en el header de `games_screen` es invisible a distancia y no usa el sistema universal `AppHover`. Reemplazarlo por una tarjeta reutilizable tipo plataforma (`AppHover` + `scaleHighlightOutlineLed`) con un dot LED en esquina siempre visible cuando hay música sonando, para que en Smart TV (D-Pad, sin hover) el indicio "hay música" sobreviva aunque el foco esté en otra fila.

## Scope
- In: `lib/features/games/presentation/widgets/jukebox_entry_card.dart` nuevo `ConsumerWidget` reutilizable (glassmorphism + `AppHover` + `Stack` dot LED, adaptable de tamaño); `lib/features/games/presentation/games_screen.dart` mantiene el botón en `_HeroHeader` pero compacto (`38x38`, `AppHover scaleHighlightOutlineLed`, `Stack` dot LED `9px` en `-2,-2` persistente); LED activo cuando `soloudMusicProvider.hasItem && playing && !completed` (mismo token `skin.accent` que plataformas), con borde blanco y glow sutil; `onTap: context.push('/games/jukebox')`; foco D-Pad y sonido hover preservados; grid de plataformas vuelve a `filtered.length` sin jukebox.
- Out: cambios en `jukebox_screen.dart`, `soloud_music_provider.dart`, `AppHover` o `platform_led_color.dart`; jukebox como plataforma en grid, animación de pulso, contador de pistas, persistencia en settings.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] `jukebox_entry_card.dart` creado con `AppHover` universal + dot LED — `flutter analyze` sin issues
- [x] `games_screen.dart` usa la tarjeta como primera celda del grid y retira el IconButton del header — `flutter analyze` sin issues
- [x] `flutter analyze` global sin issues

## Evidence
- `flutter analyze` (2 ficheros + global) → "No issues found!"

## Evidence
- Header actual `lib/features/games/presentation/games_screen.dart:331` `IconButton(Icons.library_music)` fuera del sistema `AppHover`; `_PlatformCard:599` ya usa `AppHover(scaleHighlightOutlineLed, glass+blur10, ledColor=platformLedColor)`.
- `AppHover` en `lib/core/widgets/app_hover.dart:124` solo pinta LED con `_active` (hover/focus) → necesita capa persistente para TV sin foco.
- Ruta `lib/router/app_router.dart:267` `path 'jukebox'` existente; estado `SoloudMusicState` en `lib/features/music/application/soloud_music_provider.dart:63` expone `playing/hasItem/completed`.
- `platform_led_color.dart:9` Neón por hash, para jukebox se usa `skin.accent` fijo (lenguaje LED consistente).

## Next
Ajustar `childAspectRatio` si la tarjeta queda desproporcionada, añadir pulso suave al dot si se valida a distancia, y extraer `_PlatformCard` a widget público reutilizable si se quiere compartir más.
