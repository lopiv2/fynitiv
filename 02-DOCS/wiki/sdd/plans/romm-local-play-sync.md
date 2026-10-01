---
type: plan
title: Plan — Juego local RomM con sync de dispositivo
description: The structure-level implementation plan for local RomM play — contracts, shapes, flows.
tags: [sdd, plan]
timestamp: 2026-10-01T00:00:00Z
topic: sdd
slug: romm-local-play-sync
status: draft
---

# Plan — Juego local RomM con sync de dispositivo

> Spec: [../specs/romm-local-play-sync.md](../specs/romm-local-play-sync.md) · Constitution: [../constitution.md](../constitution.md) · Status: draft
> Last updated: 2026-10-01

## 0. Global Constraints

- **Stack:** Flutter 3.49 / Dart `^3.12.2`; Riverpod (estado/DI), go_router, Dio, material_ui, gen-l10n.
- **Verificación:** `flutter analyze` limpio en los ficheros tocados. **Prohibido `flutter build`.**
- **Tests:** no se escriben ni ejecutan salvo petición explícita. No comentarios salvo petición.
- **i18n:** todo texto de widget traducido con ARB (`lib/l10n/app_en.arb` + `app_es.arb`); reutilizar
  claves; no editar `app_localizations*.dart` a mano.
- **Notificaciones:** `flutter_easyloading` (nunca `ScaffoldMessenger`/`SnackBar`).
- **Loader:** `AppLoader` en toda petición Dio a RomM mientras carga.
- **Hover:** tarjetas con el widget universal de Hover. No tocar `PrimeCardBadge` sin permiso.
- **Secretos:** token en `flutter_secure_storage`; nunca en claro ni en logs.
- **Docs:** un FTD por feature en `02-DOCS/wiki/ftd/<slug>.md` antes del primer cambio.
- **Alcance:** Android + Windows; saves **y** states; sync manual + al cerrar sesión; conflictos =
  conservar ambas sin sobrescribir.

## 1. Context & constraints

- Acceptance criteria que moldean el diseño: spec §Acceptance #1-#9 (pairing, descarga+emulador,
  sesión, saves+states, conflicto conservador, offline).
- No funcionales: la UI no debe bloquear durante descargas/sync; operar offline para juegos ya
  descargados; tamaño de subida limitado por el reverse proxy del servidor.
- Constitución en juego: principios 4-14 (calidad, i18n, EasyLoading, AppLoader, Hover, no tocar
  elementos a mano).
- Fuera de alcance que el diseño NO debe invadir: emulador embebido, catálogo offline completo, SSH
  sync, RetroAchievements/netplay, multi-cuenta.

## 2. Architecture

```text
[ Settings UI (pairing) ] --code--> [ RommPairingService ] --POST exchange--> [ RomM API ] (external)
[ GameDetail "Jugar" ] --> [ LocalPlayOrchestrator ] --> [ LocalGameStore ] --download--> [ RomM API ]
                                   |                          |
                                   |                          v
                                   |                    [ filesystem local ] (external)
                                   v
                        [ ExternalEmulatorLauncher ] --intent/process--> [ Emulator externo ] (external)
                                   |
                        sesión termina
                                   v
                        [ PlaySessionTracker ] --play_sessions--> [ RomM API ]
                                   |
                                   v
                        [ RommSyncEngine ] --negotiate/execute/complete--> [ RomM API ]
                                   |
                                   v
                        [ Sync UI (manual + auto) ] · [ SyncedGames/History ]
```

- **RommPairingService** (internal) — canjea el código de emparejamiento por token y valida; única
  responsabilidad: auth por pairing. Convive con el modo API Key actual.
- **RommDeviceRegistry** (internal) — registra/identifica el dispositivo ante RomM y cachea su id.
- **LocalGameStore** (internal) — rutas locales de ROMs/saves/states, hash de ficheros, descarga.
- **ExternalEmulatorLauncher** (internal, tras una interfaz por SO) — entrega el ROM al emulador del
  dispositivo y detecta el fin de sesión.
- **PlaySessionTracker** (internal) — mide la duración y la reporta a RomM.
- **RommSyncEngine** (internal) — escanea saves/states locales, negocia con el servidor, ejecuta
  uploads/downloads, resuelve conflictos (conservador) y cierra sesión de sync.
- **[RomM API](/)** (external) — orquestador: decide qué subir/bajar; fuente de verdad de biblioteca.
- **[Emulator externo](/)** (external) — RetroArch u otro, ya instalado por el usuario.

**Decisión arquitectónica principal:** **delegar el emulador a un proceso externo** y **dejar la
decisión de sync al servidor** (negociación). Se elige porque respeta el protocolo oficial de RomM,
evita mantener cores y aísla el riesgo por SO tras una única interfaz `ExternalEmulatorLauncher`.
Alternativa viable: emulador embebido libretro — descartada en spec §Non-goals por coste.

**Decisión secundaria:** separar **auth (pairing)** de **sync**, para poder entregar y validar el
pairing sin esperar al motor de sync. La UI lee un único `rommRepositoryProvider`.

## 3. Interfaces & contracts

```text
RommRepository.deviceAuthInit(
    clientDeviceIdentifier, name, client, platform?, clientVersion?, requestedScopes[])
  -> DeviceAuthStart{deviceCode, userCode, verificationPath, verificationPathComplete, expiresIn, interval}
  - precondition: serverUrl configurada; scopes válidos
  - postcondition: petición pendiente en RomM (TTL 600 s), sin token aún

RommRepository.deviceAuthPoll(deviceCode)
  -> approved{accessToken, deviceId} | pending | slowDown | denied | expired
  - invariant: respeta el `interval`; `slow_down` sube el intervalo
  - postcondition: al aprobar, RomM ya creó Device + ClientToken ligado (no hace falta POST /api/devices)

RommAuthController.beginQrPairing(serverUrl, deviceName) -> DeviceAuthStart
RommAuthController.pollQrPairing(start) -> RommPairOutcome{approved|denied|expired|cancelled}
RommAuthController.cancelQrPairing() ; _commitPairedToken(...) persiste token + device_id

LocalGameStore
  .ensureRom(romId, downloadProgress) -> LocalRomPath | DownloadError
  .scanSavesAndStates() -> List<LocalAsset{romId, kind: save|state, file, mtime, sha1}>
  - precondition: disposición de almacenamiento; postcondition: ROM presente en disco

ExternalEmulatorLauncher
  .launch(romPath: String, platformSlug: String) -> SessionHandle | NoEmitterConfigured | LaunchFailed
  .whenSessionEnds(handle) -> Unit
  - plataformas: Android (intent a emulador), Windows (proceso configurable)
  - invariant: no bloquea el hilo de UI

PlaySessionTracker.start(romId) ; stop() -> PlaySession{romId, start, end, durationSeconds}

RommSyncEngine.sync(deviceId, localAssets) -> SyncReport
  - interna: negotiate -> execute(op) -> complete(sessionId, completed, failed, playSessions)
  - op.kind: upload | download | conflict | noop
  - invariant: conflicto => conservar ambas, nunca sobrescribir
  - postcondition: SyncReport{subidos, bajados, conflictos, errores}
```

## 4. Data model & flow

**Entities**

- **RommConfig** — serverUrl, deviceId; token en secure storage.
- **DeviceRecord** — id remoto, name, osPlatform, syncMode, paths (roms/saves/states).
- **LocalRom** — romId, ruta local del ROM, platformSlug.
- **LocalAsset** — romId, kind (save|state), fichero, mtime, sha1.
- **SyncOp** — kind, romId, source/destination.
- **PlaySession** — romId, start, end, durationSeconds.

**Flujo principal (jugar y sincronizar)**

1. GameDetail "Jugar" → `LocalPlayOrchestrator` comprueba si el ROM está en local.
2. Si falta → `LocalGameStore.ensureRom` descarga con progreso (`AppLoader`/barra); si ya está, salta.
3. `ExternalEmulatorLauncher.launch(romPath, platformSlug)` abre el emulador configurado.
4. Al volver / cerrar sesión → `PlaySessionTracker.stop()`.
5. `RommSyncEngine.sync` negocia con el servidor, ejecuta subidas/bajadas, conserva conflictos.
6. Se envía la `PlaySession` a RomM y se refresca "Continuar jugando".

- Consistencia: descarga y escritura local son locales; el estado autoritativo vive en RomM. El sync
  es "eventualmente consistente" entre sesiones.
- Migración: nuevas claves en prefs (deviceId de RomM) y almacenamiento seguro; sin backfill.

## 5. Testing strategy

> Constitución principio 6: **no se escriben tests salvo petición explícita**. Por tanto la
> estrategia es verificación manual + `flutter analyze`, con evidencia registrada en el FTD.

| Criterio de aceptación | Nivel | Comprueba | Requiere real |
| --- | --- | --- | --- |
| spec §Acceptance #1-#2 (pairing) | manual | canje de código, error de caducidad | servidor RomM real |
| spec §Acceptance #3-#4 (descarga + emulador) | manual | descarga con progreso, apertura del emulador | dispositivo + emulador |
| spec §Acceptance #5 (sesión) | manual | playtime registrado en RomM | servidor RomM real |
| spec §Acceptance #6-#7 (saves/states + conflicto) | manual | subida/bajada y conservación de conflicto | servidor + 2º dispositivo |
| spec §Acceptance #8 (offline) | manual | jugar descargado sin servidor | red desactivada |

- Línea e2e: manual sobre dispositivo real (no hay runner e2e en el repo).
- Dependencia real obligatoria: el servidor RomM 5.x del usuario, para validar endpoints y scopes.

## 6. Sequencing & dependencies

1. **Pairing (auth por código)** — depends on: none — [serial]. Independiente y entregable.
2. **Registro de dispositivo** — depends on: #1 — [serial].
3. **Descarga local + lanzador de emulador** — depends on: #2 — [parallelizable con #4].
4. **Motor de sync saves/states** — depends on: #2 — [parallelizable con #3].
5. **Play sessions + UI de sync/historial** — depends on: #3, #4 — [serial].
6. **i18n ARB + pulido UX (EasyLoading/AppLoader/Hover)** — depends on: #1-#5 — [serial].

- Paralelizables: #3 y #4 (sin estado compartido salvo `RommRepository`).
- Orden duro: #2 necesita el token de #1; #5 necesita ambos caminos.

## 7. Risks & open decisions

**Risks**

| Riesgo | Disparador | Impacto | Mitigación / spike |
| --- | --- | --- | --- |
| Payload/rutas exactas del pairing difieren en el server | Primer `exchange` real | Bloquea #1 | Verificar `{server}/openapi.json` antes de codificar; spike con curl |
| Scopes insuficientes del token | 403 en devices/sync | Bloquea #2/#4 | Guiar scopes al crear el token; mensaje claro ante 403 |
| Mapeo de rutas de saves/states por emulador/SO | Fase #4 | Sync incompleto | Config de rutas editable; empezar por un emulador por SO |
| Lanzamiento externo en Windows (ruta del exe) | Fase #3 | No lanza | Ajuste de ruta del emulador configurable |
| Límite de subida del reverse proxy | Subir save grande | Subida rechazada | Mensaje de límite; documentar `client_max_body_size` |
| Endpoints ausentes en una build RomM antigua | Servidor no 5.x | Bloquea pairing/sync | Chequeo runtime + fallback API Key |

**Open decisions**

- Emulador(es) concretos a soportar por SO — se cierra al iniciar #3.
- Formato de nombres de save por emulador — se cierra en #4 (ver Grout como referencia).

## Tasks
<!-- generated by tasks on 2026-10-01; IDs are stable, do not renumber -->

> Done-checks: el repo **no escribe tests salvo petición** (constitución principio 6). El check
> ejecutable es `flutter analyze` sobre los ficheros tocados; el resto es observación manual en
> dispositivo, registrada en el FTD del feature.

| ID | [P] | Task | Done-check | Depends-on | Trace |
| --- | --- | --- | --- | --- | --- |
| T001 |  | Spike: confirmar endpoints/payload de pairing y device en `{server}/openapi.json`; escribir FTD | `openapi.json` descargado; payload de `exchange`/`devices` anotado en el FTD | — | spec §Acceptance #1 |
| T002 | [P] | Añadir cadenas ARB del pairing (EN+ES) y regenerar | claves presentes en ambos `.arb`; `flutter analyze` limpio | — | spec §Behaviour |
| T003 |  | Implementar `deviceAuthInit`/`deviceAuthPoll` en el repositorio | `flutter analyze` limpio; `init` devuelve `user_code`/`verification_path` y el poll cambia de estado | T001 | spec §Acceptance #1 |
| T004 |  | Cablear `beginQrPairing`/`pollQrPairing` + diálogo QR en `games_panel` | `flutter analyze` limpio; pairing real por QR conecta sin API key | T002, T003 | spec §Acceptance #1-#2 |
| T005 |  | Persistir `device_id` (string) que RomM crea al aprobar | `flutter analyze` limpio; dispositivo visible en RomM | T004 | spec §Acceptance #1 |
| T006 |  | `LocalGameStore`: rutas locales, hash y descarga de ROM | `flutter analyze` limpio; ROM descargado y presente en disco | T005 | spec §Acceptance #3-#4 |
| T007 | [P] | `ExternalEmulatorLauncher` (Android intent / Windows proceso) + config de emulador | `flutter analyze` limpio; emulador abre el ROM | T005 | spec §Acceptance #3 |
| T008 |  | `PlaySessionTracker`: medir y reportar `play_sessions` | `flutter analyze` limpio; playtime visible en RomM | T007 | spec §Acceptance #5 |
| T009 | [P] | `RommSyncEngine`: negotiate/execute/complete (saves+states, keep-both) | `flutter analyze` limpio; subida/bajada reales; conflicto conserva ambas | T005 | spec §Acceptance #6-#7 |
| T010 |  | UI de sync (botón manual + auto al cerrar sesión) + SyncedGames/History | `flutter analyze` limpio; sync manual y automático disparan | T008, T009 | spec §Acceptance #5-#7 |
| T011 |  | Ajuste de emulador por SO en Ajustes (ruta Android/Windows) | `flutter analyze` limpio; ruta elegida persiste | T007 | spec §Acceptance #3 |
| T012 |  | Cerrar: FTD actualizado + todos los done-checks | `flutter analyze` limpio repo-wide; FTD con evidencia | all | spec §Acceptance |

### Per-task Interfaces (contexto aislado)

**T003 — Interfaces**
- Consumes: `RommRepository(serverUrl)`.
- Produces: `deviceAuthInit(...) -> RommDeviceAuthStart`; `deviceAuthPoll(deviceCode) ->
  RommDeviceAuthPollResult{approved, accessToken?, deviceId?, status?}`.

**T005 — Interfaces**
- Consumes: token y `device_id` del DeviceAuthTokenResponse; `getOrCreateDeviceId()`.
- Produces: `romm.device_id` (string) en `RommStorage`.

**T009 — Interfaces**
- Consumes: `deviceId` de T005; `LocalAsset{romId, kind, file, mtime, sha1}` de T006.
- Produces: `sync(deviceId, assets) -> SyncReport{subidos, bajados, conflictos, errores}`.

## Review Workload Forecast

| Dimension | Forecast | Why |
| --- | --- | --- |
| Estimated changed lines | 1200-1800 | pairing + device + store + launcher + sync engine + UI + ARB |
| Files / areas | ~14-18 | `features/games/{data,application,presentation}`, `settings`, `core/storage`, ARB, FTD |
| Review risk | high | protocolo de red, auth, filesystem, emulador por SO |
| Suggested delivery | worktree + rama propia, `ask-on-risk` | supera el `line_budget` (400) y toca muchas áreas |

- Recomendado: aislar en rama/worktree y entregar por fases (T001-T005 primero; T006-T012 después).

