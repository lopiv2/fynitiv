# Featured slider: parpadeo del reveal (Prime)

## Intent
En el slider del skin Prime, la descripción que se revela al hacer hover sobre
el logo parpadeaba sin parar cuando el ratón pasaba sobre la propia descripción.
El reveal debe responder solo al logo y mantenerse estable.

## Scope
- In: `lib/features/library/presentation/widgets/featured_slider.dart`,
  `_SliderBannerCardState`: la descripción reserva su espacio siempre que el
  reveal esté activo (`!isTv && _reveal`) y solo se animan opacidad/slide.
- Out: no se cambia el disparador (sigue siendo el `MouseRegion` del logo) ni el
  diseño general.

## Checklist
- [x] La descripción reserva su espacio (no altera el alto de la columna).
- [x] `flutter analyze` limpio.

## Evidence
- Causa: la columna inferior-izquierda está anclada abajo (`Align.bottomLeft`).
  Al aparecer la descripción crecía en alto, empujando el logo hacia arriba; el
  cursor dejaba el `MouseRegion` del logo → `_setHovered(false)` → la descripción
  desaparecía → el logo volvía → bucle enter/exit (parpadeo).
- Fix: la descripción se mantiene en el layout cuando `_reveal` (hover + overview)
  aunque esté invisible; solo se animan `opacity` y `AnimatedSlide`. El alto de la
  columna es constante y el logo (y su `MouseRegion`) no se desplazan, así que
  pasar el ratón por la descripción la oculta de forma estable.
- `flutter analyze` → `No issues found!`.
- Verificado en la app por el usuario: el reveal del logo funciona sin parpadeo
  al pasar el ratón por la descripción.

## Next
- Cerrado. Si en el futuro se quiere eliminar el pequeño hueco reservado en
  reposo, cambiar a la variante "se mantiene mientras el ratón esté sobre el
  logo o la descripción" (sin reservar espacio).
