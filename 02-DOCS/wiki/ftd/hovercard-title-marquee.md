# Marquee en el título de la hovercard (Prime)

## Intent
En el panel de la hovercard (extensión estilo Prime), el título debe desplazarse
en marquee si no cabe, cuando la preferencia `titleMarqueeOnHover` del skin está
activada.

## Scope
- In:
  - `hover_play_card.dart`: nuevo `titleMarquee` (HoverPlayCard → _ExpandedHoverCard
    → _HoverPanel). En el panel, el título usa `MarqueeText` (con `isHovered:
    true`, ya que el panel solo se ve en hover) en lugar de `Text` cuando está
    activo.
  - `backdrop_card.dart`/`poster_card.dart`: pasan `titleMarquee: marqueeEnabled`
    (de la preferencia del skin).
- Out: no se cambia el subtítulo ni el resto del panel.

## Checklist
- [x] El título del panel usa marquee si la preferencia está activa.
- [x] Solo se desplaza si desborda (comportamiento de `MarqueeText`).
- [x] `flutter analyze` limpio.

## Evidence
- `hover_play_card.dart`: `_HoverPanel.titleMarquee` → `MarqueeText(text: title,
  style: …, isHovered: true, enabled: true)`; si no, el `Text` con ellipsis.
- `backdrop_card.dart`/`poster_card.dart`: `titleMarquee: marqueeEnabled`, donde
  `marqueeEnabled = skin?.titleMarqueeOnHover ?? false`.
- `MarqueeText` mide el texto y solo anima cuando hay overflow.
- `flutter analyze` → `No issues found!`.

## Next
- Comprobar en Prime: hover en una tarjeta con título largo → el título del panel
  se desplaza; con la preferencia desactivada, se queda con ellipsis.
