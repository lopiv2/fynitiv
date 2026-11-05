# Biblioteca: tap a detalles y colecciones con sus películas

## Intent

Unificar el comportamiento de la pantalla de biblioteca (todas las skins):
al pulsar cualquier contenido se abre su **ficha** (desde ahí se reproduce/lee),
nunca el reproductor directo. Las **colecciones (BoxSets)** abren el grid con
las películas que las componen.

## Scope

- `lib/features/library/presentation/library_view_screen.dart`: helper
  `_openItem` usado por las tarjetas poster y backdrop:
  - `BoxSet` → `/library/{boxSetId}` (grid con sus películas).
  - Resto → `pushDetailForType` (película/serie → ficha, libro/cómic → ficha
    del lector, álbum → detalle de música…).
- `lib/features/movies/presentation/all_movies_screen.dart`: el grid legacy de
  películas también abre la ficha en vez del reproductor.

## Checklist

- [x] Colecciones de la biblioteca abren sus películas
- [x] Películas y series de la biblioteca abren la ficha
- [x] Libros/cómics abren su ficha (lectura desde ahí)
- [x] Grid legacy `/movies` también abre la ficha
- [x] `flutter analyze --no-pub` limpio

## Evidence

- `flutter analyze --no-pub` → `No issues found! (ran in 7.8s)`

## Next

Probar en la biblioteca de Colecciones: pulsar una colección → debe listar sus
películas; pulsar una película → ficha con botón de reproducción. Repetir en
Libros/Cómics y en los grids de Películas/Series. Las filas de Inicio/VOD
mantienen su `HomeScroll.tapAction` (play/details) configurable por scroll.
