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
- [ ] T009 `RommSyncEngine`
- [ ] T010 UI de sync + historial
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

## Next
Probar el emparejamiento QR en real (RomM 5.3.1): Ajustes → Juego online → "Emparejar con QR" →
escanear con el móvil → aprobar. Después T008-T010 y T012 (play sessions, motor de sync
saves/states y UI de sync).
