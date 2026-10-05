# E-Reader — lector básico (PDF / EPUB / CBZ; CBR pendiente)

## Intent
Al pulsar "Leer" en el detalle de un libro, abrir un lector básico que soporte PDF, EPUB y
CBZ (CBR en una fase posterior). El fichero se descarga de Jellyfin autenticado
(`GET /Items/{id}/File`) y se muestra con el visor adecuado.

## Scope
- In: ruta `/ereader/read/:itemId`; descarga del fichero a caché; detección de formato;
  visores `pdfrx` (PDF), EPUB propio (`archive`+`xml`+`html`, render propio) y cómic CBZ
  (`archive`+`PageView`); botón "Leer" del detalle; ARB.
- Out: CBR/RAR; animación de paso de página; TOC/navegación avanzada; progreso de lectura.

## Decisión de dependencias
- PDF: `pdfrx` (PDFium, Windows+Android). `printing`/`pdf` no son viables (exigen
  `archive <4.1`/`image ^3`, en conflicto con el proyecto).
- EPUB: `epub_view`/`epubx` **no son compatibles** (`image ^3` vs `media_kit` `image ^4`).
  Se monta un lector EPUB básico con `archive` (unzip) + `xml` (OPF) + `html` + `flutter_html`.
- CBZ: `archive` (ya presente).

## Checklist
- [x] FTD antes del primer cambio
- [x] Deps `pdfrx`, `flutter_html`, `xml`, `path`
- [x] `BookReaderScreen` (descarga + dispatch por formato)
- [x] Visor PDF (`pdfrx`)
- [x] Visor EPUB básico (unzip + parse OPF + render capítulos)
- [x] Visor CBZ (zip → imágenes ordenadas → PageView)
- [x] Botón "Leer" navega a `/ereader/read/:itemId`
- [x] ARB EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- Conflictos de resolución registrados (`epub_view`/`epubx` → `image ^3` vs `media_kit`;
  `printing`/`pdf` → `archive <4.1`). `flutter pub add pdfrx flutter_html xml path` OK.
- **`flutter_html 3.0.0` descartado**: rompía el build (`styled_element.dart: Method not
  found: 'matches'`, incompatible con `html`/`csslib` actuales). Se renderiza el EPUB a mano
  con el paquete `html`: se recorre el DOM de cada capítulo y se emiten bloques (títulos,
  párrafos, listas, imágenes). Deps finales: `pdfrx`, `xml`, `path` (+ `archive` existente).
- `BookReaderScreen`: descarga con `getLibraryApi().getFile(itemId:)` a `getTemporaryDirectory()`
  y dispatch pdf/epub/cbz. `EpubView` extrae el zip, parsea `META-INF/container.xml` + OPF con
  `xml` y renderiza los capítulos. `ComicView` descomprime y ordena naturalmente. Botón
  "Leer" → `/ereader/read/:itemId`.
- `flutter gen-l10n` OK; `flutter analyze` → "No issues found!".
- Nota build: **pdfrx en Windows requiere activar Developer Mode** (symlinks) al compilar.

## Next
- Probar con un PDF, un EPUB y un CBZ reales. CBR/RAR después (necesita extractor por
  plataforma). Futuro: animación de paso de página tipo libro.
