# Filas de biblioteca: filtrar por tipo en la query

## Intent
Arreglar que una fila `library`/`recent` de Series traiga 3 elementos con 222 series: la query pedía de todo (series+temporadas+capítulos) con `limit: 20` y el colapso posterior dejaba 2-3 series. Filtrar por tipo en la propia query según la colección.

## Scope
- In:
  - Helper de tipos por `CollectionType` (pelis→movie, series→series, música→musicAlbum, libros→book; resto sin filtro).
  - `libraryItemsProvider`, `libraryRowItemsProvider`, `recentLibraryItemsProvider`, `recentRowItemsProvider`: `includeItemTypes` según la vista (vía `userViewsProvider`); se mantiene `collapseSeriesDuplicates` como red de seguridad.
- Out:
  - No cambiar límites ni orden; sin ARB; sin tests (no pedidos) y sin `flutter build` (solo `flutter analyze`).

## Checklist
- [ ] Helper + 4 providers filtrados; comprobar `flutter analyze`.
- [ ] `flutter analyze` sin problemas; demostrar salida.

## Evidence
- `library_providers.dart`: helper `_viewItemTypes` (movies/tvshows/music/books; resto sin filtro) + `includeItemTypes` en `libraryItemsProvider`, `libraryRowItemsProvider`, `recentLibraryItemsProvider` y `recentRowItemsProvider` (tipo resuelto vía `userViewsProvider`); `collapseSeriesDuplicates` se mantiene como red de seguridad. Nota: el `types` del scroll de secciones `library`/`recent` lo ignoraban estos providers; ahora el filtro por vista lo hace efectivo (p. ej. `types: [series]` + vista de series → query de series).
- `flutter analyze` → `No issues found! (ran en 11.9s)`.

## Next
- Probar en app: fila de Series con las 20 primeras series; ver-más intacto.
