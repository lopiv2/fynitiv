# Tamaño en disco en el detalle del juego

## Intent
La ficha del detalle no muestra cuánto ocupa el juego. RomM envía `fs_size_bytes` por ROM: mapearlo y añadirlo como stat en `_GameHeroInfo` con formato legible (B/KB/MB/GB/TB).

## Scope
- In: `RommGame.fsSizeBytes` + mapeo en `_mapGame`; `formatBytes` compartido en `lib/core/utils/format_bytes.dart` (reusa la lógica de `game_list_screen.dart`, que pasa a usarlo); 5º `_Stat` en `_GameHeroInfo` con `l10n.platformOnDisk` reutilizada ("En disco"/"On disk", sin claves ARB nuevas).
- Out: resto de la ficha, cards/lista, cambios ARB (se reutiliza cadena existente).

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] `fsSizeBytes` en `RommGame` (+ `copyWith`) y mapeo en `_mapGame`
- [x] `formatBytes` compartido + refactor de `game_list_screen.dart` + stat en detalle
- [x] `flutter analyze` sin issues en los ficheros tocados

## Evidence
- `RomSchema` (master RomM, `backend/endpoints/responses/rom.py`): `Rom` expone `fs_size_bytes`; el detalle (`GET /api/roms/{id}`) lo incluye.
- Formato ya validado en `game_list_screen.dart::_formatBytes` (plataformas); etiqueta `platformOnDisk` existe en EN+ES.

- Implementación: 5º `_Stat` tras Plataforma con `l10n.platformOnDisk`; `flutter analyze` en los 5 ficheros → "No issues found!".

## Next
Confirmación visual del usuario en el detalle (p. ej. Monkey Island 2).
