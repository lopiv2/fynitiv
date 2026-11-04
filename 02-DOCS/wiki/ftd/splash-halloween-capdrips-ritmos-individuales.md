# FTD — Ritmo individual por capdrip Halloween

## Intent

Dar a cada capdrip interior de cada letra un tiempo de estiramiento distinto y sincronizar su propia gota con ese punto de desprendimiento. No deben compartir un único progreso de crecimiento, aunque conserven el control global `capFallSpeed`.

## Scope

- `lib/core/widgets/snow_drip.dart`: admitir progreso individual por capdrip en el modo `dripsReachBottom`, preservando nieve y llamadas existentes.
- `lib/router/splash_screen.dart`: derivar duración de estiramiento por semilla (letra + capdrip + ciclo), pasarlo al clipper y usar el mismo umbral en el painter de gotas; mantener velocidad/duración de caída individuales y el parámetro global.
- No tocar personalizaciones manuales de Halloween, sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Cada capdrip crece a un ritmo propio.
- [x] Su gota se desprende cuando ese capdrip llega a la base.
- [x] `capFallSpeed` sigue controlando la caída global y cada gota varía individualmente.
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/core/widgets/snow_drip.dart lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/router/splash_screen.dart` → formato limpio (solo `splash_screen.dart` requirió cambios).
- `flutter analyze lib/core/widgets/snow_drip.dart lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/router/splash_screen.dart` → No issues found.
- Cada fase de estiramiento usa la misma semilla letra+capdrip+ciclo en `_capDripProgresses` y `_BloodRainPainter`; thresholds distintos (`0.42`–`0.70`) sincronizan el final del capdrip con el inicio de su gota.

## Next

- Verificar visualmente con override `halloween` que los capdrips parten/escalonan y caen en momentos distintos.
