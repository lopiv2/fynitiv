# FTD — Hacer efectivo `capFallSpeed` bajo

## Intent

Corregir `capFallSpeed: 0.1`, que seguía cayendo rápido porque el valor se limitaba a `0.25` y el controlador reiniciaba el ciclo cada 1.8 segundos. Hacer que la duración real del ciclo escale de forma inversa a `capFallSpeed` (0.1 → ciclo 10 veces más largo), sin interrumpir capdrips/gotas.

## Scope

- `lib/router/splash_screen.dart`: configurar la duración del controlador al terminar la presentación; derivar el índice de ciclo y la fase individual desde la duración efectiva; quitar el clamp mínimo que neutralizaba `0.1`.
- Mantener `capFallSpeed` como control global, variación por capdrip, llegada al suelo y personalizaciones actuales.
- Sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] `capFallSpeed: 0.1` ralentiza realmente el ciclo y no reinicia gotas a mitad de caída.
- [x] Valores normales/superiores siguen funcionando.
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/router/splash_screen.dart` → archivos formateados.
- `flutter analyze lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/router/splash_screen.dart` → No issues found.
- Duración real de ciclo = `1800ms / clamp(capFallSpeed, 0.05, 3.0)`: `0.1` da 18s. Los thresholds de crecimiento se escalan inversamente para que el crecimiento inicial conserve su duración base y el tiempo extra quede en la caída (aprox. 3.6–6.8s para 0.1); los ciclos no reinician gotas en mitad del recorrido.

## Next

- `capFallSpeed` quedó redefinido como velocidad solo de la gota; el crecimiento interior se controla con `capDripSpeed` (ver `splash-halloween-cap-drip-speed.md`). Verificar visualmente con override `halloween`.
