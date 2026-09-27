# Intent
El cuerpo Disney solo mostraba el conteo: el nombre de la librería debe aparecer siempre (con y sin imagen) en el estilo Disney centrado.

# Scope
- Solo bloque de textos de `_DisneyBody` en `library_grid_card.dart`: añadir nombre encima del conteo, mismo centrado/sombras.
- Sin tocar el resto de ajustes manuales; sin ARB.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Nombre siempre visible en `_DisneyBody`
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!`.
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Revisar visualmente en Disney el conjunto nombre + conteo.
