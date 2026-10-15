# E-Reader — padding superior con barra Prime (solape)

## Intent
Con el skin Prime (`sidebarPosition: top`), la barra superior del shell se dibuja
solapada sobre el contenido. La biblioteca E-Reader reservaba su espacio con
`eReaderSkin` (Jellyfin, barra lateral) y el lector de libros no reservaba nada, así que
la barra tapaba el título del E-Reader y la flecha de atrás del lector.

## Scope
- In: reservar el alto de la barra del shell en `EReaderScreen`, `BookDetailScreen` y
  `BookReaderScreen` usando el **skin global** (el que dibuja la barra), y añadir padding
  a la flecha de atrás del lector.
- Out: cambios en el shell, en el skin Prime o en los visores de contenido.

## Checklist
- [x] FTD antes del primer cambio
- [x] `EReaderScreen` usa el skin global para `libraryPageTopPadding`
- [x] `BookDetailScreen` reserva el alto de barra
- [x] `BookReaderScreen` reserva el alto de barra + padding de la flecha de atrás
- [x] `flutter analyze` limpio

## Evidence
- `home_shell.dart` (líneas 211-226): con `SidebarPosition.top` y Prime anclado monta un
  `Stack` con `Positioned.fill(contentFocus)` y la barra superpuesta; las pantallas deben
  reservar `libraryPageTopPadding(context, skinGlobal)`.
- `EReaderScreen` pasaba `eReaderSkin = SkinPresets.jellyfinDefault` (barra lateral), por
  lo que `libraryPageTopPadding` devolvía `mqTop+8` y la barra Prime la tapaba. Ahora usa
  `ref.watch(skinControllerProvider).value` (igual que Games/Music). Sin regresión para
  skins laterales (mismo `mqTop+8`).
- `BookDetailScreen` (ruta `/ereader/details/:itemId`) y `BookReaderScreen`
  (`/ereader/read/:itemId`) también están dentro del shell, así que sus cabeceras
  (flecha de atrás + logo) quedaban bajo la barra. En ambos se añade un `SizedBox` con el
  alto de barra al inicio de la columna. El cálculo se hace en el `build` exterior al
  `SafeArea`: `libraryPageTopPadding(context, skinGlobal)` menos `MediaQuery.padding.top`
  (el `SafeArea` ya cubre el inset del sistema y, además, hace `removePadding` para sus
  descendientes — por eso el valor se computa fuera). En el lector se añade también 8 px
  de padding lateral a la cabecera.
- `flutter analyze` → `No issues found!`.

## Next
Probar visualmente en TV/escritorio con Prime: título "E-Reader" y flecha de atrás del
lector por debajo de la barra; comprobar que en skins laterales (Jellyfin/Disney) no
aparece hueco extra.
