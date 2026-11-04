# FTD — Tamaño del título parametrizable en splash

## Intent

Parametrizar el tamaño de las letras del título (FYNITIV) en `SplashPresentation` (defecto 160, el actual) y reducir un punto la presentación de Navidad, cuya fuente CHRICI__ se ve muy grande.

## Scope

- `lib/features/splash/domain/splash_presentation.dart`: nuevo campo `titleFontSize` (defecto 160.0).
- `lib/router/splash_screen.dart`: `_LetterTile` acepta `fontSize` y lo usa en los 3 `TextStyle` (cara, outline, nieve).
- `lib/features/splash/presentation/presentations/christmas_splash_presentation.dart`: `titleFontSize: 159`.
- Sin cambios de textos (no ARB), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Tamaño configurable con defecto intacto.
- [x] Navidad a 159.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/christmas_splash_presentation.dart lib/router/splash_screen.dart` → No issues found.
- `SplashPresentation.titleFontSize` (defecto 160.0); `_LetterTile.fontSize` lo usa en cara, outline y nieve; Navidad fija `159`, resto sin cambios.

## Next

- Verificar con override `christmas` (título un punto menor) y que el resto mantiene el tamaño actual.
