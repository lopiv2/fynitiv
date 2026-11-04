# FTD — Borde fino en letras de Pascua

## Intent

Afinar el borde (outline) blanco de las letras del título solo en la presentación de Pascua, donde destaca demasiado: añadir grosor configurable a `SplashPresentation` (por defecto 3.5, el actual) y fijar un valor fino en Pascua.

## Scope

- `lib/features/splash/domain/splash_presentation.dart`: nuevo campo `letterOutlineWidth` (defecto 3.5).
- `lib/router/splash_screen.dart`: `_LetterTile` acepta el grosor y lo usa en el `strokeWidth` del outline.
- `lib/features/splash/presentation/presentations/easter_splash_presentation.dart`: `letterOutlineWidth` fino (1.2).
- Sin cambios de textos (no ARB), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Grosor configurable con defecto intacto.
- [x] Pascua con borde fino.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/easter_splash_presentation.dart lib/router/splash_screen.dart` → No issues found.
- `SplashPresentation.letterOutlineWidth` (defecto 3.5); `_LetterTile` lo usa en el `strokeWidth`; Pascua fija grosor fino a mano (0.1, corrección del usuario que se respeta).
- El color ya era parámetro (`letterOutlineColor`, defecto blanco): Pascua fija `0xFFB39DDB` (lavanda suave) en vez del blanco.

## Next

- Verificar con override `easter` (borde sutil) y que el resto de estaciones mantienen el borde actual.
