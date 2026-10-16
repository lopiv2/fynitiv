# Jellyfin — fila "Próximamente" (.disc placeholders)

## Intent
Ofrecer en Home/VOD una fila "Próximamente" con el contenido que Jellyfin conoce pero aún no
tiene media (stubs `.disc` de Radarr/Sonarr: `IsPlaceHolder: true`), configurable desde el
layout (zona Amazon Prime usará Seerr para TMDB upcoming aparte).

## Scope
- In:
  - `LayoutSectionType.upcoming` + `LayoutSection.upcoming([HomeScroll?])`, configurable, no
    activada en presets.
  - Provider Jellyfin que consulta `getItems` y filtra `isPlaceHolder == true`, ordenado por
    `premiereDate` ascendente.
  - Fila reutilizando `ContentRow` con las tarjetas Jellyfin existentes.
  - Sustituye a la fila TMDB "Novedades" que se retira del layout de Home/VOD.
- Out:
  - Peticiones/upcoming de TMDB en Home (viven en Seerr).

## Checklist
- [x] FTD antes del primer cambio (este documento)
- [x] `jellyfinUpcomingProvider`
- [x] `LayoutSectionType.upcoming` (+ json) y quitar `novedades`
- [x] Resolución en `home_screen`/`vod_screen` + no-op en backdrops
- [x] `ItemDetailScreen`: `isPlaceHolder` cuenta como no reproducible
- [x] ARB + `flutter analyze`

## Evidence
- `jellyfin_dart`: `BaseItemDto.isPlaceHolder` (`IsPlaceHolder`), `LocationType.virtual`.
- Stubs `.disc` llegan como `IsPlaceHolder: true` aunque `LocationType` sea `FileSystem`.
- `jellyfinUpcomingProvider` consulta `getItems` (movie+series, `premiereDate` asc) y filtra
  `isPlaceHolder == true`. Sin items → la fila no ocupa espacio.
- `JellyfinUpcomingRow` reutiliza `ContentRow` (cards Jellyfin), con `showPlayIcon: false`.
- Se retiró la antigua sección TMDB `novedades` del layout (el upcoming TMDB vive en Seerr).
- `flutter analyze` → `No issues found!`.

## Exclusión de placeholders de las filas normales
- Los stubs `.disc` se colaban en "Novedades" y otras filas. Ahora se excluyen:
  - `ContentRow` tiene `excludePlaceholders` (por defecto `true`); la fila "Próximamente"
    lo pone a `false`. Cubre todas las filas (Novedades, recientes, biblioteca, custom,
    relacionados, continuar/a continuación).
  - `collapseSeriesDuplicates` filtra placeholders (library/recent/custom rows).
  - `libraryFilteredPageProvider` (grids, incl. AllMovies) y los banners
    (`latestBannerItemsProvider`, `vodLatestBannerProvider`) también excluyen.
- Helper compartido `excludePlaceholders` / `isPlaceholderItem` (por `IsPlaceHolder`,
  ruta `.disc` o media source `Placeholder`).
- Nota: los contadores de paginación (`libraryFilteredCountProvider`) siguen contando
  placeholders; puede quedar una página final desajustada por un item.

## Next
Probar con stubs `.disc` reales en Jellyfin.
