# Discover — Novedades y "Dónde ver" con TMDB (BYO-key)

## Intent
Ofrecer contenido externo (no presente en la biblioteca Jellyfin) usando TMDB con la key
propia del usuario ("Bring Your Own Key"): una fila de **Novedades** configurable en el
layout y un botón **"Dónde ver"** en el detalle para items sin media (venidos de
Radarr/Sonarr), mostrando proveedores de streaming sin depender de JustWatch directamente.

## Scope
- In:
  - Preferencia persistente (almacén seguro) con la API key de TMDB del usuario.
  - Servicio TMDB (trending/estrenos, detalle, watch providers), región/idioma derivados
    del locale de la app.
  - `LayoutSection` nuevo tipo `novedades` (configurable: trending o estrenos), disponible
    en Home y VOD, **no activado** en presets por defecto.
  - Ficha externa TMDB (`/discover/:mediaType/:id`) sin acciones de Jellyfin.
  - "Dónde ver" en el detalle de biblioteca para items no reproducibles.
  - Atribución TMDB (+ JustWatch en proveedores).
- Out:
  - TVMaze, JustWatch directo, key embebida en el repo, backend propio.

## Checklist
- [x] FTD antes del primer cambio (este documento)
- [x] `TmdbKeyNotifier` (flutter_secure_storage)
- [x] API + providers TMDB
- [x] `NovedadesRow` + `LayoutSection.novedades` + resolución home/vod
- [x] `TmdbDetailScreen` + ruta
- [x] "Dónde ver" en `item_detail_screen`
- [x] Campo key en Preferencias + atribución en About
- [x] ARB EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- Investigación: el límite de TMDB es **por IP** (~40-50 req/s), no por key; compartir una
  key no concentra el límite, pero **embeber** una key la expone (revocación + ToS). Modelo
  elegido: **BYO-key** (cada usuario la introduce; sin secretos en el repo).
- Sin key, TMDB no se llama y "Novedades"/"Dónde ver" no aparecen (silencioso).
- Implementado:
  - `core/settings/tmdb_key_controller.dart` (secure storage), `features/discover/`
    (modelos, `TmdbApi`, providers con locale→región, `NovedadesRow`, `WhereToWatchSection`,
    `TmdbDetailScreen`).
  - `LayoutSection.novedades(source)` configurable (trending/estrenos) + resolución en
    `home_screen` y `vod_screen` (no-op en backdrops). Solo disponible, no en presets.
  - Ruta `/discover/:mediaType/:id` (pantalla completa).
  - `item_detail_screen`: para items no reproducibles (`LocationType.virtual` o
    `MediaSources` vacío) con tmdb id y key configurada, muestra "Dónde ver".
  - Preferencias: campo de key; About: atribución TMDB/JustWatch.
  - ARB EN+ES (`whereToWatch`, `viewOnTmdb`, `tmdbApiKey[Example|Hint]`, `tmdbAttribution`,
    `tmdbPoweredBy`, `watchFlatrate|Free|Ads|Rent|Buy`, `watchNoProviders`).
  - `flutter gen-l10n` OK; `flutter analyze` → `No issues found!`.

## Next
Probar con una key TMDB real: fila Novedades (trending/estrenos), ficha externa y
"Dónde ver" en un item virtual. Verificar que sin key todo queda oculto.
