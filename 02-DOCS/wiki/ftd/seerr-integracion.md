# Seerr — integración (Quick Connect, búsqueda, próximos, peticiones)

## Intent
Convertir la pantalla placeholder `Seerr` en un centro de descubrimiento y peticiones:
conexión al servidor Seerr (Quick Connect con QR o login), buscador, próximos (TMDB vía
Seerr), y gestión de peticiones.

## Scope
- In:
  - Configuración persistente: URL de Seerr (SharedPreferences) + sesión (cookie
    `connect.sid` en `flutter_secure_storage`).
  - Quick Connect: `POST /auth/jellyfin/quickconnect/initiate` → `code`/`secret`; QR con el
    código; `GET .../check?secret=` (polling) y `POST .../authenticate`.
  - API Seerr (`/api/v1`) con cookie de sesión.
  - Pantalla: setup (URL + conectar), y principal con buscador, tabs Próximos / Buscar /
    Peticiones.
  - Próximos: `/discover/movies/upcoming` + `/discover/tv/upcoming`.
  - Búsqueda: `/search?query=`.
  - Peticiones: `/request` (list) y `POST /request` (crear).
  - Ficha Seerr (`/seerr/:mediaType/:id`).
- Out:
  - Login Plex, gestión de usuarios/permisos de Seerr, notificaciones.

## Checklist
- [x] FTD antes del primer cambio (este documento)
- [x] Modelos + `SeerrApi`
- [x] Controlador de config/sesión + Quick Connect
- [x] Pantalla Seerr (setup + tabs + buscador)
- [x] Ficha + crear petición + ruta
- [x] ARB + `flutter analyze`

## Evidence
- Seerr API: auth cookie (`connect.sid`)/`X-Api-Key`; Quick Connect endpoints
  (`/auth/jellyfin/quickconnect/initiate|check|authenticate`).
- `SeerrApi`: cliente Dio (`/api/v1`) con cookie o API key; `status`, Quick Connect, detalle,
  `discover/{movies|tv}/upcoming`, `search`, `request` (crear/listar).
- `seerrConnectionProvider`: URL en `SharedPreferences`, credencial en `flutter_secure_storage`.
- `SeerrScreen`: sin conexión muestra setup (URL + Quick Connect con QR `qr_flutter` + API key);
  con conexión, tabs Próximos (movies+tv) / Buscar (debounce 400ms) / Peticiones.
- `SeerrDetailScreen` (`/seerr/:mediaType/:id`): ficha + Solicitar (series → `seasons: all`) +
  "Dónde ver/comprar" desde `watchProviders` de Seerr.
- `flutter analyze` → `No issues found!`.

## Fix — `type 'String' is not a subtype of type 'Map'` al pulsar Quick Connect
- Causa: `initiateQuickConnect` casteaba `res.data` a `Map` sin comprobar; si el servidor
  devolvía algo no-JSON (URL errónea, 404/HTML, versión de Seerr sin el endpoint) llegaba un
  `String` y el cast lanzaba.
- Fix: `SeerrApi` ahora valida (`status` 200 + respuesta JSON, tolerando `String` vía
  `jsonDecode`) y lanza `SeerrException` con mensaje legible (HTTP + cuerpo). El diálogo de
  Quick Connect hace prechequeo de `/status`: si falla → "No se pudo conectar con Seerr…".
  `_normalize` tolera que la URL venga con `/api/v1`.

## HTTPS / certificados (Traefik, autofirmados)
- La app no manejaba certificados TLS: Dio (`HttpClient`) rechazaba autofirmados/CA no
  confiable → "No se pudo conectar".
- `FynitivHttpOverrides` ahora acepta certificados no válidos según
  `FynitivHttpOverrides.allowBadCertificates` (por defecto **true**), aplicado a todo
  (`HttpOverrides.global` cubre Jellyfin, imágenes, ROMm y Seerr).
- Preferencia persistente "Aceptar certificados no válidos" (Preferencias) y lectura al
  arranque en `main.dart` antes de cualquier petición.
- Diagnóstico Seerr: `SeerrApi.assertReachable()` clasifica el error
  (`SeerrErrorKind.certificate|network|http|response`) y el diálogo muestra el mensaje
  traducido (certificado vs red/DNS).

## Fix — diálogo Quick Connect permanente (localizations en initState)
- `_QuickConnectDialog.initState` llamaba a `_start()`, que usa
  `AppLocalizations.of(context)` → `dependOnInheritedWidgetOfExactType` antes de terminar
  `initState` (excepción, el diálogo se quedaba fijo).
- Fix: `_start()` se difiere con `WidgetsBinding.instance.addPostFrameCallback`.

## Fix — 401 en `/status` (proxy con auth)
- `/status` es público en Seerr, así que un 401 indica una capa de autenticación delante
  (Traefik/Authelia/basic-auth). Se eliminó el prechequeo por HTTP de `/status` (bloqueaba
  el flujo); ahora se llama directamente a Quick Connect y se clasifica el error
  (`unauthorized` 401/403, `notFound` 404).
- Se añade **basic-auth por URL**: `https://user:pass@host` → el `user:pass` se extrae y se
  envía como `Authorization: Basic …` (útil para proxies con basic-auth). No ayuda con
  Authelia/forward-auth con redirección.

## Fix — "LayoutBuilder does not support returning intrinsic dimensions" en el diálogo
- `AlertDialog` mide su contenido por intrínsecos (`IntrinsicWidth`), y el contenido incluye
  `AppLoader`/`QrImageView`, que usan `LayoutBuilder` (no soporta intrínsecos) → excepción.
- Fix: el diálogo de Quick Connect ya no usa `AlertDialog` sino un `Dialog` propio con
  `ConstrainedBox(maxWidth: 340)`, que aporta constraints acotados sin calcular intrínsecos.

## Próximos reutilizando widgets existentes + ficha de la app
- **Reutilización (sin widgets nuevos)**:
  - `PosterCard`/`BackdropCard` ganan un `imageUrl` opcional (imagen externa TMDB).
  - `ContentRow` gana `imageUrlFor` (URL por item) y lo reenvía a las tarjetas.
  - La fila de Próximos (`SeerrMediaRow`) usa el **`ContentRow`** real (título `ScrollTitle`,
    hover universal, tamaños del skin), mapeando los items TMDB a `BaseItemDto` con
    `seerrMediaToBaseItem` (marcados `LocationType.virtual`).
  - La búsqueda usa `PosterCard` directamente (misma tarjeta).
  - Se eliminó `SeerrMediaCard` (custom) — no se duplican widgets.
- **Ficha = la de la app**: `SeerrDetailScreen` ahora carga el detalle de Seerr y renderiza
  `ItemDetailScreen` (misma pantalla por skin) con `backdropUrl` de TMDB. `ItemDetailScreen`
  gana `backdropUrl` opcional.
  - **Acciones**: en `ItemDetailScreen._DetailActions`, los items `seerr:<type>:<id>` muestran
  **Solicitar** con el mismo botón ancho que "Reproducir" (`_WideDetailButton`, que ahora
  acepta `background`/`foreground`) pero en **azul claro** (`0xFF7FD4FF`, texto negro) para
  distinguirse, o un chip "En tu biblioteca" si ya está (vía `jellyfinHasTmdbProvider`), y
  **Más opciones** abre un diálogo con los proveedores de Seerr para ver o comprar. Se ocultan trailer/favorito/descarga y
  también el badge "Se incluye con Jellyfin" + términos (no está en la biblioteca).
  `_DetailActions` pasa a `ConsumerStatefulWidget` para el estado de envío.
- Se retiraron los `debugPrint` de diagnóstico (Seerr y `[Upcoming]`).

## Tabs con el estilo de Live TV / Juegos
- Los tabs de Seerr (Próximos / Buscar / Peticiones) usan el `AppTabBar` común
  (`core/widgets/app_tab_bar.dart`), el mismo que Live TV (TV/Radio) y Juegos (Juegos/Emuladores),
  con icono + hover/foco del widget universal. Se eliminó el `_TabBar` con `ChoiceChip`.

## "Se incluye con Jellyfin" opcional en el hover
- El badge "Se incluye con Jellyfin" del panel de hover (Prime) pasa a ser opcional:
  `HoverPlayCard.showIncludedBadge` → `_HoverPanel`/`_ExpandedHoverCard`, expuesto por
  `PosterCard`/`BackdropCard` (`showHoverIncludedBadge`) y `ContentRow`.
- Se pone a `false` en las filas de Próximos y en la cuadrícula de búsqueda de Seerr
  (contenido externo, no está en la biblioteca). Por defecto `true` (resto de la app).

## Texto del botón del hover personalizable
- `HoverPlayCard.hoverActionLabel` (→ `_HoverPanel`/`_ExpandedHoverCard` → `WatchNowButton`)
  permite fijar el texto del botón principal del panel de hover. `null` = por defecto
  ("Reanudar" con progreso o "Ver ahora").
- Expuesto por `PosterCard`/`BackdropCard` (`hoverActionLabel`) y `ContentRow`, así cada fila
  puede poner el suyo. En Seerr (Próximos y búsqueda) se pasa `l10n.seerrRequest` ("Solicitar",
  cadena ARB existente).

## `seerrLayout` configurable por skin (pestaña "Descubrir")
- `Skin.seerrLayout` (como `homeLayout`/`vodLayout`): lista ordenable de
  `LayoutSection.seerrDiscover(category, [HomeScroll?])`. Categorías
  (`SeerrDiscoverCategory`): `trending`, `popularMovies`, `upcomingMovies`, `popularTv`,
  `upcomingTv`.
- API Seerr: `SeerrApi.discover(category)` →
  `/discover/trending`, `/discover/movies`, `/discover/movies/upcoming`, `/discover/tv`,
  `/discover/tv/upcoming`. Provider `seerrDiscoverProvider(category)`.
- UI: la pestaña (renombrada **"Descubrir"** / "Discover") recorre `skin.seerrLayout`
  (fallback a un orden por defecto) y pinta una `SeerrMediaRow(category, scroll)` por sección.
  La fila reutiliza `ContentRow`; el aspecto (póster/backdrop) sale de `scroll.cardType` o del
  skin.
- Presets **Prime y Disney** incluyen las cinco secciones (`_seerrDiscoverAll`).
- ARB: `seerrUpcomingTab` (valor ahora "Descubrir"/"Discover"), `seerrTrending`,
  `seerrPopularMovies`, `seerrUpcomingMovies`, `seerrPopularTv`, `seerrUpcomingTv`.
- `LayoutSectionType.seerrDiscover` se ignora en Home/VOD (solo aplica en Seerr).

## Logo de esquina: Jellyfin solo si está en la biblioteca; si no, plataformas
- `PosterCard`/`BackdropCard` aceptan `cornerLogos` (URLs) que, si vienen, se pintan en la
  esquina inferior derecha **en lugar** del `cardLogo` del skin. Widget reutilizable
  `ProviderLogoStrip` (`core/widgets`).
- `ContentRow.cornerLogosFor(item)` reenvía los logos por item.
- En Seerr (Descubrir y búsqueda) el `cardLogo` del skin se pone a `null` (no está en la
  biblioteca) y se pasan los logos de las plataformas donde se emite el título:
  `seerrDiscoverProvidersProvider` (por fila, en paralelo) y `tmdbWatchProvidersProvider`
  (por tarjeta en la búsqueda), filtrando a streaming (flatrate/free/ads). Requiere key TMDB.
- En la biblioteca, el logo de Jellyfin sigue mostrándose como antes.

## Fix — items no soportados en Tendencias y hover de botones anchos
- **Tendencias con items que fallaban**: `SeerrMedia.fromJson` ahora lee `mediaType` **o**
  `media_type`, y **descarta** resultados que no son película/serie (p. ej. `person`), que
  antes se colaban como `tv` y su detalle daba 404 (sin detalles ni botón Solicitar).
- **Hover en botones anchos**: nuevo `AppHoverEffect.invert` en el widget universal `AppHover`
  (invierte los colores con `ColorFilter.matrix` al hacer hover/foco). `_WideDetailButton`
  (Reproducir / Solicitar / Continuar sin anuncios / Más opciones…) usa ese efecto, así se ve
  claramente el estado seleccionado por inversión de colores.

## Fix — "En tu biblioteca" vs "Próximamente en tu biblioteca" (stubs `.disc`)
- Síntoma: al buscar en Seerr un título que ya está en la biblioteca **solo como stub**
  (`.disc` de Radarr/Sonarr, aún sin descargar), la ficha decía "En tu biblioteca".
- Fix: `jellyfinHasTmdbProvider` (bool) pasa a `seerrLibraryStatusProvider` →
  `SeerrLibraryStatus { none, placeholder, available }`. En la biblioteca busca por `TmdbId`
  (pide `providerIds`, `mediaSources`, `path`) y usa `isPlaceholderItem` para distinguir el
  stub; un título con media real prevalece sobre un stub del mismo título.
- UI (`_DetailActions`): `available` → chip "En tu biblioteca" (`seerrInLibrary`);
  `placeholder` → chip "Próximamente en tu biblioteca" (`seerrComingSoonInLibrary`);
  `none` → botón "Solicitar".
- `flutter analyze` → `No issues found!`.

## Fix — metadatos del detalle y acciones de series Seerr
- `SeerrMedia.fromDetailJson` ahora consume los campos de detalle de Seerr que no llegaban a la
  UI: `credits.cast/crew`, `productionCompanies`, `networks`, `contentRatings`, `releases`,
  `runtime`, `episodeRunTime` y `genres`.
- `seerrMediaToBaseItem` los convierte a los tipos que ya usa la pantalla común: `BaseItemPerson`
  (director, producer, creator, actor), `NameGuidPair` (estudios), `officialRating`, `genres` y
  `runTimeTicks`. Así la clasificación, género, duración, dirección, productores, reparto y
  estudio aparecen tanto en el resumen como en la pestaña Detalles.
- Los proveedores ya no ocupan espacio fijo bajo la sinopsis: el botón "Más opciones" abre un
  `Dialog` con `SeerrWatchProvidersView`, incluyendo sus enlaces de streaming/compra.
- Las series Seerr virtuales también reciben `_DetailActions` dentro de `_DisneySeriesBody`,
  evitando que desaparezcan Solicitar y Más opciones en ese flujo de detalle.
- `flutter analyze` → `No issues found!`.

## Eliminada la capa TMDB de la app (BYO-key)
- Seerr ya entrega todos los datos necesarios (ficha con `watchProviders` de la región),
  así que se elimina la API key propia y toda la capa TMDB:
  - Borrados: `core/settings/tmdb_key_controller.dart`, `features/discover/**`
    (`tmdb_api`, `tmdb_providers`, `tmdb_models`, `tmdb_poster_card`, `tmdb_detail_screen`,
    `where_to_watch`), `core/widgets/provider_logo_strip.dart`, ruta
    `/discover/:mediaType/:id` y el campo de key en Preferencias.
  - ARB: se retiran `tmdbApiKey`, `tmdbApiKeyHint`, `tmdbApiKeyExample`, `viewOnTmdb`,
    `tmdbPoweredBy`. Se conserva `tmdbAttribution` (los datos siguen viniendo de TMDB vía
    Seerr) en la ficha de Seerr y en "Acerca de".
  - `core/i18n/locale_regions.dart` (nuevo): `regionForLocale(Locale)` para pedir los
    proveedores de la región correcta en `seerrDetailProvider`.
  - "Dónde ver" (ficha de Seerr) usa el nuevo `SeerrWatchProvidersView`
    (`features/seerr/presentation/widgets/`), con los `SeerrWatchProvider` de Seerr.
  - En ese momento se eliminó el badge dependiente de TMDB de las tarjetas; posteriormente se
    restauró el overlay genérico usando el detalle de Seerr por tarjeta (ver el fix de iconos
    más abajo).
- `flutter analyze` → `No issues found!`.

## Fix — "Dónde ver" no coincidía con Seerr (región / key TMDB)
- Síntoma: en la ficha de Seerr salía "No disponible en streaming en tu región" aunque Seerr sí
  muestra la plataforma (p. ej. Disney+).
- Causa: se usaba `WhereToWatchSection` (TMDB BYO-key) y la región se derivaba del idioma de la
  app (`en` → región `US`), por lo que no coincidía con la biblioteca/región del usuario. Si no
  había key TMDB configurada, tampoco había proveedores.
- Fix: usar los **proveedores que ya devuelve Seerr** en el detalle (`MovieDetails`/
  `TvDetails.watchProviders`, esquema `WatchProviders` → `iso_3166_1` + `link` + `flatrate`/`buy`
  de `WatchProviderDetails`), que vienen en la región del usuario y sin necesidad de key TMDB en
  la app.
  - `SeerrMedia` gana `watchProviders: List<SeerrWatchProvider>` (`name`/`type`/`logoPath`/`link`),
    parseados en `fromDetailJson(json, type, {region})` seleccionando la entrada `iso_3166_1` de
    la región.
  - `SeerrApi.detail(type, id, {region})` acepta la región; `seerrDetailProvider` la calcula con
    `tmdbLocaleFor(locale).region`.
  - La vista de proveedores se extrajo a `WatchProvidersView` (reutilizable) en
    `discover/presentation/where_to_watch.dart`; `WhereToWatchSection` (TMDB) ahora la reusa, y
    la ficha de Seerr la pinta con los datos de Seerr. `ItemDetailScreen` gana `seerrMedia`
    (opcional) y lo reenvía a `_DetailActions`.
  - Si Seerr no devuelve proveedores, se conserva el fallback a `WhereToWatchSection` (TMDB).
- `flutter analyze` → `No issues found!`.

## Notas / límites
- La lista de peticiones usa `media.tmdbId`; si el servidor no devuelve `media.mediaType`, se
  asume movie al abrir el detalle.
- Login Plex y gestión de usuarios de Seerr quedan fuera.

## Next
Probar con un Seerr real: Quick Connect (QR/código), búsqueda, solicitar película y serie, y
peticiones.

## Fix pendiente — ficha Seerr: metadatos, diálogo de proveedores y acciones de series
- Intent: mover "Dónde ver/comprar" al botón "Más opciones" y completar los metadatos que
  devuelve Seerr en películas y series.
- Scope: parsear créditos, productoras/redes, clasificación, géneros y duración del detalle;
  mostrar proveedores en un diálogo; reutilizar las acciones de detalle en series virtuales.
- Checklist:
  - [x] Modelo y conversión de metadatos del detalle Seerr.
  - [x] Diálogo desde "Más opciones".
  - [x] Acciones Solicitar/Más opciones visibles en series.
  - [x] Acciones de series con el mismo ancho de escritorio que películas.
  - [x] `flutter analyze` limpio.
- Evidence: `flutter analyze` → `No issues found!`; las acciones de series se limitan a
  `350px` en escritorio, igual que la columna de acciones de películas, y permanecen fluidas
  en vista compacta.
- Next: probar una película y una serie reales desde Buscar y Descubrir.

## Fix pendiente — detalles de series alineados con películas
- Intent: mantener el bloque de detalles de una serie dentro del scroll, debajo del contenido
  relacionado, y hacer que el botón Detalles desplace hasta él en lugar de mostrarlo como una
  pestaña exclusiva.
- Scope: reutilizar `_detailsKey`, `_relatedKey`, `_showDetails` y `_showRelated` del detalle
  común también desde `_DisneySeriesBody`.
- Checklist:
  - [x] Detalles siempre montados después de Sugerencias/relacionado.
  - [x] Botón Detalles desplaza al bloque.
  - [x] Botón Sugerencias desplaza al bloque relacionado.
  - [x] `flutter analyze` limpio.
- Evidence: `_DisneySeriesBody` mantiene el contenido de episodios/extras/sugerencias y monta
  `_AdditionalInformation` después del bloque activo; `relatedKey`/`detailsKey` reutilizan el
  `Scrollable.ensureVisible` del detalle de películas. `flutter analyze` → `No issues found!`.
- Next: probar una serie Seerr y verificar ambos desplazamientos.

## Fix pendiente — iconos de biblioteca y plataformas en scrolls Seerr
- Intent: mostrar en cada tarjeta de Descubrir/Buscar el icono de la plataforma que devuelve
  Seerr; si no hay plataforma, mostrar Jellyfin cuando el título tenga media real en la
  biblioteca.
- Scope: resolver detalle Seerr por tarjeta, consultar el estado Jellyfin y restaurar el
  overlay genérico de logos sin duplicar tarjetas.
- Checklist:
  - [x] Metadatos de tarjeta (proveedores + biblioteca).
  - [x] Icono de plataforma con prioridad sobre Jellyfin.
  - [x] Icono Jellyfin cuando no haya plataforma y sí media real.
  - [x] `flutter analyze` limpio.
- Evidence: `seerrCardMetadataProvider` combina el detalle Seerr con
  `seerrLibraryStatusProvider`; `SeerrMediaRow` y la cuadrícula de Buscar pasan los logos a
  `ContentRow`/`PosterCard`. Si hay logo de plataforma se muestra ese; si no y el item tiene
  media real, se usa `assets/images/jellyfin.png` o el logo del skin. `flutter analyze` →
  `No issues found!`.
- Next: probar un elemento de Descubrir con y sin proveedores.
