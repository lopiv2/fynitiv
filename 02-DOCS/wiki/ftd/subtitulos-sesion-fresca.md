# Subtítulos externos no aparecen en el player (aunque Jellyfin sí los tiene)

## Intent
Un subtítulo `.srt` presente en la carpeta del item (descargado con OpenSubtitles)
aparece en la web de Jellyfin pero **no** en el reproductor de la app: salía
directamente "Buscar subtítulos". Dos causas acumuladas:
1. `playbackSessionProvider` era un `FutureProvider.family` **sin `autoDispose`**, así que
   Riverpod 3 mantenía su valor cacheado toda la vida de la app: la lista de subtítulos se
   congelaba desde la primera apertura del item.
2. La app descartaba los subtítulos sin `DeliveryUrl` (`playback_provider.dart`), y el
   `GET /Items/{id}/PlaybackInfo` puede omitirlo sin perfil de dispositivo. Los subtítulos
   externos descargados (fichero aparte) no tienen entonces pista y no aparecen.

## Scope
- In:
  - `lib/features/player/application/playback_provider.dart`:
    - `playbackSessionProvider` con `isAutoDispose: true` (refetch por apertura).
    - `_subtitleStreamUrl(...)`: usa `DeliveryUrl` si viene; si no, construye
      `.../Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/Stream.{format}` para
      subtítulos externos (`isExternal == true`).
    - `_subtitleFormat(...)`: mapea códec → formato de la ruta (`srt`/`ass`/`ssa`/`vtt`).
  - `lib/features/player/presentation/player_screen.dart`: `externalSubMeta` incluye
    también los streams `isExternal == true` (etiquetas alineadas con las pistas).
- Out: escaneo/refresco forzado del item en el servidor; borrado de subtítulos.

## Checklist
- [x] FTD antes del primer cambio
- [x] `playbackSessionProvider` con `isAutoDispose: true`
- [x] Construcción de URL de subtítulo sin `DeliveryUrl` (externos)
- [x] Etiquetas `externalSubMeta` alineadas
- [x] `flutter analyze` limpio

## Evidence
- `riverpod-3.4.3`: `FutureProvider.family(...)` usa `isAutoDispose = false` por defecto
  (`builder.dart:502`), la sesión quedaba cacheada indefinidamente.
- `jellyfin_dart-0.1.2` `SubtitleApi.getSubtitle` usa la ruta
  `/Videos/{itemId}/{mediaSourceId}/Subtitles/{index}/Stream.{format}`, la misma que
  construye `_subtitleStreamUrl` cuando falta `DeliveryUrl`. Formatos aceptados por
  Jellyfin (docs/`SubtitleController.cs`): `srt`, `vtt`, `ass`, `ssa`, `json`.
- Antes: `if (delivery == null || delivery.isEmpty) continue;` descartaba el subtítulo
  externo. Ahora se construye la URL y el subtítulo entra en `externalSubtitles`, con lo
  que `hasSubtitles` pasa a true y aparece el botón CC.
- `flutter analyze` (proyecto completo) → `No issues found!`.

## Next
- Probar en el player: el botón CC debe aparecer y el subtítulo externo cargarse
  (`Stream.srt` con `api_key`). Si mpv rechaza el formato, probar `.vtt`.
- Valorar `refreshItem` tras descargar si algún servidor no indexa el `.srt` al momento.
