# Marquee en PosterCard (hover)

## Intent
El marquee del título no se activaba en las tarjetas de póster aunque el ajuste
`titleMarqueeOnHover` estuviera activo y el texto desbordara; en las backdrop sí
funcionaba. Alinear la señal de hover del marquee con la que ya funciona en la
propia tarjeta (el borde de hover).

## Scope
- In: `lib/features/library/presentation/widgets/poster_card.dart`, el
  `MarqueeText` del título: usar `isImageHovered` en lugar de `_isHovered`.
- Out: no se toca `backdrop_card.dart` (ya funcionaba), ni el widget
  `MarqueeText`, ni el resto de la tarjeta.

## Checklist
- [x] El marquee usa la misma señal de hover que el borde (`isImageHovered`).
- [x] `flutter analyze` limpio.

## Evidence
- `poster_card.dart`: el borde de hover ya usaba `isImageHovered`
  (`_isHovered || AppHoverScope.hovered`) y el marquee usaba solo `_isHovered`;
  ahora ambos usan `isImageHovered`, que incluye el scope universal de hover.
- `flutter analyze` → `No issues found!`.

## Next
- Confirmar en la app: hover sobre una tarjeta de póster con título que
  desborde (con la preferencia activada) y comprobar que se desplaza. Si no,
  revisar si el hover llega a la tarjeta (¿se resalta el borde?) para descartar
  que el problema sea de hit-test y no del marquee.
