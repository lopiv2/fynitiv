# FTD — Detalle modular fase 1: primitivas + DetailLayout

## Intent

Fase 1 del detalle modular: extraer las primitivas idénticas de
`item_detail_screen.dart` y `book_detail_screen.dart` a
`core/widgets/detail_primitives.dart` sin cambiar ni un píxel, y definir la
config declarativa `DetailLayout` (estilo `HomeScroll`) + resolver
`detailLayoutFor(skin, kind)`. Sin migrar pantallas (fase 2).

## Scope

- NUEVO `lib/core/widgets/detail_primitives.dart`: `DetailInfoCard`,
  `DetailCreditRow`, `DetailLanguageInfo`, `DetailLinkText`, `DetailInfoValue`,
  `DetailTag` + helpers puros `detailPeopleByType`, `detailPeopleNames`,
  `detailDownloadFilename` (código byte-idéntico al actual).
- `item_detail_screen.dart` y `book_detail_screen.dart`: usar las primitivas
  (borrar duplicados privados).
- NUEVO `lib/core/skin/detail_layout.dart`: enums `DetailHeaderStyle`,
  `DetailSection`, clase `DetailLayout` (con `copyWith`), presets por tipo
  (libro/serie/peli/música/persona) + `detailLayoutFor({skin, kind})`.
- Sin cambios visuales, sin ARB nuevas, sin tocar `PrimeCardBadge`, en `main`.

## Checklist

- [x] `detail_primitives.dart` + migrar ambos detalles a usarlo.
- [x] `detail_layout.dart` + resolver por (skin, tipo).
- [x] `flutter analyze` limpio.

## Evidence

- NUEVO `lib/core/widgets/detail_primitives.dart`: `DetailInfoCard`,
  `DetailCreditRow`, `DetailLanguageInfo`, `DetailLinkText`, `DetailInfoValue`,
  `DetailTag` + `detailPeopleByType`, `detailPeopleNames`,
  `detailDownloadFilename` (código idéntico al que había duplicado).
- `item_detail_screen.dart` (-186 líneas) y `book_detail_screen.dart`
  (duplicados eliminados) usan las primitivas; cero cambios visuales.
- NUEVO `lib/core/skin/detail_layout.dart`: `DetailHeaderStyle`,
  `DetailSection`, `DetailLayout` (+`copyWith`), presets por tipo
  (libro/serie/peli/música/persona) y `detailLayoutFor({skin, kind})` con el
  caso especial Disney+ ya existente.
- `dart format` + `flutter analyze` de los 4 ficheros → No issues found.

## Next

- Fase 2: migrar `BookDetailScreen` como piloto al layout modular.
