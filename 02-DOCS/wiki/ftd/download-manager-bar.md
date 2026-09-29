# Intent
Barra inferior estilo Steam de gestión de descargas: al descargar un contenido (ROM o vídeo) aparece con progreso, velocidad, tiempo restante y botones pausar/reanudar/cancelar. Si el miniplayer suena, queda encima del gestor; ambos abajo.

# Scope
- Nuevo `lib/features/downloads/` (domain + application + presentation). Solo `home_shell.dart` (apilado + FAB pad), `game_detail_screen.dart` e `item_detail_screen.dart` (migran sus descargas al gestor), ARB EN+ES.
- No se tocan skins, `PrimeCardBadge`, resto de pantallas. Sin persistencia (cola solo en sesión). Sin tests (norma). Sin `flutter build`.

# Checklist
- [x] `domain/download_task.dart` (modelo + status + formatos)
- [x] `application/download_manager_provider.dart` (Notifier, enqueue/pause/resume/cancel, Dio+CancelToken+Range, throttle)
- [x] `presentation/download_manager_bar.dart` (filas paralelas estilo Steam)
- [x] Apilado en `home_shell.dart` + `bottomPad` FAB
- [x] Migrar ROM (`game_detail`) y vídeo (`item_detail`); fix `\\` → `pathSeparator` (ruta ahora en el provider); EasyLoading en vez de ScaffoldMessenger
- [x] ARB EN+ES + `flutter gen-l10n` + `flutter analyze` limpio

# Evidence
- `flutter gen-l10n` (28/09/2026): getters `downloadResume/downloadOf/downloadTimeLeft/...` generados en `app_localizations.dart`.
- `flutter analyze --no-pub` (28/09/2026): `No issues found!`. En el camino se cazó y corrigió un import relativo mal (`../../domain` → `../domain` en la barra).
- Alcance paralelo + solo sesión según respuestas del usuario; `Range`-resume con fallback a reinicio limpio si el servidor ignora el rango.
- Fix 28/09/2026 (fallo al descargar): el toast mostraba solo el genérico. Ahora incluye el motivo (`HTTP <código>: <mensaje>`), el `downloadUrl` codifica por segmentos (las `/` de subcarpetas ya no dan 404), el nombre en disco se sanea para Windows y el icono de error lleva tooltip con el motivo. `analyze` sigue limpio.
- Diagnóstico 28/09/2026 (sigue fallando sin motivo visible): traza `[DownloadManager]` en consola (inicio con URL/destino/auth, fallo con status/tipo/mensaje/extracto de respuesta). Pendiente que el usuario pegue esas líneas para ver la causa real.
- Causa raíz 28/09/2026 (log del usuario): `404 {detail: ROM 8758 has no file to download}`. Verificado en el fuente de ROMM (`backend/endpoints/roms/__init__.py::get_rom_content`): el endpoint es correcto, pero el servidor eleva ese 404 cuando `rom.has_file_on_disk` es falso (el fichero no está en disco según su escaneo). No es bug del cliente. Además `_reason` mostraba el texto genérico de Dio en vez del `detail` del servidor (por eso "no pone por qué"): ahora prioriza `response.data.detail`. `analyze` limpio.
- Velocidad 28/09/2026 (clavada en 56,3 kB/s): el umbral `dt > 0.05` congelaba la EMA en redes rápidas. Cambiado a ventana deslizante de 3 s (`_samples`). `analyze` limpio.
- Aviso de destino 28/09/2026: al completar, el toast muestra `Descarga completada` + ruta final en segunda línea (`doneMessage\nsavePath`, reutiliza ARB existente). `analyze` limpio.

# Next
- Tras v1 sesión: persistencia de cola y reintento con `Range` si se pide.
