# OST mini con cover del juego

## Intent
En el mini player de las OST, que no tienen cover propio, mostrar como cover la portada del juego al que pertenece cada pista.

## Scope
- In: `GameOstTrack.gameId` + `GameOstTrack.coverUrl`; `ostTracksProvider(gameId)` enriquece con la portada del juego (`coverLargeUrl` > `coverSmallUrl` vía `repo.getGame`); `jukeboxTracksProvider` enriquece con `cover_url` de `GET /api/music/games` mapeado por `rom_id`; `soloudMusicProvider` guarda `ostCoverUrl` por pista encolada y `coverUrl` lo devuelve para `isRomm`; `MiniPlayerBar` pinta esa cover (con headers Bearer ROMM) con fallback al icono actual; `_OstNowPlayingCard` del detalle pinta la portada del `game` recibido junto al título.
- Out: cambios en lista de temas del Jukebox/detalle (siguen sin thumb por fila), skins del music player fullscreen, favoritos, ordenación, descargas de assets.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] `GameOstTrack` expone `gameId` + `coverUrl` — `flutter analyze` sin issues
- [x] Providers OST/Jukebox rellenan `coverUrl` — `flutter analyze` sin issues
- [x] `MiniPlayerBar` muestra portada del juego con fallback actual — `flutter analyze` sin issues
- [x] `_OstNowPlayingCard` muestra portada del juego — `flutter analyze` sin issues

## Evidence
- Base actual: `SoloudMusicState.coverUrl` en `lib/features/music/application/soloud_music_provider.dart:95` devuelve `''` para `isRomm`; `MiniPlayerBar` en `lib/features/music/presentation/widgets/mini_player_bar.dart:123` cae al icono `music_note`; `_OstNowPlayingCard` en `lib/features/games/presentation/game_detail_screen.dart:1043` no pinta cover; `MusicGameEntry.coverUrl` existe (`GET /api/music/games`) pero `GameOstTrack` no lo propaga.
- `flutter analyze` (7 ficheros: game_ost_track, ost_providers, jukebox_providers, soloud_music_provider, mini_player_bar, game_detail_screen, jukebox_screen) → "No issues found!"

## Next
Abrir Jukebox, reproducir una OST y confirmar que el mini global muestra la portada del juego; abrir un detalle y confirmar lo mismo en su tarjeta Now Playing.
