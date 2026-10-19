# Contraste universal de botones

## Intent
Que el texto y el fondo de cualquier botón de la app tengan contraste suficiente con cualquier skin, con o sin tema estacional, sin parches locales por pantalla (p. ej. "Emparejar con QR" de ROMM o "Probar sonido").

## Scope
- In:
  - Primario del `ColorScheme` aclarado hasta ser visible sobre los fondos oscuros del dashboard.
  - `onPrimary`/`onSecondary` calculados por luminancia para que el texto de los botones rellenos contraste.
  - Aplicación global en `AppTheme.fromSkin` (afecta a `FilledButton`, `OutlinedButton`, `TextButton`, chips, sliders, tabs…).
- Out:
  - Cambiar la identidad de color de los skins (se conserva el tono).
  - Retocar botones uno a uno.

## Checklist
- [x] Causa reproducida en el código: `primary` crudo + `onPrimary` de la semilla; `OutlinedButton`/`TextButton` usan `primary` como texto.
- [x] Aclarar `primary` por luminancia preservando el tono; `flutter analyze`.
- [x] Calcular `onPrimary`/`onSecondary` por luminancia; `flutter analyze`.
- [x] Reutilizar el primario accesible en el tema de switches; `flutter analyze`.
- [x] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- Causa: `AppTheme.fromSkin` hacía `fromSeed(...).copyWith(primary: skin.primary, secondary: skin.secondary)`. `onPrimary`/`onSecondary` seguían siendo los de la semilla, que no corresponden al color sobrescrito. Con primarios oscuros (Prime/Disney) el texto de `FilledButton` quedaba oscuro sobre fondo oscuro, y `OutlinedButton`/`TextButton` (que usan `primary` como foreground) también. Ya existía un parche local en `seerr_screen.dart` por este motivo.
- `lib/core/theme/app_theme.dart`:
  - `_visibleOnDark(color)`: si la luminancia relativa es menor que `0.2`, sube la luminosidad HSL en pasos de 0.05 conservando tono y saturación hasta superar el umbral. Un primario oscuro como el de Prime pasa a un azul visible.
  - `_onColor(background)`: devuelve `#10131C` si la luminancia supera `0.18`; si no, blanco. Se aplica a `onPrimary` y `onSecondary`.
  - El `switchTheme` recibe ya el primario accesible, así que track encendido y pulgar siguen contrastando.
- Efecto global: `FilledButton` (fondo primario visible + texto oscuro), `OutlinedButton`/`TextButton` (foreground primario visible), `TabBar`, `Slider`, `CircularProgressIndicator`, `ChoiceChip` seleccionado y el botón "Emparejar con QR" de ROMM y "Probar sonido" de Sonidos.
- `flutter analyze` → `No issues found!`.

## Next
Probar en Ajustes > Juegos (Emparejar con QR) y Ajustes > Sonidos (Probar sonido) con skins de primario oscuro (Prime/Disney) y con cada estación a 0 %, 35 % y 100 %.
