# FTD: netflix-hero-focus-flow — barra → banner → Play → fila

## Intent
Flujo de foco TV/mando en el hero: barra superior ↓ al banner (nivel intermedio), ←/→ en el banner cambian de Novedad, ↓ a Reproducir, → a Más información, ↓ desde cualquiera de los dos a la fila siguiente.

## Scope
- `tv_focus_nodes.dart`: `tvSliderBannerFocusNode` global (patrón existente).
- `featured_slider.dart`: envolver el Stack del banner en `Focus` con ese nodo solo cuando no hay dots; en el `onKeyEvent` del scope, a nivel banner: ←/→ cambian, ↓ va a Play, ↑ sigue yendo a la barra (rama existente).
- `netflix_top_bar.dart`: `FocusScope` con ↓ al nodo banner (fallback a primera acción y luego a traversal).
- Solo afecta al flujo sin dots (Netflix); otros skins intactos.

## Checklist
- [x] FTD creado antes del cambio
- [x] nodo global banner
- [x] Focus banner + ramas en scope del slider
- [x] ↓ en la topbar Netflix
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (slider + topbar + nodos): `No issues found!`.

## Next
- Probar en TV el flujo completo barra → banner → Play → fila.
