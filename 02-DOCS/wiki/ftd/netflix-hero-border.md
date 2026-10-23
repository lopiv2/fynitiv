# FTD: netflix-hero-border — el borde no aparece aunque hay grosor y color

## Intent
Que el borde del billboard Netflix se vea con el grosor (20) y color (blanco) que el usuario puso a mano en el preset.

## Scope
- Causa: `FeaturedSlider.showBorder` viene de `skin.bannerBorder` (defecto `false`); el grosor y el color solo aplican si el flag es `true` (`skin.dart`: "Solo si [bannerBorder] es true"). El preset Netflix tenía width+color pero no el flag.
- Fix: añadir `bannerBorder: true` en el preset `netflix`, sin tocar los valores puestos a mano por el usuario (width 20, color).
- Nota: con grosor 20, la mitad exterior la recorta el `ClipRRect` del banner; se verá como ~10px interiores. Si se quiere el borde completo por fuera, avisar (cambio de layout).

## Checklist
- [x] FTD creado antes del cambio
- [x] flag `bannerBorder: true` en preset netflix (valores del usuario intactos)
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (preset): `No issues found!`.

## Next
- Captura en Windows; ajustar grosor si 20 resulta excesivo.
