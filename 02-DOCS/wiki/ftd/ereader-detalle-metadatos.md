# E-Reader — detalle de libro/cómic: relacionados y metadatos

## Intent
En el detalle de un libro/cómic: (1) que la fila de "Relacionado" muestre solo otros
libros/cómics (nunca canciones ni otros tipos), (2) que no aparezcan "Idiomas de audio" ni
"Subtítulos", y (3) que "Creadores y Reparto" vuelque todos los metadatos del libro
(editorial, autor, ISBN y demás roles) en lugar de los campos de vídeo.

## Scope
- In: `similarItemsProvider` filtra por `BaseItemKind.book` cuando el item es un libro;
  `_RelatedSection` navega al detalle del eReader; `_AdditionalInformation` con bandera
  `isBook` que omite streams y muestra créditos de libro (roles agrupados + editorial +
  ISBN); ARB EN+ES de roles/editorial/ISBN.
- Out: edición de metadatos; otros tipos de detalle; CBR/RAR.

## Checklist
- [x] FTD antes del primer cambio
- [x] Relacionados solo de tipo libro/cómic
- [x] Ocultar idiomas de audio y subtítulos en el detalle de libro
- [x] Creadores y Reparto con todos los roles + editorial + ISBN
- [x] ARB EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- `similarItemsProvider`: para `BaseItemKind.book` usa `includeItemTypes: [book]`, sin filtro
  de géneros, y descarta en cliente cualquier item no-libro.
- `book_detail_screen.dart`: `_AdditionalInformation(isBook: true)` muestra `details` +
  `creatorsAndCast`; roles agrupados por `PersonKind.value` (Author, Illustrator, Penciller,
  Inker, Colorist, Letterer, CoverArtist, Editor, Translator, Artist), Editorial (`studios`)
  e ISBN (`providerIds`/`tags`). Se eliminan las tarjetas de audio/subtítulos para libros.
- `flutter gen-l10n` OK; `flutter analyze` → `No issues found!`.

## Next
- Probar con un libro y un cómic reales: comprobar que el autor aparece como "Autor" y que
  editorial/ISBN salen si Jellyfin los tiene. Si el ISBN no llega en `ProviderIds`, revisar
  de dónde lo expone el servidor.
