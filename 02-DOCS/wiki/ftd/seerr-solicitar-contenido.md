# Intent
Solicitar contenido desde la ficha de Seerr no llegaba a Seerr: el botón (`_requestSeerr`) llamaba a `POST /api/v1/request` y cualquier rechazo se mostraba como un toast genérico ("No se pudo enviar la petición"), sin motivo, sin refrescar el estado y sin rastro de la petición en la pestaña Peticiones (el provider está cacheado y nadie lo invalidaba).

Revisado el contrato real de Seerr (`seerr-api.yml`, `server/routes/request.ts`, `server/entity/MediaRequest.ts`, `server/index.ts`):
- El cuerpo que mandábamos es correcto (`mediaType`, `mediaId` = TMDB id, `seasons: 'all'` → `MediaRequest.request` lo expande y filtra especiales). **Verificado además con un servidor eco local que Dio 5.11 ya envía `application/json` para `Map`** (`ImplyContentTypeInterceptor`), así que el formato del cuerpo NO era la causa.
- Rechazos posibles: 401 sin sesión; 403 permiso (`REQUEST`), cuota o lista negra; **403 de la protección CSRF** (`csurf` exige `_csrf` + `X-XSRF-TOKEN` en POST/PUT/DELETE cuando `network.csrfProtection` está activo — el cliente no los enviaba nunca); 409 duplicada; 202 sin temporadas disponibles; 500.
- `createRequest` devolvía `bool`, así que todo lo anterior terminaba en el mismo toast opaco.

# Scope
- `lib/features/seerr/data/seerr_api.dart`:
  - Bote de cookies en el cliente (`connect.sid`, `_csrf`, `XSRF-TOKEN`…) alimentado desde `set-cookie` con un interceptor; la cabecera `Cookie` se compone del bote (con respaldo a la credencial cruda si no tiene formato `name=value`).
  - `X-XSRF-TOKEN` en métodos no seguros cuando existe `XSRF-TOKEN`; si no existe, `GET /status` de primado antes del POST (obtiene el par `_csrf`/`XSRF-TOKEN`). Soporta servidores con CSRF activo, que antes rechazaban el POST con 403.
  - `createRequest` pasa a `Future<void>` y lanza `SeerrException` con el motivo real (`forbidden`, `quota`→`forbidden`, `duplicate`, `noSeasons`, `csrf`, `unauthorized`, `http`) y el `message` de Seerr.
  - `_classify` distingue 5xx (`badResponse`) de error de red.
  - `contentType: application/json` explícito en cuerpos (explícito > implícito), sin cambio de comportamiento verificado.
- `lib/features/library/presentation/item_detail_screen.dart`:
  - `_requestSeerr` refresca ficha, metadatos, estado en biblioteca y lista de peticiones; toast traducido por motivo (info si ya estaba pedida / sin temporadas).
  - Chip de estado ("Solicitada"/"Procesando"/"Disponibilidad parcial"/"Disponible") en lugar del botón cuando Seerr ya tiene la petición, en vez de ofrecer "Solicitar" otra vez.
- `lib/features/seerr/presentation/seerr_screen.dart`: la pestaña Peticiones invalida su provider al abrirse; casos nuevos del enum en el mapa de errores.
- `lib/l10n/app_en.arb` + `app_es.arb`: 5 claves de error nuevas (`seerrRequestAlreadyRequested`, `seerrRequestNoSeasons`, `seerrRequestQuota`, `seerrRequestForbidden`, `seerrRequestCsrf`); se reutilizan `seerrRequestSuccess/Error`, `seerrStatus*`, `seerrCertError`, `seerrNetworkError`. `flutter gen-l10n` ejecutado.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Bote de cookies + cabecera CSRF en `SeerrApi`
- [x] `createRequest` con motivo real del error
- [x] ARB (en/es) + `flutter gen-l10n`
- [x] Refresco de estado tras solicitar + chip de estado
- [x] `flutter analyze` limpio

# Evidence
- Contrato verificado en la fuente de Seerr: `seerr-api.yml` (`POST /request`: `mediaType`, `mediaId`, `seasons` array|'all', 201; `quickconnect/authenticate` exige `application/json`), `server/routes/request.ts` (401/403/409/202), `server/entity/MediaRequest.ts` (`seasons === 'all'`, permisos `REQUEST*`, cuota), `server/index.ts` (`csurf` condicionado a `network.csrfProtection`; errores `{ message }`).
- `csurf@1.11.0`: 403 `EBADCSRFTOKEN` si falta el token → de ahí el soporte de `_csrf`/`X-XSRF-TOKEN`.
- Comprobación puntual (fuera del repo, ya borrada): servidor HTTP local + Dio 5.11 → el `Map` se envía como `application/json` con y sin `contentType` explícito ⇒ se descarta el formato del cuerpo como causa.
- `flutter analyze` (proyecto completo): `No issues found!`.
- Sin `flutter build` (norma del proyecto); sin tests (no pedidos).

# Next
- Si sigue sin llegar, el toast ya dirá el motivo exacto de Seerr (permiso, cuota, duplicada, CSRF) y se ajusta en consecuencia.
