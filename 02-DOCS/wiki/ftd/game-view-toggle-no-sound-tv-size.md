# Toggle 2D/3D sin sonido y más grande en TV

## Intent
En el detalle del juego, el toggle 2D/3D suena al pasar el foco entre segmentos y en TV se ve pequeño. Quitar el sonido de hover/focus en esos dos segmentos y agrandarlos en TV con factor dedicado, manteniendo el tamaño actual en desktop/móvil y el foco por D-pad.

## Scope
- In: `game_box3d_viewer.dart` (`_ViewToggle`): `playSoundOnHover: false` en ambos segmentos; param `isTv` desde `platformModeProvider`; paddings/fuente/radios mayores en TV (20/12, 15sp, radios 10/12, gaps 6/5) y escala 1.08 en TV.
- Out: otros `AppHover` con sonido, cambios de skins/sliders, cadenas ARB (sin texto nuevo), cambios en `AppHover` global o `platform_mode`.

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Sonido off en segmentos 2D/3D (`playSoundOnHover: false`)
- [x] `isTv` cableado desde `platformModeProvider` y factor de tamaño TV aplicado
- [x] Foco D-pad intacto (`trackFocus` por defecto) y `flutter analyze` sin issues

## Evidence
- `flutter analyze lib/features/games/presentation/widgets/game_box3d_viewer.dart` → "No issues found!"
- Implementación: `_ViewToggle` con `isTv` (TV: pads 20/12, fuente 15, radios 10/12, gaps 6/5, escala 1.08; resto: 14/7, 12sp, radios 8/10, gaps 4/3, escala 1.04); ambos `AppHover` con `playSoundOnHover: false`; foco D-pad sin cambios.

## Next
- Confirmación visual del usuario en TV (foco D-pad entre 2D/3D sin sonido y tamaño legible a distancia) y en desktop (tamaño como antes).
