# FTD — Capdrips de Halloween sincronizados con la caída

## Intent

Hacer que los `capDrips` rojos recortados dentro de cada letra crezcan desde el casquete hasta la línea base visible; cuando llegan abajo, los mismos puntos emiten las gotas que caen al suelo. El capdrip interior y la caída no deben ser dos patrones independientes.

## Scope

- `lib/core/widgets/snow_drip.dart`: añadir modo opcional `dripsReachBottom` + `dripBottomRatio` al path/clipper, dejando intacto el comportamiento de nieve existente.
- `SplashPresentation` / `_LetterTile`: parametrizar el modo y pasar baseline como destino; Halloween lo activa.
- `lib/router/splash_screen.dart`: generar centros/anchos con la misma semilla que el clipper; hacer crecer capdrips durante la primera fase y desprender gotas desde esos mismos puntos al llegar al baseline. Mantener variación por ciclo en semilla, tamaño y velocidad.
- Sin cambios de textos (no ARB), sin tests (no solicitados), sin tocar `PrimeCardBadge` ni otros ajustes manuales, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Los capdrips dentro del texto recorren hasta el baseline, no solo media letra.
- [x] Las gotas se desprenden desde el extremo del mismo capdrip y llegan abajo.
- [x] Nieve de Navidad y `SnowCapOverlay` mantienen el comportamiento existente.
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/core/widgets/snow_drip.dart lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/router/splash_screen.dart` → 0 archivos modificados (ya formateados).
- `flutter analyze lib/core/widgets/snow_drip.dart lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart lib/router/splash_screen.dart` → No issues found.
- `buildSnowDripPath` / `SnowDripClipper` soportan `dripsReachBottom` y `dripBottomRatio`; Halloween activa el modo y pasa `baseline / textHeight`. `capMelt` llega a 1 en el 58% del ciclo; desde ese mismo punto `_BloodRainPainter` reproduce semilla, centros y anchos del clipper y desprende gotas desde cada baseline.
- Navidad y demás llamadas conservan `dripsReachBottom: false` por defecto; el generador de nieve no cambia.

## Next

- Verificar visualmente con override `halloween` que cada capdrip recortado llega al fin de la tinta y desde ahí cae la gota.
