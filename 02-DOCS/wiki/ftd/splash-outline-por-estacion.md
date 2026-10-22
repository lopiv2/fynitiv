# FTD: Borde del título del Splash por estación

## Intent
El borde (outline) de las letras del título del Splash es hoy blanco fijo. Se quiere poder cambiarlo según la estación a demanda, manteniendo el blanco como valor por defecto.

## Scope
- `lib/features/splash/domain/splash_presentation.dart`: nuevo campo `letterOutlineColor` (por defecto blanco).
- `lib/router/splash_screen.dart`: `_LetterTile` recibe el color de la presentación y lo usa en el `Paint` del outline (grosor 3.5 sin cambios); sombra del borde derivada del mismo color con alpha 0.30 (equivale al blanco actual).
- No se cambian colores de ninguna presentación: Halloween y resto siguen en blanco hasta que se pida otro valor.
- No tocar: fuentes, gradientes, extrusión, ARB (sin textos nuevos).

## Checklist
- [x] Doc FTD creado antes del primer cambio
- [x] Campo `letterOutlineColor` añadido con defecto blanco
- [x] `_LetterTile` usa el color de la presentación
- [x] Halloween fija `letterOutlineColor: Color(0xFFFABDAD)` (rosa opaco)
- [x] `flutter analyze` sin nuevos problemas en los archivos tocados

## Evidence
- `flutter analyze lib/router/splash_screen.dart lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart` → No issues found.
- El outline queda en `splash_screen.dart` (`Paint` con `strokeWidth 3.5` + `letterOutlineColor`); la sombra del borde deriva del mismo color con alpha 0.30 (equivale al blanco anterior por defecto).

## Next
- Fijar `letterOutlineColor` en la presentación que se quiera (p. ej. Halloween) cuando se elija el color.
