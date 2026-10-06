# Live TV — error 500 de PlaybackInfo no controlado

## Intent
Un `DioException [bad response] 500` del `POST /Items/{id}/PlaybackInfo`
(`getPostedPlaybackInfo`) al abrir un canal de Live TV se propagaba sin capturar desde
`resolveLiveChannelStreamUrl` (se llamaba fuera del `try` de `playChannel`), tumbando la app
con "Unhandled Exception".

## Scope
- In: capturar el fallo de la llamada de resolución del stream, registrarlo con el cuerpo de
  error del servidor y dejar que la UI muestre "sin URL de stream"; sin cambiar el protocolo.
- Out: arreglar la causa del 500 (servidor/tuner); perfiles de dispositivo; reintentos.

## Checklist
- [x] FTD antes del primer cambio
- [x] `resolveLiveChannelStreamUrl` devuelve `null` ante `DioException` (no lanza)
- [x] Log con status + cuerpo recortado del error
- [x] `flutter analyze` limpio

## Evidence
- El error venía de `live_tv_player_provider.dart:81` (`getPostedPlaybackInfo`) sin `try` en
  `playChannel` (`:357`). Ahora la llamada está envuelta en `try/on DioException` y devuelve
  `null`; `playChannel` ya gestiona el `null` con `error: 'Sin URL de stream'`.
- `_snippet(...)` recorta el cuerpo para el log `LiveTV`.
- `flutter analyze` → `No issues found!`.

## Next
- Reproducir el canal y leer el log `LiveTV` (o los logs del servidor Jellyfin) para ver el
  mensaje exacto del 500. Si el POST falla siempre sin `DeviceProfile`, probar un perfil
  mínimo o un fallback a `getPlaybackInfo` (GET).
