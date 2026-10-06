# E-Reader — lector paginado a doble página (CBZ + EPUB)

## Intent
Los CBZ no se estaban mostrando con el lector esperado: el usuario quiere un lector tipo
libro con **una página a la izquierda y otra a la derecha**, **flechas laterales** para pasar
de página (siguiente/anterior) y el **mismo comportamiento en el modo de lectura de EPUB**.

## Scope
- In: widget genérico reutilizable `SpreadReader` (doble página en ancho, una sola en
  estrecho; flechas izquierda/derecha; contador; teclado/televisor); `ComicView` alimenta
  el widget con las imágenes del CBZ; `EpubView` divide el texto en páginas según el tamaño
  real de la página y lo muestra en el mismo `SpreadReader`; tooltips ARB EN+ES.
- Out: CBR/RAR; animación de volteo realista; progreso de lectura persistente; zoom global.

## Checklist
- [x] FTD antes del primer cambio
- [x] `SpreadReader` genérico (`spread_reader.dart`)
- [x] `ComicView` usa `SpreadReader` (2 imágenes por pliego, flechas, contador)
- [x] `EpubView` paginiza bloques (texto por líneas + imágenes) y usa `SpreadReader`
- [x] Detección de formato robusta (container/path) en `BookReaderScreen`
- [x] ARB `eReaderPreviousPage` / `eReaderNextPage` + `flutter gen-l10n`
- [x] Cada página EPUB se ve completa, sin barras de scroll
- [x] `flutter analyze` limpio

## Evidence
- `flutter gen-l10n` OK (aviso informativo de l10n.yaml, sin errores).
- `flutter analyze` → `No issues found!` (tras corregir type-check innecesario en `ComicView`).
- Diseño: `SpreadReader` usa `PageView` de *pliegos*; en ancho >=900 px cada pliego muestra
  dos páginas (`2i` izquierda, `2i+1` derecha) y en estrecho una sola; flechas laterales
  deshabilitadas en los extremos, contador `pageOf`, y flechas de teclado/D-pad vía
  `CallbackShortcuts` + `Focus(autofocus)`.
- `EpubView` mide cada bloque con `TextPainter` (mismo `TextScaler` que el render) y reparte
  líneas/imágenes en páginas que caben en `readerPageSize(...)`, cacheando por tamaño.
- Ajuste "sin scroll": el corte de línea ya no deja `bottomGap` en el fragmento partido y
  se elimina la tolerancia de 0,5 px al encajar; `_PageColumn` deja de ser un scroll
  (`OverflowBox`+`ClipRect`) y las imágenes se limitan a la altura de página. `SpreadReader`
  usa un `ScrollBehavior` sin barra para que el `PageView` tampoco muestre scrollbar.
- Ajuste "sin corte abajo": cuando en el hueco restante no cabe ni una línea completa, se
  cierra la página y el bloque pasa a la siguiente (antes se forzaba la primera línea y se
  recortaba); la medición descuenta el `indent` de listas.

## Next
- Probar con un CBZ, un EPUB y un PDF reales; ajustar punto de corte de doble página y
  espaciados de paginación si el texto se solapa. CBR/RAR sigue pendiente.

