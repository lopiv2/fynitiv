# Biblioteca: las series abren el detalle (sin botón de reproducir)

## Intent
En el grid de biblioteca, tocar una serie abría el reproductor. Debe abrir la
pantalla de detalle (como en otras secciones) y no mostrar el botón de
reproducir; desde el detalle se eligen temporadas/capítulos.

## Scope
- In:
  - `library_view_screen.dart`: para items de tipo `series`, `onTap` → detalle y
    `showPlayIcon: false` (tanto en `BackdropCard` como en `PosterCard`).
  - `hover_play_card.dart`: `_HoverPanel` oculta el botón "Ver ahora" cuando
    `showPlay` es `false`; se propaga desde `HoverPlayCard.showPlayIcon`
    (reutilizado, sin parámetro nuevo).
- Out: no se cambia el resto de tipos (películas/música siguen reproduciendo) ni
  la pantalla de detalle.

## Checklist
- [x] Series → detalle en el grid de biblioteca.
- [x] Sin botón de reproducir para series (overlay y panel de hover).
- [x] `flutter analyze` limpio.

## Evidence
- `library_view_screen.dart`: `final isSeries = item.type == BaseItemKind.series;`
  controla `onTap` (detalle) y `showPlayIcon` (false).
- `hover_play_card.dart`: `HoverPlayCard.showPlayIcon` → `_ExpandedHoverCard.showPlay`
  → `_HoverPanel.showPlay`; el `WatchNowButton` se omite si `showPlay` es false.
- El detalle (`/home/details/:id`) es el mismo que en otras secciones, así que
  muestra temporadas/capítulos igual.
- `flutter analyze` → `No issues found!`.

## Next
- Corregido después (ver `series-biblioteca-y-detalle-prime.md`): en la
  biblioteca el hover de las series SÍ muestra "Ver ahora" (la tarjeta abre el
  detalle y "Ver ahora" reproduce). El ocultado del botón cuando no hay capítulos
  aplica a la VISTA DE DETALLE, no a la biblioteca. Este documento se mantiene
  solo como registro del primer ajuste.
