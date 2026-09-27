# Intent
El botón atrás del detalle de biblioteca (`/library/:viewId`) vuelve a Inicio porque la navegación usa `go` (sin pila) y el `LibraryPageHeader` cae a `/home`. Debe volver al grid de Biblioteca (`/library`).

# Scope
- Solo `library_view_screen.dart`: `onBack` explícito a `/library` (+ import de `go_router`).
- Sin ARB; sin tocar `PrimeCardBadge`.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] `onBack` a `/library` en el header
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!` (el import de `go_router` ya existía).
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Comprobar en Disney: grid → biblioteca → atrás vuelve al grid, con foco TV coherente.
