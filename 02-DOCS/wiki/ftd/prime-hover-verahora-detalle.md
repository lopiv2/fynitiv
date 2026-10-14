# Prime: "Ver ahora" del hover abre el detalle (salvo Reanudar)

## Intent
En el skin de Prime, el botón del panel de hover ("Ver ahora") debe abrir la
pantalla de detalle en todos los sitios; la única excepción es "Reanudar" (items
con progreso, p. ej. Seguir viendo), que reproduce/reanuda.

## Scope
- In:
  - `hover_play_card.dart`: se vuelve a exponer `onCardTap` (tap del cuerpo de la
    tarjeta), separado de `onPlay` (botón del panel / overlay).
  - `backdrop_card.dart`/`poster_card.dart`: para Prime, `onPlay` = detalle
    (`onImageTap`) cuando el item **no** tiene progreso, y reproduce (`onTap`)
    cuando sí; `onCardTap: onTap` (el tap de la tarjeta no cambia).
- Out: no cambia el comportamiento en otros skins ni el resto del panel.

## Checklist
- [x] Prime: hover "Ver ahora" → detalle.
- [x] Prime: hover "Reanudar" (con progreso) → reproduce.
- [x] Otros skins sin cambios.
- [x] `flutter analyze` limpio.

## Evidence
- `backdrop_card.dart`/`poster_card.dart`: `onPlay` se resuelve como
  `(skin.id == 'amazon_prime' && sin progreso) ? onImageTap : onTap`, y se pasa
  `onCardTap: onTap`.
- `HoverPlayCard`: `onCardTap` (cuerpo) con fallback a `onPlay`; el botón del
  panel usa `onPlay`.
- `onImageTap` es la acción de "detalle" en toda la app (filas, VOD, biblioteca).
- `flutter analyze` → `No issues found!`.

## Next
- Comprobar en Prime: hover en filas/VOD/biblioteca → "Ver ahora" abre detalle;
  en "Seguir viendo" con progreso → "Reanudar" reproduce.
