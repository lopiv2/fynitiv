# Detalle: botón atrás bajo la barra superior (Prime)

## Intent
En la pantalla de detalle (`/home/details/:id`) con el skin Prime, el botón de
atrás (arriba-izquierda) quedaba por debajo de la barra de menú superior y esta lo
tapaba. Debe quedar por debajo de esa barra.

## Scope
- In: `lib/features/library/presentation/item_detail_screen.dart`: el padding
  superior del bloque del botón usa `libraryPageTopPadding` en lugar del fijo 8.
- Out: no se tocan otras pantallas ni el shell.

## Checklist
- [x] El botón atrás respeta el alto de la barra superior del skin.
- [x] `flutter analyze` limpio.

## Evidence
- El detalle usa `SafeArea` (solo resuelve el status bar del sistema, no la barra
  superior del shell). El bloque del botón tenía `EdgeInsets.fromLTRB(28, 8, …)`.
- Fix: `topInset = libraryPageTopPadding(context, skin) - MediaQuery.padding.top`
  y el padding pasa a `fromLTRB(28, topInset, 24, 0)`. Combinado con el `SafeArea`
  da `libraryPageTopPadding` total (Prime anclada: `mqTop + 76`); para barras
  laterales `topInset` vuelve a ser 8 (sin cambio).
- `flutter analyze` → `No issues found!`.
- Verificado en la app por el usuario: el botón de atrás del detalle ya queda
  bajo la barra superior en Prime.

## Next
- Cerrado.
