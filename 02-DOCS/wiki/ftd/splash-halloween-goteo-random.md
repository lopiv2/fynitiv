# FTD — Variación aleatoria por ciclo del goteo Halloween

## Intent

Evitar que el goteo repita siempre las mismas posiciones, tamaños y velocidades. Cambiar los atributos de cada gota en cada ciclo, pero mantenerlos estables durante ese ciclo para que no haya parpadeo entre fotogramas.

## Scope

- `lib/router/splash_screen.dart`: cambiar la semilla del `SnowDripClipper` por ciclo y derivar de ella distintos centros/anchos, tamaño y velocidad de caída; mantener el mismo progreso de crecimiento para que cada chorrete llegue abajo antes del desprendimiento.
- Mantener anclaje en baseline de tinta, cuerpo mucoso, caída al borde inferior, splash al impactar, y no consultar dimensiones/baselines de RenderBox durante `paint`.
- Sin tests (no solicitados), no tocar personalizaciones manuales, sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Patrón/tamaño/velocidad diferentes en ciclos sucesivos.
- [x] Atributos estables dentro de cada ciclo (sin flicker).
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/router/splash_screen.dart` → archivo formateado.
- `flutter analyze lib/router/splash_screen.dart` → No issues found.
- `AnimationController.lastElapsedDuration ~/ 1.8s` entrega el ciclo global; el hash estable mezcla ese índice con la identidad de cada letra para cambiar los centros/anchos del clipper y tamaño/velocidad de cada gota. Los parámetros no cambian entre fotogramas.

## Next

- Verificar visualmente con override `halloween` que el goteo no repite el mismo patrón ni tamaño en ciclos sucesivos, sin vibración dentro de cada ciclo.
