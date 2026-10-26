# FTD — Detalle modular fase 2: piloto libros

## Intent

Migrar `BookDetailScreen` al sistema modular sin cambiar ni un píxel:
parámetro opcional `skin` (override; por defecto el global), layout resuelto
con `detailLayoutFor(skin, kind)` y composición ordenada por
`layout.sections` con flags `show*`. Paridad visual total; las variantes por
skin llegarán como nuevos builders sobre este cableado.

## Scope

- `book_detail_screen.dart`: `skin` opcional + `layout` + composición por
  secciones con los bloques existentes (`header`, `tabs`, `related`,
  `synopsis+credits` fusionados, `media`/`extras` no-op en libros).
- `detail_layout.dart`: orden del preset de libro = orden real actual
  (`header, tabs, related, synopsis, credits, extras`).
- Sin ARB, sin cambios de ruta, sin tocar `PrimeCardBadge`, en `main`.

## Checklist

- [x] `skin` opcional + layout en `BookDetailScreen`.
- [x] Composición por `layout.sections` con paridad visual.
- [x] Preset de libro con el orden real.
- [x] `flutter analyze` limpio.

## Evidence

- `BookDetailScreen({required item, Skin? skin})`: `effectiveSkin` =
  `widget.skin ?? global`; `layout = detailLayoutFor(skin, kind)`; la cola
  Prime sale de `_primeTail` (tabs/related/info según `sections` + flags;
  `synopsis`+`credits` fusionados, `media`/`extras` no-op en libros).
- Preset libro reordenado al orden real (`header, tabs, related, synopsis,
  credits, extras`) → paridad visual total.
- `dart format` + `flutter analyze` → No issues found.

## Next

- Fase 3 apuntada como pendiente en `detail-modular-fase3-unificada.md`.
