# Subtítulos remotos (plugin OpenSubtitles de Jellyfin) + sincronización

## Intent
Poder buscar y descargar subtítulos en películas y series usando el plugin de OpenSubtitles
configurado en el servidor Jellyfin, sin pedir ninguna Api-Key ni cuenta al usuario en la app.
Además: un botón visible cuando el contenido **no** tiene subtítulos y un slider para sincronizar
el subtítulo con el audio (`sub-delay` de mpv).

## Scope
- In:
  - `lib/features/subtitles/domain/subtitle_language.dart` (normalización a ISO-639-2).
  - `lib/features/subtitles/application/remote_subtitles_provider.dart` (búsqueda vía `jellyfin_dart`).
  - `lib/features/subtitles/presentation/subtitle_search_sheet.dart` (UI de búsqueda).
  - `lib/features/player/presentation/player_screen.dart` (chip "Buscar subtítulos", ítem de menú,
    aplicar subtítulo con `SubtitleTrack.data`, slider de sincronización + persistencia por ítem).
  - `lib/l10n/app_en.arb` + `app_es.arb` (cadenas nuevas).
- Out:
  - Proveedores externos (SubDL/OpenSubtitles directo) y claves en la app.
  - "Guardar en el servidor" (`downloadRemoteSubtitles`): fuera de esta iteración.
  - Ajuste automático de sincronización por hash.

## Checklist
- [x] FTD antes del primer cambio
- [x] Cadenas ARB (en/es) + `flutter gen-l10n`
- [x] Helper de idioma ISO-639-2
- [x] Provider de búsqueda remota (`getSubtitleApi().searchRemoteSubtitles`)
- [x] Hoja de búsqueda (selector de idioma, resultados, loader, toasts)
- [x] Chip "Buscar subtítulos" cuando no hay pistas + ítem en el menú de subtítulos
- [x] Aplicar subtítulo (`getRemoteSubtitles` → `SubtitleTrack.data` → `setSubtitleTrack`)
- [x] Slider de sincronización inline (±10 s, paso 0,1 s) con `sub-delay` vía `NativePlayer`
- [x] Persistencia del delay por ítem (`subtitle_delay_<itemId>`)
- [x] `flutter analyze` limpio
- [ ] Prueba manual con el plugin OpenSubtitles del servidor

## Evidence
- `jellyfin_dart-0.1.2` expone `client.getSubtitleApi()` con `searchRemoteSubtitles`,
  `getRemoteSubtitles` y `downloadRemoteSubtitles` (`lib/src/api/subtitle_api.dart`).
- `media_kit-1.2.6` implementa `SubtitleTrack.data` escribiendo a un fichero temporal que borra en
  `dispose` (`native/player/real.dart:1107-1113`), por lo que no hace falta `path_provider`.
  Además, el `track-list` de mpv (que incluye el `sub-add`) se vuelca a `tracks.subtitle`
  (`real.dart:1871-1893`), así que el subtítulo descargado aparece en el menú sin duplicar entradas.
- El proyecto ya usa `NativePlayer.setProperty` para propiedades de mpv
  (`featured_slider.dart:1085`, `live_tv_player_provider.dart:231`); el desfase usa `sub-delay`.
- La API de SubDL devuelve `403` sin `api_key` (comprobado por HTTP), por eso se descarta como
  fuente por defecto y se apoya todo en el plugin del servidor.
- `flutter gen-l10n` → genera `searchSubtitles`, `searchSubtitlesMenu`, `subtitleDownloadsCount`,
  `subtitleSyncOffset`, etc. en `app_localizations*.dart`.
- `flutter analyze` (proyecto completo) → `No issues found!`.
- Ajuste posterior: el chip "Buscar subtítulos" se envolvía en `Flexible`, que competía con el
  `Spacer` de la barra y dejaba hueco al final de la fila (el control de subtítulos se veía
  descentrado/centrado). Se quita el `Flexible` para anclarlo a la derecha como el botón CC.
  Con subtítulos presentes la posición ya era la de `HEAD` (verificado con `git show`).

## Next
- Prueba manual con el plugin OpenSubtitles configurado en el servidor (búsqueda por idioma,
  aplicar y valorar calidad del matching).
- Valorar "Guardar en el servidor" (`downloadRemoteSubtitles` + refrescar playback info).
  → Hecho en `subtitulos-guardar-servidor.md`.
- Manejar el caso de usuario sin permiso `SubtitleManagement` con mensaje específico si el
  genérico de error no es suficiente. → Hecho: respaldo local + aviso
  `subtitleAppliedLocalOnly` (`subtitulos-guardar-servidor.md`).
