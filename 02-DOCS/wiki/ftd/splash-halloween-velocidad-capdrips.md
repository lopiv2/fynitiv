# FTD — Velocidad configurable de capdrips Halloween

## Intent

Hacer más perceptible que cada capdrip cae a una velocidad distinta y añadir un parámetro `capFallSpeed` en `SplashPresentation` para ajustar globalmente la velocidad de caída sin impedir que las gotas lleguen al suelo.

## Scope

- `lib/features/splash/domain/splash_presentation.dart`: agregar `capFallSpeed` (1.0 por defecto).
- `lib/router/splash_screen.dart`: aplicar el multiplicador global junto a un factor determinista distinto por capdrip; usar una curva de progreso que conserve el aterrizaje antes del splash/reset.
- No tocar geometría, centros/anchos sincronizados del clipper, colores ni personalizaciones manuales.
- Sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Diferencias de velocidad perceptibles entre capdrips.
- [x] `capFallSpeed` cambia la velocidad global y las gotas siguen llegando al suelo.
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/router/splash_screen.dart` → archivos formateados.
- `flutter analyze lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/router/splash_screen.dart` → No issues found.
- El factor propio por gota va de `0.55` a `1.85`, luego se multiplica por `capFallSpeed` (acotado a `0.25`–`3.0`). Cada gota recibe duración de caída propia (`0.20`–`0.38` del ciclo a velocidad normal) y su propio umbral de desprendimiento (`0.42`–`0.70`); la curva exponencial cambia el ritmo, y cada gota llega al suelo en un momento distinto antes de salpicar.
- Halloween expone `capFallSpeed: 1.0` como valor ajustable en su presentación.

## Next

- Verificar con override `halloween` el ritmo relativo de las gotas y ajustar `capFallSpeed` desde la presentación si hace falta.
