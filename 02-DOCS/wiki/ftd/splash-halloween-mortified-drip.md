# FTD: Splash Halloween con Super Midnight

## Intent
Usar la fuente Super Midnight (recién añadida en `assets/fonts/`) solo en la presentación de Halloween del Splash, manteniendo los colores actuales de la presentación.

## Scope
- `pubspec.yaml`: registrar las 3 fuentes añadidas (`MortifiedDrip.ttf`, `October Crow.ttf`, `Super Midnight.ttf`).
- `lib/features/splash/domain/splash_presentation.dart`: nuevo campo opcional `titleFontFamily`.
- `lib/features/splash/presentation/presentations/halloween_splash_presentation.dart`: fijar `titleFontFamily: 'MortifiedDrip'`, sin tocar colores.
- `lib/router/splash_screen.dart`: aplicar `titleFontFamily` a las letras del título (cara frontal, extrusión, outline, nieve) manteniendo tamaños, pesos y colores/gradientes.
- No tocar: resto de presentaciones, tagline, ARB (sin textos nuevos).

## Checklist
- [x] Doc FTD creado antes del primer cambio
- [x] Fuentes registradas en `pubspec.yaml`
- [x] `titleFontFamily` añadido y fijado solo en Halloween
- [x] Título del Splash usa la fuente manteniendo colores/gradientes
- [x] `flutter analyze` sin nuevos problemas en los archivos tocados

## Evidence
- `flutter pub get` OK + `flutter analyze lib/router/splash_screen.dart lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart` → No issues found.
- Halloween fija `titleFontFamily: 'SuperMidnight'` (`halloween_splash_presentation.dart`); resto de presentaciones con `null` (fuente del sistema). Colores/gradientes/extrusión sin cambios.

## Next
- Ver en Splash con evento Halloween forzado cómo queda Mortified Drip y decidir si se extiende al tagline o se ajusta tamaño/peso.
