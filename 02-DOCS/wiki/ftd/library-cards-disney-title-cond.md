# Intent
El nombre superpuesto del cuerpo Disney solo aparece si la biblioteca no trae arte con título de Jellyfin (`bgUrl == null`, fondo degradado). Con imagen de fondo, la tarjeta muestra imagen + conteo.

# Scope
- Solo bloque de textos de `_DisneyBody` en `library_grid_card.dart`: nombre condicional a `bg == null`.
- Sin tocar el resto de ajustes manuales; sin ARB.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Nombre condicional en `_DisneyBody`
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!`.
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Revisar visualmente ambos casos en Disney (con y sin arte).
