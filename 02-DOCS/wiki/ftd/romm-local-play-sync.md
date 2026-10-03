# Juego local RomM con sync de dispositivo

## Intent
Permitir jugar a los juegos de RomM **en local** (descargar el ROM y abrirlo en un emulador externo) y
mantener sincronizados biblioteca, sesiones de juego y partidas (saves/states) con RomM, sustituyendo
el juego en navegador/streaming del servidor. Empieza por el **emparejamiento por QR** (device
authorization flow de RomM) para no teclear la API key ni el token.

Spec: `02-DOCS/wiki/sdd/specs/romm-local-play-sync.md`
Plan: `02-DOCS/wiki/sdd/plans/romm-local-play-sync.md`

## Scope
- In: emparejamiento por QR (`POST /api/auth/device/init` + polling `/api/auth/device/token`, RomM crea
  el Device y su token ligado); almacén local de ROMs/saves/states; lanzador de emulador externo
  (Android intent / Windows proceso); motor de sync (`/api/sync/negotiate`, `/api/saves`,
  `/api/sync/sessions`), saves+states, conflictos conservadores; play sessions; UI en Ajustes y detalle.
- Out: emulador embebido (libretro/FFI), catálogo offline completo, SSH sync, RetroAchievements,
  netplay, multi-cuenta.

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] sdd-init: `config.yaml` + registry
- [x] constitution v1.0.0 ratificada
- [x] spec `romm-local-play-sync` clarificado (plataformas, saves+states, sync, conflictos)
- [x] plan + tasks (T001-T012) + forecast
- [x] T001 spike de endpoints + confirmación del device-flow en RomM 5.3.1
- [x] T002 cadenas ARB del pairing (EN+ES)
- [x] T003 `RommRepository.deviceAuthInit` + `deviceAuthPoll`
- [x] T004 `RommAuthController.beginQrPairing/pollQrPairing` + diálogo QR en `games_panel`
- [x] T005 dispositivo + `device_id` que ya crea RomM en la aprobación
- [x] T006 `LocalGameStore` (layout roms/bios/saves/states, descarga, extracción `.zip`)
- [x] T007 `EmulatorLauncher` catalog-driven (Android intent / Windows exe) + pestaña Emuladores
- [ ] T008 `PlaySessionTracker`
- [x] T009 `RommSyncEngine`
- [x] T010 UI de sync + historial
- [x] T011 catálogo de emuladores + asociación por plataforma + autodetección de instalado
- [ ] T012 cierre + evidencia

## Evidence
- Device authorization flow confirmado en **RomM 5.3.1** (`backend/endpoints/device_auth.py`,
  `frontend/src/v2/views/DevicePair.vue`, ruta web `/pair/device`):
  - `POST /api/auth/device/init` (abierto) `{client_device_identifier, name, client, platform?,
    client_version?, requested_scopes[]}` → `{device_code, user_code, verification_path:"/pair/device",
    verification_path_complete:"/pair/device?user_code=…", expires_in:600, interval:5}`.
  - El QR contiene `{serverUrl}/pair/device?user_code=…` (el device lo pinta; no necesita cámara).
  - `POST /api/auth/device/token {device_code}` cada `interval`: `400 authorization_pending` ·
    `400 slow_down` · `400 access_denied` · `400 expired_token` · `200 {access_token, device_id, scopes}`.
  - En la aprobación RomM crea el **Device + ClientToken ligado**; no hace falta `POST /api/devices`.
- Scopes solicitados: `roms.read`, `devices.read`, `devices.write`, `assets.read`, `assets.write`,
  `me.read`, `me.write` (válidos según `handler/auth/constants.py` de 5.3.1).
- Sync (fase posterior): `POST /api/sync/negotiate` → ops `upload|download|conflict|noop`; subida
  `POST /api/saves`; bajada `GET /api/saves/{id}/content`; cierre `POST /api/sync/sessions/{id}/complete`.
- `GET https://romm.lopivhouse.page/api/heartbeat` → `VERSION 5.3.1` (2026-10-01).
- Implementación 2026-10-01 (rama `feat/romm-local-play-sync`), device-flow:
  - `romm_repository.dart`: clases `RommDeviceAuthStart` / `RommDeviceAuthPollResult` +
    `RommDeviceAuthStatus`; métodos `deviceAuthInit(...)` y `deviceAuthPoll(deviceCode)`.
    **Se eliminaron** `exchangePairingCode` y `registerDevice`.
  - `romm_providers.dart`: `beginQrPairing(...)` (devuelve datos del QR), `pollQrPairing(...)`
    (respeta `interval`, sube +5 s en `slow_down`, timeout a `expires_in`, cancelable) y
    `cancelQrPairing()`; persiste token y `device_id` (string). **Se eliminaron** `pairWithCode` y
    `ensureDeviceRegistered`.
  - `romm_storage.dart`: `romm.device_id` pasa a **string** (UUID del device).
  - `games_panel.dart`: botón "Emparejar con QR" → diálogo con QR (`qr_flutter`), `user_code`, cuenta
    atrás, "Abrir en el navegador" y cancelación. API Key sigue como fallback.
  - `pubspec.yaml`: `qr_flutter ^4.1.0`, `package_info_plus ^10.2.1`.
  - ARB EN+ES: `rommPairTitle/Help/CodeLabel/Button/Success/Failed`, `rommOrApiKey`,
    `rommQrScanHint/Waiting/OpenBrowser/Denied/Expired/Cancel/Preparing`.
  - Verificación: `flutter pub get` OK; `flutter gen-l10n` OK; `flutter analyze` → "No issues found!".
- Referencias: `rommapp/argosy-launcher` (Android), `rommapp/grout` (protocolo de saves).
- Implementación 2026-10-01 (Bloque "emuladores + BIOS"), rama `feat/romm-local-play-sync`:
  - **Catálogo**: `assets/data/emulators.json` (emuladores por SO con URLs de descarga, cores y args;
    plataformas con recomendado por SO; alias). Modelos en `domain/emulator_profile.dart`, loader
    `data/emulator_catalog.dart` (`emulatorCatalogProvider`).
  - **Asociación**: `data/emulator_preferences.dart` (`romm.emulator.assoc.<slug>` y overrides por
    emulador: win_exe/win_args/android_pkg/bios_dir) + `emulatorPreferencesProvider`.
  - **Lanzador**: `EmulatorLauncher.launch(emulator, spec, romPath, prefs, coreName, configFilePath)`
    (Android: extras ROM/LIBRETRO/CONFIGFILE; Windows: exe del prefs + args con `%ROM%`).
  - **Pestañas**: `games_screen` con selector grande **Juegos | Emuladores** (foco de mando) y
    `presentation/widgets/emulators_tab.dart` (por plataforma: recomendado, Descargar, asociar,
    instalado en Android, selector de .exe en Windows).
  - **Botón Jugar universal**: `game_detail_screen` muestra Jugar cuando `game.firstFile != null`
    (ya no depende de EmulatorJS); streaming/navegador eliminado (badge y `_play`).
  - **BIOS + layout**: `LocalGameStore` con `roms/<slug>`, `bios/`, `saves/`, `states/`;
    `RommRepository.getFirmware/firmwareDownloadUrl/downloadUrlTo`; `LocalPlayController` hace
    BIOS → ROM → lanzar y genera `CONFIGFILE` de RetroArch apuntando system/save/state a nuestra
    estructura.
  - Deps: `qr_flutter`, `package_info_plus`, `archive`, `android_intent_plus`, `installed_apps`.
    `<queries>` de paquetes Android en `AndroidManifest.xml`.
  - **Tick "configurado"**: `platformPlayReadinessProvider` (Windows = `.exe` guardado; Android =
    paquete instalado). Tick verde con tooltip "Configurado correctamente" en la tarjeta de Emuladores
    (junto al desplegable) y en la tarjeta de plataforma de games screen (esquina inferior derecha).
  - **Botón Jugar condicionado**: en `game_detail_screen` aparece solo si hay archivo **y** la
    plataforma está lista (`platformPlayReadinessProvider`); si no, solo se muestra Descargar.
  - **Pestañas comunes**: nuevo widget `core/widgets/app_tab_bar.dart` (`AppTabBar`/`AppTabItem`,
    index-based, con `AppHover` para hover/foco TV), reutilizado por la pantalla de Juego online
    (Juegos | Emuladores) y por Live TV (TV | Radio), sustituyendo el `TabBar` inline de Live TV.
- Verificación: `flutter analyze` → "No issues found!".

### Cambio 2026-10-01 — raíz Fynitiv + descarga por zip de juegos de carpeta

- **Raíz común**: `lib/core/storage/app_paths.dart` (`AppPaths`): Windows `C:\Fynitiv`, Android
  externo de la app (`Android/data/<pkg>/files/Fynitiv`), otros `.../Fynitiv`. Subcarpetas
  `roms/`, `bios/`, `saves/`, `states/`, `Downloads/`. Si no se puede crear (permisos), lanza
  `AppPathsException` y la UI avisa.
- **Descargas generales** (vídeos/música Jellyfin): por defecto van a `Fynitiv/Downloads`.
- **Zip multiarchivo**: `RommGame.hasMultipleFiles` (de `has_multiple_files`/`files>1`);
  `RommRepository.romZipUrl(romId, filename:)` → `/api/roms/download?rom_ids=`; `LocalGameStore.extractZipInto`
  extrae preservando subcarpetas (quitando carpeta raíz única).
- **Juego local**: `LocalPlayController` distingue single-file (descarga directa) de multiarchivo/carpeta
  (zip → extracción **automática** al terminar). Plataformas de carpeta (`scummvm`, `win`, `dos`,
  `msdos`, `openbor`) lanzan el **directorio**; el resto, el archivo principal. La descarga se espera
  en la misma pulsación (spinner) y luego se lanza.
- Verificación: `flutter analyze` → "No issues found!".

### Extracción aplanada, sin soundtrack y con marcador (2026-10-01)

- `extractZipInto` **aplana prefijos comunes** (`roms/<juego>/<juego>/…` → `…/<juego>/`), **omite** las
  carpetas prescindibles (`soundtrack`) y notifica progreso.
- `LocalGameStore.clearDir` + `markReady`/`isReady`: se limpia la carpeta del juego antes de extraer y
  se marca `.fynitiv.ready`; si ya está lista, **se lanza directamente** sin volver a descargar/extraer.
- El zip se **borra** tras extraer correctamente (ya no ocupa espacio y no incluye el soundtrack en la
  carpeta del juego).
- Verificación: `flutter analyze` → "No issues found!".

### Fix 2026-10-01 — lanzamiento Windows (ScummVM) 

- El proceso se lanzaba (`launch ok=true`) pero ScummVM salía con **code 1**: no acepta la carpeta como
  argumento. Args correctos: `--auto-detect --path="%ROM%"` (catálogo `emulators.json`).
- `EmulatorLauncher._launchWindows`: `ProcessStartMode.detached` → `normal`, `workingDirectory` a la
  carpeta del exe, y log del **pid** + código de salida para diagnosticar cierres inmediatos.
- Verificación manual: `scummvm --auto-detect --path="<carpeta>"` mantiene el proceso vivo; la carpeta
  extraída contiene `monkey2.000`/`.scummvm` (correcto).

### Al lanzar el emulador, pausar la OST (2026-10-01)

- En `game_detail_screen._playLocal`, en `LocalPlayStatus.launched` se llama
  `GameOstPlayer.instance.pauseForExternal()` para que la banda sonora no suene mientras el emulador
  externo está en primer plano. `resumeIfNeeded()` (lifecycle) la reanuda al volver si procede.
- Verificación: `flutter analyze` → "No issues found!".

### Toggles por juego: subtítulos y pantalla completa (2026-10-01)

- Persistencia por juego (`romm.game.subtitles.<id>`, `romm.game.fullscreen.<id>`) en
  `data/game_play_options.dart`; provider `gamePlayOptionsStoreProvider`.
- `EmulatorOsSpec.subtitlesFlag`/`fullscreenFlag` (JSON `subtitles_flag`/`fullscreen_flag`); ScummVM los
  define (`--subtitles`, `--fullscreen`), RetroArch `--fullscreen`.
- En el detalle, junto a Descargar y solo si `canPlay`, `_GamePlayToggles` (dos botones con tooltip y
  color del skin) que persisten y afectan al lanzamiento (`EmulatorLauncher` añade `extraArgs`).
- Verificación: JSON válido, `flutter gen-l10n` OK y `flutter analyze` → "No issues found!".

### Estado "jugando": pausa de audio y botón deshabilitado (2026-10-01)

- `EmulatorLaunchResult.exit` (Windows) expone el `exitCode` del proceso del emulador.
- `gameRunningProvider` (Notifier<int?>) guarda el id del juego en ejecución; se marca al lanzar y se
  limpia cuando el proceso termina.
- Al lanzar: `GameOstPlayer.pauseForExternal()` + `GameBgPlayer.pauseForGame()` (nuevo, sin el guard de
  `pauseForExternal`); al salir: `resumeIfNeeded()` de ambos.
- El botón **Jugar** se muestra deshabilitado ("En ejecución") mientras ese juego corre, y se rehabilita
  al cerrarse el emulador (evita lanzarlo dos veces).
- Verificación: `flutter analyze` → "No issues found!".

### ScummVM: cierre inmediato y salir al cerrar el juego (2026-10-01)

- **Causa del cierre inmediato**: se pasaban flags inexistentes (`--auto-run`, `--quit-after-play`) y,
  además, las opciones iban **después** del gameid → ScummVM daba `Stray argument '<gameid>'` y salía con
  code 1. Solución: quitar esos flags y dejar el **gameid SIEMPRE al final** de los args.
- **No quedarse residente**: se genera un config propio copiando `%APPDATA%\ScummVM\scummvm.ini` y
  forzando `[scummvm] gui_return_to_launcher_at_exit=false` (+ `start_minimized=false`), pasado con
  `-c "<cfg>"` (en `states/scummvm_fynitiv.ini`).
- `_launchScummVm` resuelve el gameid desde el `.scummvm` y lanza `--path=<carpeta> … <gameid al final>`.
- Al salir el proceso, `exitCode` completa → se limpia el estado "en ejecución" y el botón se rehabilita.
- Verificación manual: `--path=… -c … --subtitles monkey2` (gameid último) mantiene el proceso vivo;
  con opciones tras el gameid, `Stray argument`. `flutter analyze` → "No issues found!".

### Barra de descarga: estado "Extrayendo" con progreso (2026-10-01)

- `DownloadStatus.extracting` + `DownloadTask.extractProgress`; `DownloadManagerController` añade
  `startExtracting`/`updateExtractProgress`/`finishExtracting` (cancela el prune del zip y lo
  reprograma al terminar).
- `LocalGameStore.extractZipInto` notifica progreso por archivo; `LocalPlayController` actualiza la
  barra durante la extracción.
- La fila de la barra muestra icono `unarchive`, texto "Extrayendo…", porcentaje y barra de progreso.
- Verificación: `flutter analyze` → "No issues found!".

### Fix 2026-10-01 — layout por juego, multiarchivo y plataformas de carpeta

- **Bug ruta doble**: `rootDir()` devolvía `.../romm/roms` y `platformDir` añadía otro
  `roms` → `.../romm/roms/roms/<slug>`. Ahora la raíz es `.../romm` y cuelgan `roms/`, `bios/`,
  `saves/`, `states/`.
- **Layout por juego**: `LocalGameStore.gameDir(slug, name)` → `roms/<slug>/<juego>/`; la descarga
  preserva subcarpetas (`localPathFor` y el gestor de descargas sanean y conservan estructura).
- **Multiarchivo**: `RommRepository.getGameFiles(romId)` (vía `/api/roms/{id}/files`); `LocalPlayController`
  descarga **todos** los archivos del juego, no solo el primero.
- **Selección de archivo jugable**: `_pickPlayableFile` prioriza `.scummvm/.m3u/.cue/.chd/.iso` y ROMs,
  y descarta arte/audio/docs/saves (`flac`, `mp3`, `png`, `pdf`…), evitando casos como ScummVM con
  `001 Introduction.flac`.
- **Plataformas de carpeta** (`scummvm`, `win`, `dos`, `msdos`, `openbor`): se lanza el **directorio**
  del juego, no un archivo.
- **Diagnóstico**: `debugPrint` `[LocalPlay]`/`[EmulatorLauncher]` y captura de errores visible en
  `_playLocal`.
- Verificación: `flutter analyze` → "No issues found!".
- Implementación 2026-10-01 (Bloques 1-3), rama `feat/romm-local-play-sync`:
  - **Bloque 1**: eliminado el modo API Key. `RommConfig{serverUrl, token}`; `RommStorage` usa
    `romm.access_token` (seguro) y `romm.device_id` (string); fuera `login`/`loginWithApiKey`.
    `kRommRequestedScopes` ampliado a `me.*`, `roms.read`, `roms.user.*`, `platforms.read`,
    `assets.*`, `devices.*`, `firmware.read`. ARB sin claves de API Key. `games_panel` = URL + QR.
  - **Bloque 2**: `LocalGameStore` (raíz `<appSupport>/romm/roms` + override `romm.roms_dir`,
    `platformDir`, `localPathFor`, `resolvePlayableFile` con extracción `.zip`). `DownloadManager.enqueue`
    acepta `destinationDir`. Dep `archive`.
  - **Bloque 3**: `EmulatorLauncher` (Android: Intent a RetroArch con `ROM`+`LIBRETRO` y mapa
    `kRetroArchCores`; Windows: exe + args con `%ROM%`). Dep `android_intent_plus`. `LocalPlayController`
    orquesta descargar+extraer+lanzar. Botón "Jugar" del detalle usa `_playLocal` (fallback a streaming
    si no hay emulador). Tarjeta "Emulador" en Ajustes (paquete Android / exe+args Windows).
  - Verificación: `flutter analyze` → "No issues found!" tras cada bloque.

### Alternativas de emulador y cores de RetroArch (2026-10-01)

- `EmulatorOsSpec.retroarchCore` (JSON `retroarch_core`): una alternativa que es un **core de
  RetroArch**. El lanzador usa RetroArch con `-L <core>_libretro.dll` (Windows) o el core en el intent
  Android, en vez de un exe propio.
- Catálogo ampliado: 48 emuladores y 51 plataformas. Añadidas alternativas por sistema (Nestopia UE,
  Mupen64Plus-Next, DeSmuME, Beetle VB/Lynx/WonderSwan/NeoPop/PCE/SuperGrafx/Saturn/PSX HW, Gearcoleco,
  blueMSX, VICE x64sc, PUAE, DOSBox Pure, FreeIntv, O2EM, SAME CDi, Opera, Genesis Plus GX, PicoDrive,
  Flycast, Vecx, Fuse, MAME, Virtual Jaguar, xemu, WinUAE) y plataformas nuevas (pce, sgx, amiga,
  intellivision, odyssey-2, cdi, dreamcast, vectrex, xbox).
- Para una alternativa-core, la tarjeta usa el `.exe` de **RetroArch** (readiness y selección de fichero
  apuntan a `retroarch`), y "Descargar" apunta a RetroArch.
- Verificación: JSON válido y `flutter analyze` → "No issues found!".

## Next
Probar el emparejamiento QR en real (RomM 5.3.1): Ajustes → Juego online → "Emparejar con QR" →
escanear con el móvil → aprobar. Después T008-T010 y T012 (play sessions, motor de sync
saves/states y UI de sync).

### Sync saves/states (T009/T010) — 2026-10-03

- `RommSyncController`/`rommSyncProvider` (`application/romm_sync_controller.dart`): escanea
  `saves/`+`states/`, mapea a `rom_id` por `.fynitiv.meta` (stem del jugable), `sha1`+mtime,
  `POST /api/sync/negotiate`, ejecuta ops (upload `POST /api/saves` multipart `saveFile`; download
  `GET {source}`; conflict = keep_both sin sobrescribir), `POST /api/sync/sessions/{id}/complete`.
- Meta por juego: `LocalGameStore` (`.fynitiv.meta`, `listGameMetas`, `listFiles`) escrita al lanzar
  en `LocalPlayController._launch`.
- UI: `_SavesSyncCard` en `games_panel`; sync automático al cerrar la sesión (`exit.then`).
- FTD del feature: `02-DOCS/wiki/ftd/romm-saves-sync.md`. `flutter analyze` → "No issues found!".
- Pendiente: verificación manual en RomM real + 2º dispositivo; T008 (play sessions); T012.

