# OST ordenada por número del nombre de fichero/título

## Intent
La lista OST no debe ordenarse alfabéticamente ni fiarse del tag `track` de metadatos (muchos rips no lo traen o lo traen mal): el orden lo manda el número que viene en el nombre, p. ej. `01. The Adventure Continues.mp3` es la pista 1. Solo cuando el nombre no trae número se ordena alfabéticamente.

## Scope
- In: nº efectivo por pista (`sortNumber`: número líder del título o del nombre de fichero en `stream_url`, fallback al tag `track`); ordenación en `RommRepository.getSoundtrackTracks` (numeradas primero por número con desempate alfabético, no numeradas después por `displayName` insensible a mayúsculas).
- Out: cambios de UI (la lista ya numera por posición y hereda el orden), renombrados, quitar el `order_by=track` de la query (se deja como pista de fetch; el orden final es cliente), playlists/favoritas.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] `RommSoundtrackTrack.sortNumber` (título → fichero → tag `track`) — `flutter analyze` sin issues
- [x] `getSoundtrackTracks` devuelve la lista ya ordenada — `flutter analyze` sin issues

## Evidence
- Base actual: `getSoundtrackTracks` en `lib/features/games/data/romm_repository.dart:859` pide `order_by=track` y devuelve en orden de servidor; `_fileStem` en `lib/features/games/domain/romm_soundtrack_track.dart:89` ya quita el prefijo numérico para mostrar, pero nada lo usa para ordenar.
- Caso del usuario: `01. The Adventure Continues.mp3` debe salir primera aunque sus metadatos no digan `track: 1`.
- `flutter analyze` (2 ficheros: romm_soundtrack_track, romm_repository) → "No issues found!"

## Next
Probar en runtime con un juego cuyo OST tenga prefijos numéricos en fichero y tags ausentes/incorrectos.
