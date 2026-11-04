# FTD — Separar velocidad del drip y de la gota

## Intent

Aclarar y separar los dos ritmos del goteo de Halloween. `capFallSpeed` pasa a controlar solo la caída de la gota fuera de la letra; se añade `capDripSpeed` para controlar la velocidad con la que el capdrip crece dentro de la letra, que antes compartía ritmo y parecía demasiado rápido.

## Scope

- `lib/features/splash/domain/splash_presentation.dart`: agregar `capDripSpeed` (1.0 por defecto) y redefinir `capFallSpeed` como velocidad solo de la gota.
- `lib/router/splash_screen.dart`: normalizar el ciclo a partir de la suma de ambos ritmos, de modo que bajar `capDripSpeed` alargue el crecimiento sin acortar la caída; el desprendimiento de cada capdrip usa su propio umbral derivado de `capDripSpeed`.
- `halloween_splash_presentation.dart`: `capDripSpeed: 0.35` (drip interior lento) y `capFallSpeed: 1.0` (gota normal).
- Sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] `capDripSpeed` ralentiza/acelera solo el crecimiento dentro de la letra.
- [x] `capFallSpeed` afecta solo la caída de la gota.
- [x] Ambas fases completan antes de reiniciar el ciclo.
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/router/splash_screen.dart` → 0 cambios (ya formateado).
- `flutter analyze` sobre esos 3 ficheros → No issues found.
- `grow = (0.42..0.70 / capDripSpeed) / escala` y `fall = (0.20..0.38 / capFallSpeed) / escala`, con `escala = 0.70/capDripSpeed + 0.38/capFallSpeed`. Con `0.35 / 1.0` el ciclo dura ~4,3 s y el drip tarda ~2,2–3,6 s en recorrer la letra; la gota cae en ~0,4–0,7 s.
- `_capDripProgresses` (clipper interior) y `_BloodRainPainter` (desprendimiento) usan la misma semilla y la misma normalización, así que cada drip suelta su gota justo al llegar a la base.

## Next

- Verificar visualmente con override `halloween`: drip lento dentro de la letra y gota con caída normal; ajustar `capDripSpeed` (más bajo = más lento) según gusto.
