# FTD — Leer geometría de letras fuera del pintado

## Intent

Corregir la aserción de `RenderBox` al pintar las gotas de Halloween. El custom painter no debe consultar directamente `size`, baseline ni transformaciones de otros render objects durante su propio paint; la geometría de origen debe entregarse como datos ya calculados por el layout.

## Scope

- `lib/router/splash_screen.dart`: quitar lecturas de `RenderBox.size` / `getDistanceToBaseline` externas desde `_BloodRainPainter.paint`; precalcular métricas locales con `TextPainter` y mapear puntos locales mediante `localToGlobal`.
- Mantener orígenes en la línea base visible, gotas variadas, ciclo stretch→fall→impact, y claves sin duplicación.
- Sin tests (no solicitados), no tocar personalizaciones manuales, sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] FTD creado antes del primer cambio.
- [x] El painter no consulta `size` ni baseline de render objects ajenos durante `paint`.
- [x] Aserción de baseline eliminada; la animación sigue usando las transformaciones del glifo.
- [x] `flutter analyze` limpio.

## Evidence

- `dart format lib/router/splash_screen.dart` → archivo formateado.
- `flutter analyze lib/router/splash_screen.dart` → No issues found.
- Las métricas locales (ancho, alto y baseline) se calculan una vez con `TextPainter` al cambiar fuente/tamaño/escalado/dirección. Durante el pintado solo se consulta `localToGlobal` de los glifos y se transforma el punto local de origen; ya no se invoca `getDistanceToBaseline` ni se lee `RenderBox.size` externo.

## Next

- Verificar en ejecución que no aparece la aserción y que las gotas siguen naciendo en la tinta.
