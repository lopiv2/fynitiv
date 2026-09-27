# Intent
Tarjetas de `LibrariesScreen`: con imagen de fondo (backdrop/thumb/primary de Jellyfin) y nombre de colección centrado y más grande, solo en skin Disney. No existe widget que lo haga: se extiende `LibraryGridCard` con variante Disney (el resto de skins mantiene el layout actual con icono).

# Scope
- Solo `library_grid_card.dart` (+ imports): variante Disney con `CachedNetworkImage` (mismo patrón que `BackdropCard`: `errorBuilder` + placeholder), degradado inferior, título centrado 19/w800 y subtítulo centrado; fallback a icono si no hay imagen.
- Sin ARB; sin tocar `PrimeCardBadge`, sidebar ni router.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Variante Disney con imagen en `LibraryGridCard`
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!` (un `info prefer_function_declarations_over_variables` intermedio, corregido).
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).
- Nota: al compartir `LibraryGridCard`, el diálogo de escritorio y el modal TV también muestran la variante con imagen cuando el skin es Disney.

# Next
- Revisar visualmente en Disney (tarjetas con y sin backdrop) y valorar aplicar la variante al diálogo/modal si gusta.
