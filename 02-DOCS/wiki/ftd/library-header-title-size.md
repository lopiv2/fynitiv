# Intent
El título de `LibraryPageHeader` usa `fontSize: 24` literal; debe usar la constante `kSectionTitleFontSize` (que ya vale 24) para unificar el tamaño de cabeceras de sección.

# Scope
- Solo `library_page_header.dart`: import de `ui_constants` y `fontSize: kSectionTitleFontSize` (sin cambio visual, 24 = 24).
- Sin ARB; sin tocar `PrimeCardBadge`.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Aplicar `kSectionTitleFontSize` al título
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!` (`kSectionTitleFontSize` es `const`, el `TextStyle` sigue siendo `const`; sin cambio visual).
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Ninguno.
