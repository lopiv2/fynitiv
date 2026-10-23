# FTD: netflix-slider-flag — el billboard no aparece en el skin Netflix

## Intent
Que el `FeaturedSlider` aparezca en Inicio, VOD, Películas y Series con el skin Netflix, como ya declaran sus layouts.

## Scope
- Causa: `home_screen.dart` y `vod_screen.dart` solo pintan el slider si `skin.showNewReleasesBanner == true`; el preset `netflix` no lo definía (defecto `false`). Solo 2 presets lo activan.
- Fix: `showNewReleasesBanner: true` en el preset `netflix` (`skin_presets.dart`). Sin tocar lógica de pintado ni otros skins.

## Checklist
- [x] FTD creado antes del cambio
- [x] flag en preset netflix
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (preset): `No issues found!`.
- Causa verificada: `showNewReleasesBanner` solo estaba en 2 presets; home/VOD/movies/series lo exigen para pintar el slider.

## Next
- Verificar visualmente en Windows (home + películas con skin Netflix).
