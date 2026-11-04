# FTD: detail-play-routing — Ver ahora según tipo (peli/serie/música/libro)

## Intent
En la vista detalle, el botón Ver ahora mandaba todo a `/player` (salvo libros, que lo ocultaban). Distinguir película, serie, música y libro para mandar cada uno a su reproductor.

## Scope
- Nuevo helper genérico reutilizable `lib/core/navigation/play_routing.dart`: `playTargetFor(item)` + `pushPlayForDetail(context, item)`.
  - Vídeo (movie, episode, video, trailer, musicVideo) → `/player/:id` (media_kit).
  - Audio (audio, audioBook) → `/player/:id` (el propio player resuelve audio con SoLoud).
  - Libro (book) → `/ereader/read/:id` (BookReaderScreen).
  - Colección de música (musicAlbum, playlist): Ver ahora reproduce su primera pista en `/player` (`_CollectionWatchNow` + providers jellyfin_dart).
  - Artista (musicArtist): Ver ahora abre su ficha de Música (que ya tiene reproducir).
  - No reproducibles directos (series, season, person…) → `unsupported`, sin navegación + toast `playbackFailed` reutilizado (sin ARB nuevas).
- `lib/features/library/presentation/item_detail_screen.dart`: `_DetailActions` usa el helper (libros van al lector en vez de ocultar el botón; álbum/playlist resuelven primera pista; artista va a su ficha; series sin VER directo no muestran botón muerto); `_RelatedSection.onItemTap` también usa el helper.
- No se toca: `_DisneySeriesBody` (VER por episodio ya es correcto), `PrimeCardBadge`, foco TV, ARB (se reutiliza `playbackFailed`).

## Checklist
- [x] FTD creado antes del cambio
- [x] Helper `play_routing.dart` creado
- [x] `item_detail_screen.dart`: `_DetailActions` + `_RelatedSection` usan helper
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze lib/core/navigation/play_routing.dart lib/features/library/presentation/item_detail_screen.dart lib/features/library/application/library_providers.dart`: `No issues found!`.
- `playTargetFor`: book→lector, movie/episode/video/trailer/musicVideo/audio/audioBook→`/player`, resto→unsupported (toast `playbackFailed`, sin ARB nuevas).

## Next
- Verificar en Windows: película→player vídeo, episodio serie→player, canción→player audio, álbum/playlist→primera pista en player, libro→lector; serie sin episodios no muestra botón muerto.
