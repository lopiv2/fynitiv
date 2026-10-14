# Intent
El botón atrás del detalle de biblioteca (`/library/:viewId`) siempre iba al grid
de Biblioteca (`/library`), ignorando de dónde se venía. Al entrar desde Inicio
con "Ver más" (que usa `push`) debe volver a Inicio; solo si se entró sin pila
(`go`, p. ej. desde la barra lateral) debe caer al grid de Biblioteca.

# Scope
- Solo `library_view_screen.dart`: `onBack` pasa a
  `context.canPop() ? context.pop() : context.go('/library')`.
- Sin ARB; sin tocar `PrimeCardBadge`.

# Checklist
- [x] FTD creado antes del primer cambio (versión inicial: `onBack` fijo a `/library`)
- [x] `onBack` a `/library` en el header
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!` (el import de `go_router` ya existía).
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Corrección (back siempre a Biblioteca)
- Causa: `onBack` estaba fijado a `context.go('/library')`. Como `home_screen`
  navega con `context.push('/library/:viewId')` (Ver más de filas y de scrolls),
  había pila, pero el botón la ignoraba.
- Fix: `onBack: () => context.canPop() ? context.pop() : context.go('/library')`.
  Con pila (Inicio) vuelve a la pantalla anterior; sin pila (barra lateral con
  `go`) mantiene el fallback al grid de Biblioteca.
- `flutter analyze` → `No issues found!`.

# Next
- Comprobar: Inicio → Ver más → atrás vuelve a Inicio; barra lateral → biblioteca
  → atrás va al grid de Biblioteca.
