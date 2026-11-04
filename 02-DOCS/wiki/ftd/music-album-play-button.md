# FTD: music-album-play-button — botón Reproducir en la ficha del álbum

## Intent
En Música, la ficha del álbum (vista moderna, skins no clásicos) no muestra ningún botón Reproducir en cabecera: solo iconos por pista que arrancan el mini-player. El resto de fichas (playlist, artista, skin clásico) sí tienen reproducir. Añadir Reproducir todo en la cabecera del álbum.

## Scope
- `lib/features/music/presentation/music_screen.dart` (`MusicAlbumScreen`, vista moderna): botón `FilledButton.icon` con `l10n.play` (clave ARB existente, sin ARB nuevas) que abre `/player` con la primera pista, igual que playlist/artista.
- Traducción: los dos `tooltip: 'Reproducir'` hardcodeados de esta pantalla pasan a `l10n.play` (norma ARB).
- No se toca: `play_routing.dart` (canción en detalle genérico ya va a `/player`), `PrimeCardBadge`, foco TV, resto de skins.

## Checklist
- [x] FTD creado antes del cambio
- [x] Botón Reproducir en cabecera del álbum moderno
- [x] Tooltips hardcodeados → `l10n.play`
- [x] `flutter analyze` limpio

## Evidence
- `flutter analyze` (4 ficheros: `music_screen.dart`, `play_routing.dart`, `item_detail_screen.dart`, `library_providers.dart`): `No issues found!`.
- Nota: la vista detalle genérica (`ItemDetailScreen`) ya muestra Ver ahora para canciones (`audio`→`/player`); lo que no tenía botón era la ficha del álbum en skins modernos.

## Next
- Verificar en Windows: abrir un álbum con skin moderno → Reproducir abre el player con la primera pista.
