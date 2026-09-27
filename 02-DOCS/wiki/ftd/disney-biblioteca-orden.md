# Intent
Skin Disney: el item Biblioteca pasa a estar debajo de Buscar y encima de VOD (era el último tras Juegos/Seerr). Seerr se queda tras Juegos.

# Scope
- Solo `sidebar.dart` (rama lateral, condicional Disney): Biblioteca en posición 3 (Inicio, Buscar, Biblioteca, VOD…), Seerr al final tras Juegos.
- Sin ARB; sin tocar `PrimeCardBadge`, resto de skins ni barra Prime.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Reordenar items en sidebar Disney
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!`.
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Revisar orden y foco TV en Disney.
