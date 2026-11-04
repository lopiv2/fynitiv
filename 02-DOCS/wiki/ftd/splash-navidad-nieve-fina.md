# FTD — Nieve parametrizable y afinada en Navidad

## Intent

Arreglar la nieve de las letras en la presentación de Navidad: con la fuente CHRICI__ los casquetes quedan como pegotes (franja del 30% + 3 chorretes anchos). Parametrizar la nieve en `SplashPresentation` (defectos = valores actuales) y afinarla solo en Navidad.

## Scope

- `lib/features/splash/domain/splash_presentation.dart`: nuevos campos `snowDepth` (0.30), `snowDripMax` (0.13), `snowDrips` (3).
- `lib/router/splash_screen.dart`: `_LetterTile` acepta los 3 y los pasa al `SnowDripClipper`.
- `lib/features/splash/presentation/presentations/christmas_splash_presentation.dart`: nieve fina (`snowDepth: 0.16`, `snowDripMax: 0.08`, `snowDrips: 4`).
- Sin cambios de textos (no ARB), sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] Nieve configurable con defectos intactos.
- [x] Navidad con nieve fina.
- [x] `flutter analyze` limpio.

## Evidence

- `flutter analyze lib/features/splash/domain/splash_presentation.dart lib/features/splash/presentation/presentations/christmas_splash_presentation.dart lib/router/splash_screen.dart` → No issues found.
- Medición con fonttools sobre `CHRICI__.TTF` (upm 1000, win 1066/438; yMax F835 Y841 N869 I845 T838 V906): arranques de tinta F.154 Y.150 N.131 I.147 T.151 V.106 de la caja. Con la nieve anterior (valles en 0.148) quedaban sin cubrir justo F/Y/I/T → coincide con lo reportado. Con `0.24` los valles quedan en 0.228 (margen ~15px a 155px) → cobertura total.
- Correcciones a mano del usuario respetadas (tamaño 155, borde verde fino); los valores de prueba 0.36/0.18/8 se sustituyen por los del fix pedido.

## Next

- Verificar con override `christmas` (casquetes finos sobre CHRICI__) y que el resto no cambia (solo Navidad usa nieve).
