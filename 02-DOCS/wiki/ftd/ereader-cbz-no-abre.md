# E-Reader — los CBZ no los abre el lector

## Intent
El lector no abre los cómics CBZ. Se endurece la detección de formato y el visor de
cómics para que los CBZ se abran de forma fiable y sin agotar memoria.

## Scope
- In:
  - `bookFormatOf`: la extensión real del fichero manda sobre el `Container` de Jellyfin.
  - `ComicView`: decodificación en streaming y extracción a disco (`Image.file`), filtro
    de imágenes más amplio, detección por firma (magic bytes) y salto de entradas corruptas.
- Out: soporte CBR/RAR (sigue mostrando "formato no soportado").

## Checklist
- [x] FTD antes del primer cambio
- [x] `bookFormatOf` prioriza la extensión del fichero
- [x] `ComicView` con `decodeStream`/`OutputFileStream` + `Image.file`
- [x] Detección por extensión + fallback por firma; se saltan entradas que fallan
- [x] `flutter analyze` limpio

## Evidence
- Decodificación verificada con `ZipDecoder().decodeBytes` sobre zips de prueba
  (PowerShell `Compress-Archive`, con subcarpeta, `ComicInfo.xml` y extensión `.JPG`):
  los `ArchiveFile.content` devuelven `Uint8List` con bytes válidos — el decode no era el
  fallo.
- `jellyfin_dart.getFile` usa `Options(responseType: ResponseType.bytes)`, así que la
  descarga tampoco depende del content-type.
- Cambios:
  - `bookFormatOf`: antes devolvía el `Container` si era un formato conocido, aunque no
    coincidiera con el fichero real descargado (p. ej. `cbr`/`zip` para un `.cbz`), lo que
    hacía caer el dispatch en el caso por defecto ("formato no soportado"). Ahora la
    extensión conocida gana; el `Container` es solo respaldo cuando no hay ruta.
  - `ComicView`: cargaba el CBZ entero (`readAsBytes` + `decodeBytes`) y descomprimía
    **todas** las páginas a memoria (`List<Uint8List>`), lo que en cómics grandes puede
    agotar la RAM y dejar la pantalla en blanco. Ahora usa `ZipDecoder().decodeStream(
    InputFileStream)` y `entry.writeContent(OutputFileStream)` para extraer a un directorio
    temporal, y pinta con `Image.file` (decodificación bajo demanda y cacheada por Flutter).
  - Filtro: además de `.jpg/.jpeg/.png/.webp/.gif/.bmp` se aceptan `.jfif/.tif/.tiff/
    .avif/.jxl`, se ignora `__MACOSX`, y si no hay coincidencias por extensión se detecta
    por firma de bytes (JPEG/PNG/GIF/BMP/WEBP/ISO-BMFF).
- Verificado el nuevo flujo con un script temporal: `decodeStream` + `OutputFileStream`
  extrae las páginas correctamente (bytes escritos coinciden con el tamaño declarado).
- `flutter analyze` → `No issues found!`.

## Next
Probar con un CBZ real grande: debe abrir al instante y pasar páginas con el curl sin
consumir toda la RAM. Si algún cómic concreto falla, revisar el `debugPrint('[ComicView]')`
para ver la entrada concreta. CBR/RAR ya está cubierto en `ereader-cbr.md`.
