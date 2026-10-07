# Subtítulos remotos — guardar en el servidor para que la API los devuelva

## Intent
Al elegir un subtítulo remoto (plugin OpenSubtitles del servidor) desde el player, el
subtítulo se descargaba con `getRemoteSubtitles` y se aplicaba solo como pista temporal
en el cliente (`SubtitleTrack.data`). Nunca se guardaba en Jellyfin, así que la API no lo
devolvía como pista externa del item: en próximas sesiones / en la ficha del item no
aparecía, mientras que los subtítulos ya presentes en el servidor sí aparecían.
Se debe persistir el subtítulo en el servidor (`downloadRemoteSubtitles`) y refrescar la
info de reproducción (y el detalle del item) para que la lista lo incluya.

## Scope
- In:
  - `lib/features/player/presentation/player_screen.dart` (`_applyRemoteSubtitle`):
    guardar en el servidor, refrescar `playbackSessionProvider` + `itemDetailProvider`,
    aplicar la nueva pista externa del servidor.
  - Respaldo local (`getRemoteSubtitles`) si el guardado en servidor falla (p. ej. sin
    permiso `SubtitleManagement`), avisando de que solo aplica en este dispositivo.
  - `lib/l10n/app_en.arb` + `app_es.arb` (cadena nueva del respaldo local).
- Out:
  - Gestión/borrado de subtítulos ya guardados en el servidor.
  - Ajuste automático de sincronización por hash.

## Checklist
- [x] FTD antes del primer cambio
- [x] Guardado en servidor con `downloadRemoteSubtitles`
- [x] Refresco de `playbackSessionProvider` + `itemDetailProvider`
- [x] Aplicar la pista externa nueva (detección por `id` no visto antes + idioma)
- [x] Respaldo local + cadena ARB (en/es) + `flutter gen-l10n`
- [x] `flutter analyze` limpio

## Evidence
- `jellyfin_dart-0.1.2` expone `SubtitleApi.downloadRemoteSubtitles(itemId, subtitleId)`
  (POST `/Items/{itemId}/RemoteSearch/Subtitles/{subtitleId}`) que es el endpoint que
  guarda el subtítulo en el servidor; antes solo se usaba `getRemoteSubtitles` (GET
  `/Providers/Subtitles/Subtitles/{subtitleId}`, bytes temporales).
- `playbackSessionProvider` / `itemDetailProvider` son `FutureProvider.family` con
  `isAutoDispose = false` (Riverpod 3.4.3), es decir, cacheados: sin invalidar, la lista
  de pistas del item no se actualiza en próximas aperturas.
- `AsyncValue.when` usa `skipLoadingOnRefresh = true` por defecto, así que invalidar
  `playbackSessionProvider` mientras se reproduce no cambia a `loading` ni desmonta el
  reproductor; mantiene los datos previos hasta resolver la nueva sesión.
- `flutter gen-l10n` reescribe `app_localizations*.dart` con `subtitleAppliedLocalOnly`
  (en/es). `flutter analyze` (proyecto completo) → `No issues found!`.

## Next
- Probar en un servidor con plugin OpenSubtitles: descargar un subtítulo desde el player,
  comprobar que aparece en la ficha del item (lenguajes de subtítulos) y en el menú del
  player como pista externa, y que sigue ahí tras reiniciar la app.
- Si el usuario no tiene permiso `SubtitleManagement`, confirmar que se aplica en local y
  se muestra el aviso correspondiente.
