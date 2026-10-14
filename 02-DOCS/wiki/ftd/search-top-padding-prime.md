# Búsqueda: separación de la barra superior (Prime)

## Intent
En el skin de Amazon Prime (barra de menú superior anclada, `sidebarPosition:
top` + `topBarFloating: false`), la barra de búsqueda quedaba por debajo del
menú y este la tapaba. La búsqueda debe respetar el alto de esa barra, como el
resto de pantallas con grid.

## Scope
- In: `lib/features/search/presentation/search_screen.dart`: reservar el alto de
  la barra superior con `libraryPageTopPadding(context, skin)` (SizedBox previo)
  y quitar el padding superior fijo del campo (24 → 0).
- Out: no se tocan otras pantallas ni el shell.

## Checklist
- [x] La búsqueda usa `libraryPageTopPadding` según el skin.
- [x] `flutter analyze` limpio.

## Evidence
- `/search` es una rama de `StatefulShellRoute` (`app_router.dart`), así que el
  contenido queda bajo la barra superior superpuesta del shell.
- `search_screen.dart`: se añade `SizedBox(height: libraryPageTopPadding(context,
  skin))` al inicio de la columna y el campo pasa a `fromLTRB(24, 0, 24, 12)`.
  Para skins con barra superior el padding es `mqTop + 76` (anclada) / `+78`
  (isla flotante); para el resto, `mqTop + 8`.
- `flutter analyze` → `No issues found!`.

## Next
- Comprobar en Prime que la barra de búsqueda queda por debajo del menú; revisar
  si otras pantallas de rama (VOD, Música, Live, Juegos) necesitan el mismo
  ajuste.
