# FTD — Gotas visibles en el splash de Halloween

## Intent

Corregir el goteo de sangre que no se aprecia: el efecto anterior solo variaba levemente la longitud del casquete superior. Dibujar gotas/trazos visibles bajando por las letras tras completar los 13 segundos de intro, mientras se espera Play.

## Scope

- `lib/router/splash_screen.dart`: añadir gotas animadas sobre las letras, cada una con rastro y caída continua; activarlas solo con `capAfterCompletion` y tras `AnimationStatus.completed`.
- Preservar el controlador post-presentación y detenerlo/reiniciarlo en replay; mantener el casquete de Navidad y la sangre base de Halloween.
- Sin cambios de textos (no ARB), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Gotas visibles recorren desde las letras hasta el borde inferior de la ventana.
- [x] No hay gotas durante la intro; replay reinicia el efecto.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/router/splash_screen.dart lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/halloween_splash_presentation.dart` → No issues found.
- Capa `CustomPaint` a pantalla completa reproduce las semillas/centros/anchos de `SnowDripClipper`; tras la fase interior del capdrip cae desde su baseline hasta `size.height` y salpica.
- La capa solo se construye con `capAfterCompletion` y `AnimationStatus.completed`; `_replay()` para y reinicia el controlador secundario.

## Next

- Verificar visualmente con override `halloween`: gotas salen del logo y llegan al borde inferior mientras queda el splash en espera de Play.
