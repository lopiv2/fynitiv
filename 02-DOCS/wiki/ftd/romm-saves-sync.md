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
