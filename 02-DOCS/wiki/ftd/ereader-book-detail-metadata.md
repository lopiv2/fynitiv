# FTD — Todos los metadatos en detalle de libro/cómic

## Intent

El detalle del libro/cómic solo vuelca `people` del servidor (o autores del
OPF si no hay `people`): si el servidor viene pobre no se ve dibujante,
serie, idioma, etc. Completar con todo lo disponible: `artists` del servidor,
serie (`seriesName`), serie/nº/autores/género/editorial del OPF (EPUB) y de
`ComicInfo.xml` (CBZ/CB7/CBT/CBR), idioma y fecha del OPF, y géneros
embebidos si el servidor no trae.

## Scope

- `ereader_providers.dart`: nuevo `comicMetadataProvider` (familia por itemId,
  descarga + `parseComicInfoFromZip/Rar`, patrón de `epubMetadataProvider`).
- `comic_info.dart`: añadir `publisher` (`Publisher` de ComicInfo.xml).
- `book_detail_screen.dart`: `needsFileMetadata` también para cómics; nuevas
  filas Serie (servidor/embebida + nº), Autores (servidor `artists` + OPF +
  ComicInfo), Editorial (+ ComicInfo), ISBN, Idioma (`language`, reutilizada),
  fecha OPF si no hay año, géneros embebidos si no hay del servidor.
- ARB ES+EN: clave nueva `eReaderSeries` ("Serie"/"Series") + `gen-l10n`
  (resto de etiquetas ya existen: roles, editorial, ISBN, idioma...).
- Sin tocar `PrimeCardBadge`, todo sobre `main`.

## Checklist

- [x] `publisher` en `ComicMetadata` + `comicMetadataProvider`.
- [x] Filas de metadatos completas en el detalle.
- [x] ARB `eReaderSeries` ES+EN + `gen-l10n`.
- [x] `flutter analyze` limpio.

## Evidence

- `comicMetadataProvider` (familia por itemId): descarga + `parseComicInfoFromZip`
  (ZIP por firma `PK`) o `parseComicInfoFromRar`; `publisher` añadido a
  `ComicMetadata`.
- Detalle libro: fila Serie (`seriesName` o embebida + nº `#N`,
  `eReaderSeries` nueva ES/EN), Autores (`people` por rol, o `artists`, OPF,
  ComicInfo), Editorial (studios/OPF/ComicInfo), ISBN, Idioma (`language`
  reutilizada, del OPF), fecha OPF si no hay año, géneros embebidos si el
  servidor no trae.
- `flutter gen-l10n` generó `eReaderSeries`; `dart format` +
  `flutter analyze lib/features/ereader lib/l10n` → No issues found.

## Next

- Revisar visualmente el detalle con un EPUB con Calibre y un CBZ con ComicInfo.
