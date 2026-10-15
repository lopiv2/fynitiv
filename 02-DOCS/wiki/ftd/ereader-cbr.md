# E-Reader — soporte de cómics CBR (RAR)

## Intent
Abrir los cómics CBR (RAR) en el lector, como los CBZ: extraer las imágenes,
ordenarlas naturalmente y mostrarlas en el lector paginado con flechas.

## Scope
- In:
  - Detección de `.cbr`/`.rar` y enrutado al visor de cómics.
  - Extracción RAR con `another_rar` (Dart puro, sin código nativo).
- Out:
  - CBR con filtros RarVM o compresión RAR5 (ver limitaciones).
  - RAR con contraseña.

## Checklist
- [x] FTD antes del primer cambio
- [x] `ComicView` extrae ZIP (CBZ) y RAR (CBR)
- [x] `BookReaderScreen` enruta `cbr`/`rar` al visor
- [x] `book_format` reconoce `rar` además de `cbr`
- [x] `flutter analyze` limpio

## Evidence
- Librería elegida: `another_rar` (Dart puro; deps `meta`+`universal_io`). API
  `RarArchiveReader.open` → `getArchiveEntries` → `extractEntry`, validada con el
  `SampleRar.rar` del paquete (lista y extrae entradas correctamente).
- `ComicView._extractRar` corre en `Isolate.run`, filtra imágenes (con fallback por firma),
  ordena naturalmente y escribe a un directorio temporal para pintar con `Image.file`.
- `flutter analyze` → `No issues found!`.

## Limitaciones (motivo de esta decisión)
- Se intentó el decodificador nativo oficial UnRAR (`unrar`, FFI + build hooks) para cubrir
  RarVM/RAR5, pero no fue viable sin un coste/basura desproporcionada:
  - `unrar` (pub) falla su build hook en Windows: pasa flags de GCC/Clang a MSVC
    (`cl : error D8021`) y le faltaba `motw.cpp` + libs `advapi32`/`shell32`.
  - Además choca con `flutter_scene` (`hooks ^1` vs `^2`).
  - La vía de vendorizar y parchear el hook de UnRAR se descartó por el alcance.
- Por eso se mantiene `another_rar`: **RAR4 (store/normal) sí**; **filtros RarVM y RAR5
  comprimido no** (esos CBR mostrarán el aviso de formato no soportado).

## Next
Si más adelante se necesitan RAR5-comprimidos/RarVM, evaluarlo como trabajo aparte con
presupuesto (vendorizar UnRAR con hook MSVC corregido, o vía nativa en Android/desktop).
