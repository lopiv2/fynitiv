# E-Reader — pantalla de biblioteca (recientes + grid paginado)

## Intent
Implementar la pantalla del E-Reader (antes `FeaturePlaceholder`) como biblioteca de
libros/cómics de Jellyfin: una **fila de recién añadidos** arriba y un **grid paginado**
con todos los libros debajo, con un **skin fijo** propio que no cambia al cambiar el skin
de VOD u otros.

## Scope
- In: `SkinScope` (override de skin por subárbol) + adaptación de widgets compartidos;
  `lib/features/ereader/application/ereader_providers.dart`; `ereader_screen.dart`;
  ocultar "Ver ahora" en el detalle para `Book`; ARB EN+ES.
- Out: lector EPUB/CBZ, progreso de lectura, filtro por tipo de fichero (Jellyfin no lo
  permite en `/Items`), sidebar con skin propio.

## Checklist
- [x] FTD antes del primer cambio
- [x] `SkinScope` (`lib/core/skin/skin_scope.dart`)
- [x] Widgets compartidos prefieren `SkinScope` sobre el skin global
- [x] `eReaderLatestBooksProvider` + `eReaderSkin`
- [x] `EReaderScreen` (recientes + grid paginado)
- [x] Detalle oculta "Ver ahora" en libros
- [x] ARB EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- `SkinScope` consultado en `dashboard_background`, `scroll_title`, `poster_card`,
  `backdrop_card`, `content_row` (altura/spacing/rowSpacing) y `library_grid_card`.
- `eReaderProviders`: `eReaderLatestBooksProvider` (`getItems` book + dateCreated desc),
  `eReaderBooksPageProvider`/`eReaderBooksCountProvider` (reutilizan `libraryFiltered*` con
  `includeItemTypes:[book]`), `eReaderSkin` = `SkinPresets.jellyfinDefault` (fijo).
- `EReaderScreen`: `SkinScope` + `ContentRow` (recién añadidos) + grid `SliverGrid` con
  `PosterCard` + orden A-Z/Z-A + paginación `‹ ›` y `pageOf`.
- `ItemDetailScreen`: "Ver ahora" oculto para `BaseItemKind.book`.
- `flutter gen-l10n` OK; `flutter analyze` → "No issues found!".

## Next
- Probar la pantalla: fila de recientes + grid paginado, skin fijo independiente de VOD.
- Futuro: lector EPUB/CBZ, progreso de lectura, filtro por tipo (cliente).
