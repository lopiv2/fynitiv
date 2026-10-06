# E-Reader — metadatos del EPUB (autor/editorial/ISBN)

## Intent
Al abrir el detalle de un EPUB, mostrar sus metadatos (autor, editorial, ISBN, etc.).
Jellyfin lee el OPF interno del EPUB, pero si no los tiene poblados (no se refrescaron,
EPUB sin metadatos indexados, etc.) el detalle aparecía sin créditos. Se añade un respaldo
que lee los metadatos directamente del fichero.

## Scope
- In: parser OPF (Dublin Core) reutilizable; proveedor que descarga el EPUB y extrae
  autor/editorial/ISBN; el detalle usa el respaldo solo si al servidor le falta algo y
  muestra el loader mientras descarga; helper de formato compartido.
- Out: editar metadatos en el servidor; CBR/RAR; otros formatos distintos de EPUB.

## Checklist
- [x] FTD antes del primer cambio
- [x] `bookFormatOf` compartido (`data/book_format.dart`)
- [x] Parser `parseEpubMetadata` (`data/epub_metadata.dart`)
- [x] `epubMetadataProvider` (descarga + parse, loader)
- [x] Detalle de libro fusiona metadatos del servidor y del fichero
- [x] `BookReaderScreen` reutiliza `bookFormatOf`
- [x] `flutter analyze` limpio

## Evidence
- `parseEpubMetadata`: descomprime, localiza `META-INF/container.xml` → `full-path` del OPF
  (fallback: primer `.opf`), y lee `dc:title`, `dc:creator`/`dc:contributor`,
  `dc:publisher`, `dc:identifier` (ISBN-10/13 normalizado), `dc:language`, `dc:date`,
  `dc:description`, `dc:subject` por nombre local (tolera prefijos `dc:`).
- `epubMetadataProvider(itemId)` descarga con `getLibraryApi().getFile` y parsea; el detalle
  solo lo observa si al servidor le falta autor, editorial o ISBN, mostrando `AppLoader`.
- `flutter analyze` → `No issues found!`.

## Next
- Probar con un EPUB sin metadatos en Jellyfin: debe mostrar "Autor"/"Editorial"/"ISBN" del
  OPF. Si el servidor ya los tiene, no se descarga nada. Valorar respaldo equivalente para
  CBZ (`ComicInfo.xml`) si hiciera falta.
