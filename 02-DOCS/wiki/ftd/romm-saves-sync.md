# Intent
Sincronizar **partidas y estados** (saves/states) en dos direcciones entre el cliente y RomM (Device Sync Protocol), con resolución **conservadora** de conflictos (conservar ambas, sin sobrescribir). Cierra la Fase 2 del plan de juego local RomM.

# Scope
- In: `RommSyncController`/`rommSyncProvider`; métodos de repositorio `negotiateSync`/`uploadSave`/`completeSyncSession`; mapeo local `rom_id` ↔ partidas mediante `.fynitiv.meta` por juego; escaneo de `saves/` y `states/`; UI "Sincronizar partidas" (manual) + sync automático al cerrar la sesión de juego; ARB EN+ES.
- Out: PlaySessionTracker (T008); subida de BIOS (fase posterior de `romm-bios-sync`); partidas de ScummVM (guardan en su ruta propia, no en `saves/`); resolución interactiva de conflictos; play_sessions en el `complete` (se envía lista vacía).

# Checklist
- [x] `RommRepository.negotiateSync` / `uploadSave` / `completeSyncSession`
- [x] `LocalGameStore`: `.fynitiv.meta` (write/read) + `listGameMetas` + `listFiles`
- [x] Escribir meta al lanzar (romId, platformSlug, name, playable, stem) en `LocalPlayController._launch`
- [x] `RommSyncController`: escaneo, mapeo por stem (omite stems ambiguos), sha1+mtime, negotiate, ejecución, keep-both, complete
- [x] UI `_SavesSyncCard` en `games_panel`
- [x] Sync automático al cerrar la sesión (`romm_providers.dart`, `exit.then`)
- [x] ARB EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

# Evidence
- Protocolo confirmado (docs RomM): `POST /api/sync/negotiate {device_id, roms:[{rom_id, saves:[{file, mtime, sha1}]}]}` → `{session_id, operations:[{type: upload|download|conflict|noop, rom_id, file, source?, destination?, resolution?}]}`; `POST /api/sync/sessions/{id}/complete`.
- Subida confirmada en código RomM (`backend/endpoints/saves.py`): `POST /api/saves` con query `rom_id`, `device_id`, `session_id` y multipart field **`saveFile`**. Descarga: `GET {source}` (p. ej. `/api/saves/{id}/content`).
- `crypto` ya era dependencia directa (sha1).
- Implementación 2026-10-03:
  - `romm_repository.dart`: `negotiateSync`, `uploadSave`, `completeSyncSession`.
  - `local_game_store.dart`: `.fynitiv.meta` + `listGameMetas` + `listFiles`.
  - `romm_providers.dart`: escribe meta al lanzar; `_playableStem`; sync automático al cerrar sesión.
  - `romm_sync_controller.dart` (nuevo): motor completo.
  - `games_panel.dart`: card `_SavesSyncCard`.
  - ARB: `rommSyncTitle/Help/Button/Running/Done/UpToDate/Error/Login`.
- Verificación: `flutter gen-l10n` OK; `flutter analyze` → "No issues found!".

# Next (PENDIENTE — 2026-10-03)
1. **Verificación manual real**: RomM 5.x + 2º dispositivo. Probar subida, bajada y conflicto keep-both. Necesita **lanzar un juego al menos una vez** con este build para generar `.fynitiv.meta`.
2. **Backfill de `.fynitiv.meta`**: los juegos ya descargados antes de este build no tienen meta y no sincronizan hasta relanzarse. Opcional: derivar meta al escanear si falta.
3. **ScummVM**: sus partidas guardan en la ruta propia de ScummVM, no en `saves/` → no entran en el sync. Pendiente mapear/redirigir.
4. **Conflictos interactivos**: hoy `conflict` solo cuenta (keep_both). Falta UI para elegir versión.
5. **T008 PlaySessionTracker**: registrar playtime y enviarlo en `play_sessions` del `complete` (hoy va lista vacía).
6. **Stems ambiguos**: si el mismo nombre base existe en varias plataformas, se omiten. Opcional: desambiguar por plataforma.
7. **T012**: cierre del SDD `romm-local-play-sync` (evidencia global).

# Evidencia de estado
- `flutter analyze` → "No issues found!" (2026-10-03). Sin build (norma del proyecto).

# Fix 2026-10-05 — log de diagnóstico y capacidad por emulador

## Intent
Hacer observable el sync (qué roms se envían, ops recibidas y resultado) y contemplar que
las partidas solo son sincronizables con **RetroArch** (base o cores alternativos). Los
emuladores standalone (Ryujinx/Switch, ScummVM, Dolphin, PPSSPP, PCSX2…) guardan en su
propio directorio y con nombres por título/serial, no por stem del ROM → no sincronizan.

## Scope
- In: `[RommSync]` logs en `RommSyncController`; flag `saveSync` en `.fynitiv.meta`;
  filtrado+log de juegos sin soporte; generar config de RetroArch también para cores
  alternativos (`retroarch_core != null`) para que guarden en `saves/`/`states/`.
- Out: cambiar `negotiate` (roms con saves vacíos), configuración de rutas de guardado
  de emuladores standalone, UI/ARB nuevos.

## Checklist
- [x] FTD actualizado antes del primer cambio
- [x] Logs de diagnóstico en `RommSyncController` (petición, respuesta, ops, resultado)
- [x] `saveSync` en `.fynitiv.meta` (`romm_providers._launch`)
- [x] Filtrado + log de juegos sin soporte en el sync
- [x] `_writeRetroArchConfig` también cuando `spec.retroarchCore != null`
- [x] `flutter analyze` limpio → "No issues found!" (2026-10-05)

## Evidence
- `romm_sync_controller.dart`: helper `[RommSync]` + logs en salidas tempranas, metas
  (`saveSync=false` → skip, sin flag → asumido), assets locales (rom/file/sha1/mtime),
  petición (`negotiate roms=N`), respuesta (`session`, `ops`), cada op, resultado por op,
  `complete` y reporte final.
- `romm_providers.dart`: `.fynitiv.meta` incluye `saveSync` (`_supportsSaveSync` =
  `id=='retroarch' || retroarchCore != null`); `_writeRetroArchConfig` se genera también
  para cores RetroArch alternativos (antes solo id `retroarch` → no redirigía saves).
- Verificación: `flutter analyze` → "No issues found!" (2026-10-05).

## Next
- Verificación manual en RomM real + 2º dispositivo (subida/bajada/conflicto).
- Opcional: incluir en `negotiate` todos los roms con `saves: []` para bajar ausentes.
- Opcional: backfill de `.fynitiv.meta` (incluido `saveSync`) al escanear.

# Fix 2026-10-05b — 422 por negotiate vacío y RetroArch sin core en Windows

## Intent
Corregir lo que reveló el log de diagnóstico en una prueba real (`gb`): el sync enviaba
`negotiate` con `roms: []` (los ficheros detectados eran configs, no partidas) → RomM
devolvía **422**; y RetroArch base en Windows arrancaba **sin core** (`core=null`), salía
con `code=1` y no generaba partida.

## Scope
- In: `RommSyncController` (no negociar en vacío; saltar ficheros de servicio; log por
  fichero; log de `statusCode`+body); `EmulatorLauncher` (pasar `coreName` en Windows y
  usar `-L` en RetroArch base); `emulators.json` (`cores` en `retroarch.windows`).
- Out: sync de partidas de PSP/GC/Wii/3DS/PS2 (subcarpetas por core), backfill de metas.

## Checklist
- [x] FTD antes del primer cambio
- [x] `negotiate` se omite si `roms` vacío (evita 422)
- [x] Ficheros de servicio (`.cfg`/`.ini`) saltados y log por fichero escaneado
- [x] Error de `negotiate` loguea `statusCode` y body
- [x] `coreName` en `_launchWindows` + `-L` para RetroArch base
- [x] `cores` en `retroarch.windows`
- [x] `flutter analyze` limpio

## Evidence
- Log real previo: `negotiate roms=0 … FALLÓ … status code of 422` (configs en `states/`,
  no partidas). `[EmulatorLauncher] … core=null … exited code=1`.
- Cambios 2026-10-05: ver arriba. Comprobación JSON (`ConvertFrom-Json`) OK.
- `flutter analyze` → "No issues found!" (2026-10-05).

## Next
- Repetir la prueba: lanzar `gb` con RetroArch debe arrancar con `-L gambatte` y, al
  guardar, el sync debe mostrar `scan … -> rom=…`, `negotiate roms=1`, `upload OK`.

# Fix 2026-10-05c — RetroArch sin cores instalados (`code=1`)

## Intent
El log real mostró `-L …gambatte_libretro.dll` pero RetroArch seguía saliendo con `code=1`.
Diagnóstico en disco: `C:\RetroArch-Win64\cores` está **vacío** (0 cores) → RetroArch no
puede cargar el core especificado y sale. Se añade descarga automática del core que falte
(Windows) desde libretro buildbot, con loader y aviso si falla.

## Scope
- In: `LocalPlayController._ensureRetroArchCore` (descarga+extrae `<core>_libretro.dll`
  desde `buildbot.libretro.com` a `<exe>/cores`); `LocalPlayStatus.coreMissing`; ARB
  EN+ES `gamesLocalCoreDownloading`/`gamesLocalCoreMissing`.
- Out: gestión de cores en Android (vienen dentro del APK de RetroArch); emuladores
  standalone.

## Checklist
- [x] FTD antes del primer cambio
- [x] `_ensureRetroArchCore` (Windows) con extracción del `.dll` por `archive`
- [x] `LocalPlayStatus.coreMissing` + aviso localizado
- [x] Loader (`EasyLoading`) durante la descarga
- [x] ARB EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- `C:\RetroArch-Win64\cores` → 0 ficheros; `gambatte_libretro.dll` ausente; URL buildbot
  HEAD `gambatte_libretro.dll.zip` → 200.
- `flutter gen-l10n` OK; `flutter analyze` → "No issues found!" (2026-10-05).

## Next
- Repetir: al pulsar Jugar, el log debe mostrar `[LocalPlay] core gambatte missing -> download`
  → `core gambatte installed`, y RetroArch debe arrancar y generar `saves/<stem>.srm`.

# Fix 2026-10-05d — descriptor de guardado por plataforma + ScummVM

## Intent
El core de ScummVM (vía RetroArch) guarda en `C:\Fynitiv\saves\ScummVM\monkey2.s00` con el
**gameid** como nombre, no el stem del ROM, y en subcarpeta. El escáner plano lo ignoraba y
el meta no tenía `stem`. Se introduce un **descriptor declarativo** de guardado por
plataforma en el catálogo (extensible a futuros emuladores sin tocar el motor) y se soporta
ScummVM (subida y bajada in-place). Confirmado en disco: los cores se instalaron solos y el
core ScummVM escribió `saves\ScummVM\monkey2.s00/.s01`.

## Scope
- In: `EmulatorSaveLayout` (`id_source` = `stem|scummvm_gameid|title_id`, `saves_subdir`,
  `states_subdir`); `save_layout` de `scummvm` en `emulators.json`; meta con `stem` por
  `idSource` + subdirs; `sort_*=false` en el override de RetroArch; `listFilesRecursive`;
  escaneo recursivo con `relDir` y descarga in-place.
- Out: `title_id` (PPSSPP/Dolphin/PCSX2); emuladores standalone con appdata propio; copia
  local anti-pérdida en `download` (se confía en el `negotiate`).

## Checklist
- [x] FTD antes del primer cambio
- [x] `EmulatorSaveLayout` + parsing `save_layout`
- [x] `save_layout` de `scummvm` en el catálogo
- [x] `readScummVmGameId` público (y acepta carpeta)
- [x] `sort_*=false` en `_writeRetroArchConfig`
- [x] meta: `stem` por `idSource` + `saveSubdir`/`stateSubdir`
- [x] `listFilesRecursive` + escaneo recursivo con `relDir`
- [x] descarga in-place (respeta subcarpeta)
- [x] `flutter analyze` limpio

## Evidence
- En disco: `C:\Fynitiv\saves\ScummVM\monkey2.s00` + `.s01`; cores instalados solos en
  `C:\RetroArch-Win64\cores`. Protocolo RomM confirmado: negotiate con `sha1`+`mtime`
  devuelve `noop|upload|download|conflict(keep_both)`.
- Cambios 2026-10-05: `EmulatorSaveLayout`; `scummvm.save_layout`; `readScummVmGameId` estático;
  `sort_*=false`; meta con `stem` por `idSource` + subdirs; `listFilesRecursive`; escaneo
  recursivo con `relDir`; descarga in-place.
- JSON válido (`ConvertFrom-Json`); `flutter analyze` → "No issues found!" (2026-10-05).

## Next
- **Relanzar ScummVM una vez** para regenerar el `.fynitiv.meta` con `stem=monkey2` (los metas
  previos no lo tienen). Luego sync → `scan ScummVM/monkey2.s00 stem=monkey2 -> rom=28901`
  → `negotiate roms=1` → `upload OK`.
- Futuro: `title_id` (PPSSPP/Dolphin/PCSX2) y standalone con appdata propio.

# Fix 2026-10-05e — protocolo real de RomM 5.3.1 (negotiate plano)

## Intent
La prueba real devolvió `422 body={loc:[body,saves], msg: Field required}`. Verificado contra
el código de RomM **5.3.1** (`backend/endpoints/sync.py` + `responses/sync.py`), el schema es
**una lista plana `saves`** (no `roms[].saves`), con `file_name`/`content_hash`/`updated_at`/
`file_size_bytes` y `slot`; las ops usan `action` (`upload|download|conflict|no_op`) y
`save_id` (el binario se baja por `GET /api/saves/{id}/content`). Además 5.3.1 **solo negocia
saves, no states**.

## Scope
- In: `RommRepository.negotiateSync` (payload plano + `rom_ids`), `uploadSave` (`slot`/
  `emulator`), `saveContentUrl`; `RommSyncController` reescrito (slot = nombre de fichero,
  lista plana, ops por `action`/`save_id`, descarga por `/{id}/content`, solo `saves/`);
  meta con `emulator`.
- Out: sync de **states** (no soportado por la versión del servidor); subida/bajada por
  `title_id`; emuladores standalone.

## Checklist
- [x] FTD antes del primer cambio
- [x] `negotiateSync` con `{device_id, saves[], rom_ids?}`
- [x] `uploadSave` con `slot` + `emulator`
- [x] `saveContentUrl` + descarga por `save_id`
- [x] Controlador: `slot` estable, ops `action`, `no_op`, solo `saves/`
- [x] Scope `rom_ids` (límite 500)
- [x] `flutter analyze` limpio

## Evidence
- Código RomM 5.3.1: `SyncNegotiatePayload{device_id?, saves: list[ClientSaveState], rom_ids?}`;
  `ClientSaveState{rom_id, file_name, slot?, emulator?, content_hash?, updated_at,
  file_size_bytes}`; `SyncOperationSchema{action, rom_id, save_id?, file_name, slot?}`;
  `SAVE_SLOT_MAX_LENGTH=255`; `MAX_ROM_IDS_PER_QUERY=500`; `/api/saves/{id}/content`.
- **`content_hash` = MD5** (RomM `assets_handler._compute_file_hash` usa `hashlib.md5`;
  `compare_save_state` da `no_op` solo si los hashes coinciden). El cliente usa `md5`.
- `flutter analyze` → "No issues found!" (2026-10-05).

## Next
- Probar: `negotiate saves=2 rom_ids=…` → `upload OK` de `monkey2.s00`/`monkey2.s01`
  (RomM crea las partidas bajo `assets/users/<user>/saves/scummvm/28901/`).

# Fix 2026-10-05f — RetroArch queda residente al cerrar

## Intent
Al cerrar RetroArch (Windows), su proceso queda vivo en memoria (bug conocido con
ciertos cores / "handoff" de instancia única), como pasaba con ScummVM. Se refuerza la
limpieza y se fuerza a RetroArch a salir al cerrar el contenido.

## Scope
- In: `EmulatorLauncher.killByImage` (`taskkill /F /T /IM`); limpieza **antes** de lanzar
  (huérfanos) y **al salir** (hijos/re-parentados); `lastImageName`; `game_detail_screen`
  mata el emulador residente al volver a la app (`resumed`) si sigue "en ejecución";
  `_writeRetroArchConfig` con `quit_on_close_content=true`, `config_save_on_exit=false`,
  `ui_companion_*=false`.
- Out: detección por handle de ventana; otros SO.

## Checklist
- [x] FTD antes del primer cambio
- [x] `killByImage` + uso pre-lanzamiento y al salir
- [x] `lastImageName` + limpieza en `resumed`
- [x] flags de salida en el override de RetroArch
- [x] `flutter analyze` limpio

## Evidence
- Logs previos: `[EmulatorLauncher] windows exited pid=… code=1` con instancias
  residentes tras cerrar (bug conocido de RetroArch con cores que no liberan).
- `flutter analyze` → "No issues found!" (2026-10-05).

## Next
- Probar: lanzar un juego, cerrar RetroArch y comprobar en el Administrador de tareas que
  no queda `retroarch.exe`; y que volver a la app limpia el estado "En ejecución".

# Fix 2026-10-05g — pull de partidas al abrir el juego

## Intent
El sync solo se ejecutaba **al cerrar** (push). Al abrir un juego con `saves/` vacío no se
bajaba la partida de RomM, así que no se podía continuar. Se añade un **pull dirigido al
juego** antes de lanzar el emulador.

## Scope
- In: `RommSyncController.pullRom(romId, stem, subdir, emulator)` (negocia solo ese rom y
  aplica `download`); helper de nombre local de descarga basado en `slot`; hook en
  `LocalPlayController._launch`; loader `gamesLocalSyncSaves` (ARB EN+ES).
- Out: subir antes de jugar (se sigue subiendo al cerrar); sync de states.

## Checklist
- [x] FTD antes del primer cambio
- [x] `pullRom` (solo `download`, `rom_ids:[id]`, `complete`)
- [x] Nombre local de descarga por `slot` (evita el nombre etiquetado de RomM)
- [x] Hook en `_launch` antes de lanzar + loader
- [x] ARB `gamesLocalSyncSaves` + gen-l10n
- [x] `flutter analyze` limpio

## Evidence
- `RommSyncController.pullRom` + `_localNameFor`; `LocalPlayController._launch` llama `pullRom`
  tras escribir el meta y antes de lanzar (solo si `_supportsSaveSync`); loader
  `gamesLocalSyncSaves` (EN+ES).
- Log real: `pull rom=28901 stem=monkey2 saves=0` → `ops=0` (RomM no re-ofrece una partida
  que cree borrada a propósito). Se añade **fallback** con `GET /api/saves/summary?rom_id=…`:
  baja cada `latest` por slot si falta localmente (`pull server slots=N` / `pull fallback
  download slot=…`).
- `RommRepository.getSavesSummary`; `flutter gen-l10n` OK; `flutter analyze` → "No issues
  found!" (2026-10-05).

## Next
- [x] Verificado manualmente (2026-10-05): pull al abrir + push al cerrar bidireccional OK
  ("todo correcto").
