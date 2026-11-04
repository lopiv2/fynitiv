# FTD — Transición entre capdrip y gota Halloween

## Intent

Corregir la unión visual al final del capdrip: actualmente el cuerpo entero de la gota se dibuja centrado en la línea base y se superpone como un bulto al extremo del capdrip. La punta debe tocar el extremo, empezar pequeña, desprenderse y crecer al caer; el balanceo comienza después de la separación.

## Scope

- `lib/router/splash_screen.dart`: posicionar la punta superior de `_drawFallingMucus` en el endpoint del capdrip al iniciar; aumentar el tamaño progresivamente; anclar la primera posición x al capdrip y aplicar sway solo durante la caída; estirar hilo desde el endpoint.
- Mantener velocidades individuales, `capFallSpeed`, tiempos de impacto y valores manuales de Halloween.
- Sin tests (no solicitados), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [ ] FTD creado antes del primer cambio.
- [ ] Al desprenderse, la punta de la gota conecta con el capdrip sin bulto superpuesto.
- [ ] La gota crece y se balancea durante la caída.
- [ ] `flutter analyze` limpio.

## Evidence

- (pendiente) salida de `flutter analyze`.

## Next

- Verificar visualmente el contacto capdrip→gota con override `halloween`.
