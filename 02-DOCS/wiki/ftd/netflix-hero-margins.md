# FTD: netflix-hero-margins — billboard con laterales, radio y barra fija

## Intent
Que el billboard Netflix tenga padding lateral, bordes redondeados marcados y la barra superior fija arriba con el banner debajo (con hueco), como pide el diseño.

## Scope
- Solo preset `netflix` en `skin_presets.dart`: `bannerHorizontalPadding: 24`, `bannerBorderRadius: 12`, `bannerAttachedTop: false` (esto último da el hueco de 54 bajo la barra fija en home/VOD).
- Sin cambios de lógica: el slider ya aplica `horizontalPadding` y `bannerBorderRadius`; la barra fija ya es la actual (`topBarFloating: false`).

## Checklist
- [x] FTD creado antes del cambio
- [x] preset: padding 24 + radio 12 + detached top
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (preset): `No issues found!`.
- El slider ya aplicaba `horizontalPadding` y `bannerBorderRadius` en home y VOD; solo faltaba el preset.

## Next
- Captura en Windows (home Netflix) y ajustar 24/12 si se quiere más/menos aire.
