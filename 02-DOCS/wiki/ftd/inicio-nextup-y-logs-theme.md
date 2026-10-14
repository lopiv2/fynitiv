# Ajustes de Inicio (orden A continuación) y limpieza de logs [Theme]

## Intent
Reordenar la fila "A continuación" del Inicio para que quede justo bajo "Continuar viendo" en el preset cuyo layout la tenía al final, y eliminar los `debugPrint` de diagnóstico `[Theme]` en la resolución/reproducción del theme, ya innecesarios.

## Scope
- In:
  - Preset de Inicio con layout custom: mover `LayoutSection.nextUp()` de la última posición a justo después de `continueWatching`.
  - Quitar todos los `debugPrint('[Theme] ...')` en `item_theme_player.dart`, `item_detail_screen.dart` y `library_providers.dart` (resolución de theme), junto con el código auxiliar que quedaba sin uso.
- Out:
  - Cambios de comportamiento en la reproducción del theme.
  - Otros presets/skins sin `homeLayout`.

## Checklist
- [x] Mover "A continuación" bajo "Continuar viendo" en el `homeLayout` del preset; comprobar el orden en `skin_presets.dart`.
- [x] Eliminar los logs `[Theme]`; comprobar con búsqueda (`grep [Theme]`) que no queda ninguno.
- [x] Análisis estático sin problemas; demostrar salida de `flutter analyze`.

## Evidence
- `lib/core/skin/skin_presets.dart`: en `disneyPlus.homeLayout` el orden pasa a
  `featuredSlider → continueWatching → nextUp → newReleases → custom(actionMovies) → custom(familyMovies) → recent`.
- `lib/core/audio/item_theme_player.dart`: sin `debugPrint`; eliminados `_short`, `_scheduleDiag` y el import de `soloud_initializer` que solo usaban los logs.
- `lib/features/library/presentation/item_detail_screen.dart`: `_maybeStartTheme` sin logs.
- `lib/features/library/application/library_providers.dart`: `jellyfinThemeAudioProvider`/`itemThemeProvider` sin logs; `catch` anónimos donde el error solo se imprimía.
- Búsqueda `\[Theme\]` en `lib/**/*.dart` → sin resultados.
- `flutter analyze` → `No issues found!`. (En el mismo pase se añadieron llaves a dos `if` que `dart format` destapó con `curly_braces_in_flow_control_structures`.)

## Next
Si un usuario tiene un skin Disney+ **personalizado** (JSON completo guardado), el cambio de preset no se hereda automáticamente; habría que reaplicar el preset o migrar el layout.
