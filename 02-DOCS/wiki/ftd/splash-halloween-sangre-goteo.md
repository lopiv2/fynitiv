# FTD — Sangre goteando en Halloween

## Intent

Añadir goteo de sangre en las letras del título en la presentación de Halloween, del color del borde (`letterOutlineColor`), reutilizando el mecanismo de casquetes (banda superior + chorretes) ya parametrizado para la nieve, sin duplicar código.

## Scope

- `lib/features/splash/domain/splash_presentation.dart`: generalizar la nieve a casquete (`capEnabled`, `capColor`, `capShadowColor`; `snowDepth/DripMax/Drips` pasan a `capDepth/capDripMax/capDrips` con mismos defectos).
- `lib/router/splash_screen.dart`: `_LetterTile` usa el casquete genérico (color y sombra de la presentación).
- `christmas_splash_presentation.dart`: mismos valores actuales con los nombres nuevos.
- `halloween_splash_presentation.dart`: `capEnabled` + `capDripsReachBottom` con el color del borde; los chorretes se extienden después hasta la baseline y las gotas caen desde esos mismos centros (ver FTD `splash-halloween-capdrips-caida-sincronizada.md`).
- Sin cambios de textos (no ARB), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Casquete genérico con defecto intacto (Navidad igual que ahora).
- [x] Halloween con sangre del color del borde y chorretes largos.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/features/splash/presentation/presentations/christmas_splash_presentation.dart lib/router/splash_screen.dart` → No issues found.
- `SplashPresentation`: `capEnabled` (false), `capColor` (blanco nieve), `capShadowColor`, `capDepth` (0.30), `capDripMax` (0.13), `capDrips` (3); `_LetterTile` pinta el casquete genérico.
- Navidad: `capEnabled: true` con sus valores actuales (0.24/0.17/6, `dripMax` a mano respetado); Halloween: sangre `_kHalloweenBlood` (color del borde), profundidad `0.14`, `capDrips: 4` y `capDripsReachBottom: true` (el valor `capDripMax: 0.22` queda como dato configurado, mientras el modo alcanza la baseline medida).

## Next

- Verificar con override `halloween` (sangre cubriendo arriba con chorretes largos) y `christmas` (nieve sin cambios).
