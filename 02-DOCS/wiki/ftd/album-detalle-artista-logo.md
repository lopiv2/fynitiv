# Detalle de álbum: artista (logo o nombre) sobre el título

## Intent

En la vista de detalle de un álbum, mostrar el artista **encima del título**:
su logo de Jellyfin si existe y, si no, el nombre como fallback.

## Scope

- `lib/features/music/presentation/music_screen.dart` (`MusicAlbumScreen`):
  - Se obtiene el artista de `album.albumArtists` / `artists` / `albumArtist`.
  - Sobre el título se añade `ArtistLogoName` (widget existente): resuelve el
    logo por nombre con `artistEntityByNameProvider` y cae al texto si no hay.
  - El skin `jellyfin_classic` mantiene su cabecera propia, que ya muestra el
    artista.

## Checklist

- [x] Nombre/logo del artista sobre el título del álbum
- [x] Fallback a texto si el artista no tiene logo
- [x] `flutter analyze --no-pub` limpio

## Evidence

- `flutter analyze --no-pub` → `No issues found! (ran in 11.0s)`

## Next

Probar la ficha de un álbum (skin no clásico): arriba debe verse el logo del
artista o, si no tiene, su nombre; debajo, el título del álbum.
