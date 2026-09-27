# Intent
Siempre cuerpo Disney en skin Disney (sin bifurcar por `bgUrl`): con imagen de fondo si la hay, si no degradado curado determinista por biblioteca. Mismo estilo de nombre centrado grande en ambos casos.

# Scope
- Solo `library_grid_card.dart`: renombrar a `_DisneyBody`, degradado de paleta curada por hash del id, borrar `_DisneyFallbackIcon` y el ternario.
- Sin ARB; sin tocar `PrimeCardBadge`, sidebar ni router.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] `_DisneyBody` siempre + degradado sin imagen
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!`.
- Se respetaron los ajustes manuales del usuario (outline blanco, LED azul, texto único centrado): solo se reestructuró el fondo.
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Revisar visualmente en Disney bibliotecas con y sin imagen.
