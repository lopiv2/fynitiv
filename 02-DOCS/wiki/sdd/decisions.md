# Decisiones SDD (append-only)

Registro de decisiones significativas del ciclo SDD: fecha, opciones consideradas y por qué.

## 2026-10-01 — Arranque SDD y arquitectura de juego local

- **Contexto:** el usuario quiere emparejar fynitiv con RomM para jugar ROMs **en local** y
  sincronizar juegos, sesiones y partidas.
- **Opciones consideradas:**
  1. Emulador embebido con libretro/FFI dentro de Flutter.
  2. **Modelo Argosy:** descargar el ROM y delegar en un emulador externo; sync vía Device Sync
     Protocol de RomM.
  3. Mantener solo el juego en navegador actual + API Key manual.
- **Decisión:** opción 2 (modelo Argosy), orquestada con SDD.
- **Por qué:** reutiliza el protocolo oficial de RomM y el cliente oficial Android (Argosy) como
  referencia; evita mantener cores de emulación; cubre el objetivo de continuidad de partidas.
- **Verificación de endpoints:** emparejamiento `POST /api/client-tokens/exchange`, registro
  `POST /api/devices`, sync `POST /api/sync/negotiate` + `/api/sync/sessions/{id}/complete`.
  Docs RomM latest/5.0.0. El servidor del usuario es RomM 5.x reciente.
- **Pendiente:** ratificación de la constitución v1.0.0; resolución de los puntos a aclarar del spec
  `romm-local-play-sync`.

## 2026-10-01 — Clarificación del spec y arranque de la implementación

- **Ratificada** la constitución v1.0.0 (20 principios + Definition of Done).
- **Respuestas de clarificación:** plataformas Android + Windows; sync de saves **y** states; sync
  manual + automático al cerrar sesión; conflictos **conservar ambas sin sobrescribir**.
- **Aislamiento:** rama `feat/romm-local-play-sync` (estábamos en `main`).
- **Implementado (T001-T005):** pairing por código (`exchangePairingCode`, `pairWithCode`, UI en
  `games_panel`), registro de dispositivo best-effort (`registerDevice`,
  `ensureDeviceRegistered`), `romm.device_id` en `RommStorage`, cadenas ARB EN+ES.
- **Decisión:** el token del pairing se reutiliza en el slot de la API Key (`useApiKey: true`) para no
  duplicar la ruta de auth; la API Key manual se mantiene como fallback.
- **Verificación:** `flutter analyze` → "No issues found!".

## 2026-10-01 — Cambio de pairing code a device authorization con QR

- **Hallazgo:** RomM 5.3.1 (tu servidor) implementa el *device authorization flow* (RFC 8628):
  `POST /api/auth/device/init` (abierto) + polling `POST /api/auth/device/token`; la aprobación
  web (`/pair/device`) crea el **Device + ClientToken ligado**. Confirmado en `backend/endpoints/
  device_auth.py` de la etiqueta 5.3.1.
- **Decisión:** implementar **QR en fynitiv** y **eliminar** el pairing code clásico
  (`/api/client-tokens/exchange`) y el registro manual (`POST /api/devices`). Además corrige el bug
  detectado (el `exchange` devolvía `raw_token`, no las claves que se leían).
- **UI:** el QR lo **pinta fynitiv** y lo escanea el móvil (logueado en RomM); no requiere cámara.
  Alternativa: abrir el enlace `/pair/device` en el navegador o teclear el `user_code`.
- **Dependencias añadidas:** `qr_flutter`, `package_info_plus`.
- **Scopes solicitados:** `roms.read`, `devices.read`, `devices.write`, `assets.read`, `assets.write`,
  `me.read`, `me.write`.
- **Verificación:** `flutter analyze` → "No issues found!".

## 2026-10-01 — Bloques 1-3: quitar API Key, descarga local y lanzador de emulador

- **Bloque 1:** se elimina el modo API Key manual (el token del QR ocupa el mismo rol). `RommConfig`
  se simplifica a `{serverUrl, token}`; scopes del QR ampliados (`platforms.read`, `roms.user.*`,
  `firmware.read`…) para cubrir lo que la app ya usa (arregla 403 latente).
- **Bloque 2:** `LocalGameStore` con raíz configurable y extracción `.zip`; el gestor de descargas
  admite `destinationDir`.
- **Bloque 3:** `EmulatorLauncher` Android (RetroArch intent + mapa de cores) y Windows (exe+args);
  `LocalPlayController` orquesta descargar→extraer→lanzar. Botón "Jugar" ahora local, con fallback a
  streaming si no hay emulador. Config de emulador en Ajustes.
- **Pendiente:** play sessions (T008), motor de sync saves/states (T009), UI de sync (T010).
- **Verificación:** `flutter analyze` limpio tras cada bloque.

## 2026-10-01 — Pestaña Emuladores, Jugar universal y BIOS

- **Pestañas** en Juego online: **Juegos | Emuladores**; en Emuladores, por plataforma: emulador
  recomendado por SO, enlace de descarga, selector de asociación (persistida) y estado instalado
  (autodetectado en Android con `installed_apps` + `<queries>`).
- **Catálogo** en JSON local (`assets/data/emulators.json`), editable sin recompilar; modelos+loader.
- **Jugar para todas las plataformas** (`game.firstFile != null`), junto a Descargar.
- **Streaming/navegador eliminado** de la UI (badge y `_play`); quedan métodos dormidos en el
  repositorio sin exponer.
- **BIOS + layout lógico** `roms/<slug>/`, `bios/`, `saves/`, `states/`; descarga de firmware de RomM
  al jugar; RetroArch recibe un `CONFIGFILE` que apunta esas carpetas (base del sync).
- **Windows**: ruta del `.exe` por emulador (selector de fichero); sin autodetección fiable.
- **Verificación:** `flutter analyze` → "No issues found!".



