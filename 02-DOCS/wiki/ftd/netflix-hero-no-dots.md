# FTD: netflix-hero-no-dots — slider sin puntos, estilo Netflix 2026

## Intent
Que el billboard pueda ir sin puntos de navegación (como la UI de Netflix 2026): avance automático como ahora + cambio de banner con ←/→ del mando en los bordes de los botones. Parámetro por skin, sin afectar al resto.

## Scope
- `lib/core/skin/skin.dart`: `bannerShowDots` (defecto `true`) + copyWith/JSON.
- `FeaturedSlider.showDots` (defecto `true`); home y VOD lo alimentan del skin.
- Sin dots: no se pintan (dentro ni fuera), ↓ desde acciones baja a la siguiente fila, ←/→ en los bordes cambian de banner (`_goToPrev/_goToNext`). Autoplay intacto.
- Preset `netflix`: `bannerShowDots: false`.
- No se toca: autoplay, trailer lateral, resto de skins (dots por defecto).

## Checklist
- [x] FTD creado antes del cambio
- [x] campo en Skin + copyWith + JSON (defecto true)
- [x] param showDots en slider + home/VOD
- [x] foco TV: abajo a filas, bordes cambian banner
- [x] preset netflix sin dots
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (skin + presets + slider + home + VOD): `No issues found!`.

## Next
- Probar en TV/mando: autoplay, ←/→ en bordes, ↓ a Continuar viendo.
