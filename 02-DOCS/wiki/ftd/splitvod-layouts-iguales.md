# splitVod en todos los presets y layouts de split iguales al VOD

## Intent

Activar la división Películas/Series (`splitVod`) en todos los skins predefinidos y
hacer que `moviesLayout` y `seriesLayout` usen exactamente los mismos parámetros que
`vodLayout`, para que las tres pestañas (VOD, Películas, Series) tengan la misma
estructura y aspecto (el filtro por tipo lo aplica ya `VodScreen`).

## Scope

- `lib/core/skin/skin_presets.dart`:
  - `splitVod: true` en `jellyfinDefault`, `disneyPlus`, `amazonPrime`,
    `movistarPlus`, `custom` y `netflix` (ya lo tenían los tres últimos).
  - Extracción del `vodLayout` de Disney, Prime, Custom y Netflix a consts
    `_<skin>Vod` y asignación a `vodLayout`, `moviesLayout` y `seriesLayout`.
  - Se conserva la fila de franquicias en los VOD de Disney y Netflix (se añadió a
    sus consts) para no perderla en la pestaña de películas.
- `lib/features/vod/presentation/vod_screen.dart` (cambio previo relacionado):
  `franchises`/`boxSets` se ocultan en el split de series (son contenido de cine).

## Checklist

- [x] `splitVod: true` en los 6 presets
- [x] `moviesLayout` y `seriesLayout` = `vodLayout` en Disney, Prime, Custom y Netflix
- [x] Franquicias conservadas en los layouts de VOD/películas
- [x] `flutter analyze --no-pub` limpio

## Evidence

- `flutter analyze --no-pub` → `No issues found! (ran in 8.4s)`
- Los cuatro skins con layout usan la misma lista const en los tres campos.

## Next

Probar que VOD, Películas y Series muestran las mismas secciones (cada una filtrada
por tipo) en Disney, Prime, Custom y Netflix. `jellyfinDefault` y `movistarPlus` no
tenían `vodLayout` propio: siguen con el layout legacy del VOD, ya filtrado por split.
