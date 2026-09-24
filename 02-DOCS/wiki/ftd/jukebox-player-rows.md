# Jukebox en el player global + rows Mezclas/Biblioteca

## Intent
Que el Jukebox reproduzca en el player de la librería de música (misma barra mini global bajo la app) compartiendo el singleton de audio `SoLoud.instance` para que nunca se solapen audios, y añadir bajo los chips las dos rows de la captura (Listas de reproducción + Biblioteca) funcionales.

## Scope
- In: cola OST en `SoloudMusicController` (`playOstQueue` con Bearer, avance auto, shuffle, `next()`/`previous()` con fallback a ±10s); `MiniPlayerBar` con next/prev de cola, corazón funcional para pistas ROMM, sin navegar a `/player` en pistas ROMM; `GameOstPlayer.onBeforeStart` cableado en `home_shell` + `stop(resumeBackground:false)`; `suspendForDetail` al arrancar el provider y retorno al parar/completar; detalle frena el provider al autoarrancar; `durationSeconds` en `GameOstTrack`; `min/max_year` + facet `platforms` en repo/providers; tab `platforms`; rows Mezclas (Radio libre 60min, Décadas con sublista, Recientes 25, Favoritas) y Biblioteca (Todo, Álbum, Plataforma, Artista, Género); se elimina el mini local del Jukebox; ARB EN+ES.
- Out: playlists propias `/music/playlists`, migrar el OST del detalle al provider, ecualizador dedicado ROMM.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] Cola + auth + next/prev + fav en provider/mini global — `flutter analyze` sin issues
- [x] Anti-solape estructural (hook + suspend/return) — `flutter analyze` sin issues
- [x] Rows Mezclas/Biblioteca + tab platforms + décadas — `flutter analyze` sin issues
- [x] ARB EN+ES (plurales ICU) + `flutter gen-l10n` — `flutter analyze` sin issues

## Evidence
- Singleton compartido: `SoLoud.instance` en `soloud_music_provider.dart` (cola Jellyfin) y `soloud_single_player.dart` (`loadUrl` con `httpClient` para Bearer ROMM); `MiniPlayerBar` global en `home_shell.dart:253`; `GameBgPlayer.suspendForDetail/returnFromDetail` no-op fuera de `/games` (`game_bg_player.dart:90`).
- Doc ROMM 5.3: `order_by=added`, `min_year`/`max_year`, facet `/music/platforms` (`{id, slug, name, count}`); captura del usuario con las 2 rows (4 mixes + 5 biblioteca).
- `flutter analyze` (8 ficheros: jukebox_screen, soloud_music_provider, mini_player_bar, jukebox_providers, romm_repository, game_ost_player, home_shell, game_detail_screen) → "No issues found!"
- `flutter gen-l10n` regeneró las nuevas claves `jukeboxPlatforms`, `jukeboxMixes`, `jukeboxLibrary`, etc. (verificado en `app_localizations.dart`).

## Next
Probar solapes (jukebox↔detalle↔música Jellyfin↔fondo) y decidir playlists propias en v2.
