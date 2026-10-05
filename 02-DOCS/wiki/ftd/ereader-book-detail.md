# E-Reader — pantalla de detalle de libro (clon)

## Intent
Los libros/cómics no pueden usar el detalle de películas/series. Se crea una pantalla
**clon** de `ItemDetailScreen` (`BookDetailScreen`) con acciones propias: sin "Ver trailer",
sin "Más opciones para disfrutar", y con un botón **"Leer"** en lugar de "Continuar sin
anuncios". El lector real llegará después.

## Scope
- In: copia de `item_detail_screen.dart` → `lib/features/ereader/presentation/book_detail_screen.dart`
  renombrando la clase a `BookDetailScreen`; ajuste de imports; `_DetailActions` sin trailer,
  sin "más opciones" y con "Leer"; ruta `/ereader/details/:itemId`; el grid del E-Reader
  navega a esa ruta; ARB `eReaderRead`.
- Out: lector EPUB/CBZ real; otros ajustes de layout del detalle.

## Checklist
- [x] FTD antes del primer cambio
- [x] Clon `BookDetailScreen` (imports + rename)
- [x] `_DetailActions`: quitar trailer, quitar "más opciones", botón "Leer"
- [x] Ruta `/ereader/details/:itemId` + navegación desde el grid
- [x] ARB `eReaderRead` EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- Copia de `item_detail_screen.dart` → `lib/features/ereader/presentation/book_detail_screen.dart`;
  clase renombrada a `BookDetailScreen`; imports intra-library ajustados; import de
  `ad_free_easter_egg_dialog` eliminado (ya no se usa).
- `_DetailActions` del clon: fila solo con [favorito, descargar]; botón ancho **"Leer"**
  (`Icons.menu_book_outlined`, primario, `onTap` pendiente del lector); sin trailer, sin
  "más opciones para disfrutar".
- Ruta `/ereader/details/:itemId` en la rama del E-Reader; el grid navega ahí.
- ARB `eReaderRead` ("Leer"/"Read"); `flutter gen-l10n` OK; `flutter analyze` → "No issues
  found!".
- Cabecera (2026-10-05): si el libro no tiene **backdrop** (habitual), se usa la imagen
  **primaria (portada)** como cabecera; antes `itemBackdropUrl` devolvía una URL sin tag
  (404) y no se veía nada.
- Limpieza (2026-10-05): eliminados del clon todos los métodos/campos del **theme**
  (`_maybeStartTheme`, listen/read de `itemThemeProvider`, `ItemThemePlayer`, `_ItemThemeChip`)
  y del **trailer** (`_openTrailer`/`_closeTrailer`, `_trailer*`, `_TrailerPanel`, overlays y
  cierre, `onTrailer` en `_DetailActions`/`_CompactDetailBody`), más imports de `media_kit`,
  `media_kit_video`, `mpv_teardown` y `WidgetsBindingObserver`. `playback_provider` se
  mantiene (lo usa `_downloadItem`). `flutter analyze` → "No issues found!".

## Next
- Probar: abrir un libro desde el E-Reader → detalle custom con botón "Leer".
- Futuro: acción real de "Leer" (lector EPUB/CBZ); valorar si el detalle debe usar el skin
  fijo del E-Reader (`SkinScope`).
