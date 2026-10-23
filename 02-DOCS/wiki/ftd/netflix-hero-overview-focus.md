# FTD: netflix-hero-overview-focus — sinopsis solo con foco/hover

## Intent
En el hero Netflix, la sinopsis (entre la meta de género y los botones) se oculta cuando el slider pierde el foco y el ratón sale, para que se aprecie dónde está el foco. Visible al enfocar o pasar el ratón, como el reveal de Prime.

## Scope
- `featured_slider.dart`: `_SliderBannerCard` recibe `showHeroOverview` del padre (`_sliderFocused || _sliderHovered`, estados que ya existen). Solo se usa en la rama hero; en TV la sinopsis ya estaba oculta.
- Sin cambios para otros skins ni para Prime.

## Checklist
- [x] FTD creado antes del cambio
- [x] param showHeroOverview + condición en rama hero
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (slider): `No issues found!`.

## Next
- Probar con teclado (Tab entra → sinopsis; Tab sale → se esconde) y ratón.
