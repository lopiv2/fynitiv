# Intent
Título del cuerpo Disney con degradado vertical de blanco a gris (vía `ShaderMask`), manteniendo tamaño, peso, sombras y layout actuales.

# Scope
- Solo el `Text` del nombre en `_DisneyBody` (`library_grid_card.dart`).
- Sin tocar el resto de ajustes manuales; sin ARB.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] `ShaderMask` blanco→gris en el título
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!`.
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Revisar visualmente el degradado sobre imagen y sobre degradado de fondo.
