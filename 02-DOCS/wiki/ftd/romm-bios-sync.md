# Intent
Sincronizar las BIOS/firmware de RomM al cliente de forma **explícita y completa** (dirección RomM → cliente), en lugar de la descarga perezosa por plataforma que solo ocurre al pulsar Jugar.

# Scope
- In: acción "Sincronizar BIOS" en Ajustes → Juego online; listado completo `RommRepository.getFirmware()` + descarga con progreso al directorio `bios/` de `LocalGameStore`; `BiosSyncController`/`biosSyncProvider`; ARB EN+ES; `AppLoader` durante la operación y `EasyLoading` para el resultado.
- Out: **subida** de BIOS locales a RomM (fase posterior); sync de saves/states (T009/T010 del SDD `romm-local-play-sync`); sincronización de cores/emuladores (descartado: solo aplica a juego en navegador); biblioteca de juegos (ya es descarga bajo demanda).

# Checklist
- [x] FTD redactado antes del primer cambio
- [x] `RommRepository.downloadFirmware(...)` con `onReceiveProgress`
- [x] `BiosSyncController` + `biosSyncProvider` (estado running/done/total)
- [x] Card "Sincronizar BIOS" en `games_panel` (solo si autenticado)
- [x] Cadenas ARB EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

# Evidence
- API RomM confirmada: `GET /api/firmware?platform_id=` (listar) y `GET /api/firmware/{id}/content/{file_name}` (descargar); scope `firmware.read` ya solicitado en `kRommRequestedScopes` (no requiere re-emparejar).
- `getFirmware({platformId})` ya existe (`romm_repository.dart:1450`); `firmwareDownloadUrl` en `romm_repository.dart:1475`.
- Base previa: `LocalPlayController._ensureBios` (`romm_providers.dart:380`) baja por plataforma al jugar; `LocalGameStore.biosDir()` (`local_game_store.dart:97`).
- Implementación 2026-10-03:
  - `romm_repository.dart`: `downloadFirmware({id, fileName, savePath, onProgress})`.
  - `application/bios_sync_controller.dart` (nuevo): `BiosSyncState`/`BiosSyncResult` + `BiosSyncController.sync()`; recorre `getFirmware()` completo, omite `missingFromFs`, deduplica por nombre, salta existentes y descarga el resto en `bios/`; expone progreso.
  - `games_panel.dart`: card `_BiosSyncCard` bajo el estado de conexión, con `AppLoader` mientras corre y `EasyLoading` (success/info/error) al acabar.
  - ARB EN+ES: `rommBiosSyncTitle/Help/Button/Running/Done/UpToDate/Error/Login`.
- Verificación: `flutter gen-l10n` OK; `flutter analyze` → "No issues found! (ran in 3.2s)".

# Next (PENDIENTE — 2026-10-03)
- **BIOS subida (RomM ← cliente)**: no implementada. Decisión tomada: "solo bajar por ahora". Cuando se retome, hay que elegir el mapeo archivo→plataforma (match por nombre / manual / tabla) y añadir el scope `firmware.write` a `kRommRequestedScopes` → **requiere re-emparejar** el dispositivo.
- **Verificación manual BIOS**: pulsar "Sincronizar BIOS" contra RomM real y comprobar que los ficheros aparecen en `<AppPaths>/bios/`.
- Fase 2 (saves/states) ya hecha: `02-DOCS/wiki/ftd/romm-saves-sync.md`.
