# FTD: netflix-hero-button-focus — foco visible en Más información

## Intent
Que el foco en las píldoras del hero (sobre todo Más información, gris translúcida donde la escala apenas se aprecia) sea inequívoco: escala + anillo blanco.

## Scope
- `featured_slider.dart`: `_NetflixHeroButton` pasa de `AppHoverEffect.scale` a `scaleHighlightOutline` (radio estadio). Sin tocar navegación ni otros skins.

## Checklist
- [x] FTD creado antes del cambio
- [x] efecto en píldoras hero
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (slider): `No issues found!`.

## Next
- Probar en TV: anillo blanco en Play y Más info.
