# FTD — Goteo de sangre tras la presentación de Halloween

## Intent

Hacer que la sangre de las letras de Halloween empiece a gotear al terminar los 13 segundos de presentación y siga animándose mientras el usuario espera para pulsar Play. Durante la intro no debe aparecer; al repetirla debe detenerse y volver a arrancar al final.

## Scope

- `SplashPresentation`: parámetro `capAfterCompletion` (false por defecto).
- `lib/router/splash_screen.dart`: segundo `AnimationController` para el ciclo de goteo, activo solo después de `completed` y solo cuando la presentación lo solicita; reinicio al repetir/cambiar estación y liberación en `dispose`.
- `halloween_splash_presentation.dart`: activar `capAfterCompletion` para la sangre; preservar color, grosor, tamaño de fuente y geometría manuales del usuario.
- Sin cambios de textos (no ARB), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Sangre oculta durante la intro y animada después de completar.
- [x] Repetir presentación detiene el goteo hasta el siguiente final.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/features/splash/presentation/presentations/christmas_splash_presentation.dart lib/router/splash_screen.dart` → No issues found.
- `capAfterCompletion` solo habilita el casquete tras `AnimationStatus.completed`; el controlador secundario lo anima con ciclo reversible cada 1.8s. `_replay()` lo detiene y reinicia antes de volver a ejecutar la intro.

## Next

- Verificar visualmente con override `halloween`: intro sin sangre, goteo animado tras el final mientras se espera Play, repetición reinicia la secuencia.
