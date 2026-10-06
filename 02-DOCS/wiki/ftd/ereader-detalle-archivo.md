# E-Reader — detalle: nombre y tamaño del archivo

## Intent
Mostrar en el detalle de un libro/cómic el **nombre del fichero con su tipo** y el **tamaño
que ocupa**. En Jellyfin esa info vive en `MediaSources` (`Size`, `Path`), que solo se
devuelve si se piden esos `fields`.

## Scope
- In: proveedor que consulta el item por id con `fields: [mediaSources, path]`; helper
  `bookFileInfoOf` (nombre con extensión + tamaño); fila "Archivo/Tamaño" en la tarjeta de
  detalles; ARB EN+ES.
- Out: formatear/editar el fichero; otros formatos.

## Checklist
- [x] FTD antes del primer cambio
- [x] `BookFileInfo` + `bookFileInfoOf` (`data/book_format.dart`)
- [x] `bookFileInfoProvider` (pide `mediaSources`/`path`)
- [x] Fila Archivo/Tamaño en el detalle (con fallback inmediato del item)
- [x] ARB EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- El tamaño (`Size`) y la ruta (`Path`) llegan en `MediaSources`; sin pedirlos en `fields` no
  vienen. Por eso `bookFileInfoProvider` usa `getItems(ids: [itemId], fields: [...])`.
- Se muestra de inmediato un nombre derivado del item (nombre + formato) y se sustituye por
  la info exacta del servidor cuando resuelve la petición.
- `flutter analyze` → `No issues found!`.

## Next
- Probar con un libro y un cómic: debe aparecer "Archivo" (p. ej. `Libro.epub`) y "Tamaño"
  (p. ej. `1.24 MB`). Si el servidor no devuelve `MediaSources`, el tamaño quedará oculto.
