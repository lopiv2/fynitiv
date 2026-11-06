# FTD: franchise-hover-extension — hover de scrolls en el grid de franquicias

## Intent
Las entradas de la pantalla de franquicia usan `SeerrPosterGrid`/`PosterCard`
sin `hoverExtension`, así que no muestran el panel de extensión Prime que sí
tienen las tarjetas de los scrolls. Exponer el hover universal en el grid
reutilizable y activarlo solo en franquicias.

## Scope
- In:
  - `lib/features/seerr/presentation/widgets/seerr_poster_grid.dart`: nuevos
    parámetros opcionales `hoverExtension` y `hoverScale` (por defecto como
    ahora) propagados a `PosterCard`.
  - `lib/features/franchises/presentation/franchise_screen.dart`: pasar
    `hoverExtension: true` en sus entradas.
- Out: pestañas de Seerr (mantienen el comportamiento actual), hub,
  catálogo, orden y numeración.

## Checklist
- [x] FTD creado antes del cambio.
- [x] Parámetros opcionales en `SeerrPosterGrid`/`SeerrPosterGridEntry`.
- [x] Franquicias con `hoverExtension: true`.
- [x] `flutter analyze` limpio.

## Evidence
- `SeerrPosterGridEntry` acepta `hoverExtension` (defecto `false`) y
  `hoverScale` (defecto `null`); `SeerrPosterGrid` los propaga a `PosterCard`,
  que ya envuelve todo en `HoverPlayCard`. Las pestañas de Seerr no pasan los
  nuevos parámetros, así que mantienen su comportamiento.
- `franchise_screen.dart` pasa `hoverExtension: true` tanto en entradas
  poseídas (acción "Detalles") como en faltantes ("Solicitar").
- `flutter analyze` → `No issues found!`.

## Next
- Verificación visual: hover en una tarjeta de franquicia muestra el mismo
  panel de extensión que en los scrolls. Sin `flutter build`.
