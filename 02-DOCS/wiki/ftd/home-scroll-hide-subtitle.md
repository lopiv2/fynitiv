# `HomeScroll.hideSubtitle`: ocultar artista/autor en las tarjetas

## Intent

Añadir un parámetro por scroll para ocultar la línea de subtítulo de las tarjetas
(debajo del título): el **artista** en música, el **autor** en libros/cómics y el
año/géneros en el resto. Complementa `hideTitle` y `hideYear`.

## Scope

- `lib/core/skin/home_scroll.dart`: campo `hideSubtitle` (constructor, `copyWith`,
  JSON, `==`/`hashCode`).
- `lib/features/library/presentation/widgets/poster_card.dart`: nuevo
  `hideSubtitle` que anula el subtítulo calculado (artista/autor/año).
- `lib/features/library/presentation/widgets/content_row.dart`: propaga
  `hideSubtitle` a `PosterCard` y `BackdropCard` (`BackdropCard` ya lo tenía).
- Propagación desde los `HomeScroll` en `home_screen`, `vod_screen`,
  `library_view_screen`, `seasonal_suggestions_row` y `jellyfin_upcoming_row`.
- `custom_skin_section`: conserva `hideSubtitle` al guardar un scroll.

## Checklist

- [x] `HomeScroll.hideSubtitle` (modelo + JSON)
- [x] `PosterCard` y `ContentRow` lo aplican; `BackdropCard` ya lo tenía
- [x] Propagado en todas las filas que usan `HomeScroll`
- [x] Editor de skin conserva el valor
- [x] `flutter analyze --no-pub` limpio

## Evidence

- `flutter analyze --no-pub` → `No issues found! (ran in 21.1s)`

## Next

Usar `hideSubtitle: true` en los scrolls de música/libros que no quieran mostrar
el artista/autor. En presets basta añadirlo al `HomeScroll` correspondiente.
