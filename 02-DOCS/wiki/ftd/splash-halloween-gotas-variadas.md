# FTD — Variación de gotas en Halloween

## Intent

Evitar que las gotas mucosas de Halloween parezcan sincronizadas o uniformes: variar de forma determinista la velocidad, el tamaño, el estiramiento máximo y el tiempo de desprendimiento de cada gota.

## Scope

- `lib/router/splash_screen.dart`: derivar parámetros distintos por gota usando su índice/semilla; conservar posiciones ancladas al título y la caída hasta el borde inferior.
- Mantener estiramiento viscoso, brillo y salpicadura; no tocar configuraciones manuales de las presentaciones.
- Sin cambios de textos (no ARB), sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Gotas con velocidades y tamaños visiblemente distintos.
- [x] Variar estiramiento y desprendimiento sin aleatoriedad por fotograma.
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/router/splash_screen.dart` → archivo formateado.
- `flutter analyze lib/router/splash_screen.dart` → No issues found.
- Comprobación de los 8 orígenes actuales: velocidades normalizadas distintas (`0.56`–`1.21`) y factores de tamaño (`0.71`–`1.50`); también se varían el balanceo, el estiramiento máximo y las fases de caída/impacto con una semilla estable.

## Next

- Verificar visualmente con override `halloween` que gotas grandes/pequeñas caen en ritmos distintos sin parpadeo.
