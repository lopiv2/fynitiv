# OST sin etiquetas: usar el nombre del fichero

## Intent
En el OST de Loom (FM-Towns) las pistas salen como "Track" con subtítulo del juego: sus ficheros no traen etiquetas (`title`/`artist` null en la Music API) y `displayName` cae al fallback genérico. Usar el nombre del fichero de `stream_url` como nombre visible cuando no haya etiqueta.

## Scope
- In: `RommSoundtrackTrack.displayName` en `romm_soundtrack_track.dart` — fallback intermedio: stem del fichero (URL-decodificado, sin extensión, `_` → espacio, sin prefijo `NN - ` porque la lista ya numera); `Track N`/`Track` quedan como último recurso.
- Out: cambios en UI/lista OST, etiquetas del servidor, otros providers, cadenas ARB (sin texto nuevo).

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Fallback a stem del fichero en `displayName`
- [x] `flutter analyze` sin issues en el fichero tocado

## Evidence
- `flutter analyze lib/features/games/domain/romm_soundtrack_track.dart` → "No issues found!"
- Implementación: `displayName` prueba etiqueta → `_fileStem(streamUrl)` (decode, sin extensión, `_`→espacio, sin prefijo `NN - `) → `Track N` → `Track`.

## Next
- Confirmación del usuario en el OST de Loom (nombres de fichero visibles en vez de "Track").
