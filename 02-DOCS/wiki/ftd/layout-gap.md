# FTD: layout-gap — espaciador entre secciones del layout

## Intent
Poder añadir hueco vertical entre secciones (`LayoutSection.gap(24)`) en `homeLayout`/`vodLayout`/etc., para separar sliders a demanda (caso Netflix).

## Scope
- `skin_enums.dart`: `LayoutSectionType.gap`.
- `layout_section.dart`: `LayoutSection.gap(height)` + campo `gapHeight` + JSON/`==`/hash.
- home y VOD: en el cálculo de filas el gap no aporta; al construir pinta `SizedBox(height)`. Sin preset por defecto (el usuario lo coloca).
- Editor de skins (custom_skin_section): usa `if`, sin cambios.

## Checklist
- [x] FTD creado antes del cambio
- [x] tipo + modelo + JSON
- [x] render en home y VOD (+movies/series si comparten builder)
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (4 ficheros): `No issues found!` (cubre los 4 `switch` + fromJson).

## Next
- Ninguno; uso: `LayoutSection.gap(24)` entre secciones del preset.
