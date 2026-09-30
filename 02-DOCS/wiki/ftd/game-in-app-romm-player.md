# Intent
Abrir el juego en una pantalla in-app (estilo "jugar en RomM") al pulsar Jugar en las plataformas EmulatorJS, en lugar de abrir el host/streaming en el navegador externo. Objetivo: reproductor a pantalla completa dentro de fynitiv reutilizando RomM lo máximo posible.

# Scope
- In (propuesto, pendiente de decidir): dependencia `webview_all: ^1.4.3`; pantalla `game_player_screen.dart` (WebView fullscreen + barra superior volver/recargar/abrir en navegador); ruta raíz `/games/player/:romId` en `app_router.dart`; `_play()` en `game_detail_screen.dart:142` navega a la pantalla y mantiene `markPlayed`; i18n EN+ES + `gen-l10n`.
- Out: aún nada implementado (solo este documento). No se toca `PrimeCardBadge` ni hovers.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [ ] Decidir enfoque A / B / C (ver `Evidence`)
- [ ] Validar persistencia de la cookie `romm_session` en WebView (Android/Windows)
- [ ] Implementar pantalla + ruta + enganche del botón
- [ ] `flutter analyze` limpio

# Evidence
Contexto verificado (docs RomM 5.0.0 + código del frontend + capability matrix de `webview_all`):
- Estado actual: el botón Jugar de `game_detail_screen.dart:142` llama a `claimStreamingSession()` y abre con `launchUrl` externo; solo aparece si `isEmulatorJsPlayable(platformSlug)` (`game_detail_screen.dart:657`). El badge verde de plataformas (`games_screen.dart:789`) usa el mismo helper.
- Auth RomM (`docs.romm.app/5.0.0/developers/api-authentication`): la **API** acepta `Authorization: Bearer rmm_...` (Client API Token) / OAuth2 JWT; la **página del SPA** `/rom/{id}/ejs` se autentica con la cookie **`romm_session`** creada solo por `POST /api/auth/login` (usuario/contraseña) o OIDC. No hay canje documentado de API key → sesión.
- Assets: RomM sirve EmulatorJS en `/assets/emulatorjs/data/…` (nginx `location /assets`, sin auth). El player hace `GET /api/roms/{id}/content/{file}` same-origin (EmulatorJS descarga el ROM entero; es WASM).
- `webview_all` soporta Android (WebView) y Windows (WebView2), con `WebViewCookieManager` (inyección de cookies) y `loadRequest` con headers; Windows expone cookie extendida y callback SSL recuperable.
- Opciones evaluadas:
  - A. Página de RomM + login manual una vez en el WebView (no se guarda contraseña). Riesgo: persistencia de cookie de sesión.
  - B. Página de RomM + auto-login con usuario/contraseña guardados (`POST /api/auth/login` + inyección de cookie).
  - C. EmulatorJS propio con ROM como blob (solo API key). Descartada de momento: descarga completa cada vez (sin caché reutilizable), requiere instancia/assets propios de EmulatorJS (~cientos de MB o CDN) y no usa RomM (perdería core/BIOS/saves/netplay).

# Next
Decidir A / B / C con el usuario. Si A: implementar `webview_all` + `GamePlayerScreen` + ruta `/games/player/:romId` + enganche en `_play`, y validar si `romm_session` persiste entre reinicios (Android/Windows). Si el login se hace pesado, pasar a B.
