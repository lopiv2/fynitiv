# Contraste de switches con/sin tema estacional

## Intent
Que los switches de la app se vean siempre con el mismo contraste, tanto sin tema estacional como con cualquier intensidad del tinte, sin depender de los colores derivados del skin.

## Scope
- In:
  - Estilo global de `Switch` en `AppTheme.fromSkin` con track/pulgar de contraste garantizado.
  - Colores de estado apagado legibles sobre el fondo oscuro.
- Out:
  - Cambiar la paleta de los skins ni el resto de controles Material.
  - Rediseñar los switches (tamaño, forma o iconos).

## Checklist
- [x] Identificar la causa del contraste variable; comprobar `AppTheme.fromSkin` y los `Switch` afectados.
- [x] Añadir `SwitchThemeData` con track encendido aclarado y pulgar calculado por luminancia; `flutter analyze`.
- [x] Verificar estados apagado/encendido/deshabilitado; `flutter analyze`.
- [x] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- Causa: `AppTheme.fromSkin` sobrescribe `colorScheme.primary` con el primario crudo del skin (ya teñido por la estación), pero `onPrimary` sigue siendo el generado por `ColorScheme.fromSeed`. Con primarios oscuros (p. ej. skin Prime `#0B1030`) el track y el pulgar quedan casi del mismo tono; al subir la intensidad estacional el primario se aclara/colorea y el contraste mejora o empeora. El estado apagado usaba `surfaceContainerHighest`/`outline`, también derivados de la semilla y variables con el tinte.
- `lib/core/theme/app_theme.dart`: `fromSkin` pasa a definir `switchTheme`:
  - ON: track = primario accesible del `ColorScheme` (ver `contraste-botones-universal.md`); pulgar blanco o casi negro según la luminancia del track.
  - OFF: track `white 24%`, borde `white 40%`, pulgar `white 90%`, legibles sobre el fondo oscuro.
  - Disabled: track `white 12%`, borde `white 12%`, pulgar `white 38%`.
- Al ser tema global, cubre los switches de Preferencias, Apariencia (`_SwitchRow`), ecualizador y resto de pantallas.
- `flutter analyze` → `No issues found!`.

## Next
Probar visualmente en Preferencias y Apariencia: skin Prime sin estación (Auto fuera de calendario), y con cada estación al 0 %, 35 % y 100 % de intensidad, comprobando ON/OFF/deshabilitado.
