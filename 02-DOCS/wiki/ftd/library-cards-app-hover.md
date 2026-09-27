# Intent
Usar el Hover universal (`AppHover`) en todas las tarjetas de biblioteca: migrar `_TvLibraryCard` (modal TV, con su propio Focus/GestureDetector) al widget genérico `LibraryGridCard`, y eliminar `_LibraryRow` muerta del diálogo de escritorio. Para no perder el foco inicial del modal, `AppHover` acepta `focusNode`/`autofocus`/`onFocusChange` opcionales (retrocompatible).

# Scope
- `lib/core/widgets/app_hover.dart`: nuevos params opcionales (`focusNode`, `autofocus`, `onFocusChange`); sin cambios de comportamiento por defecto.
- `library_grid_card.dart`: overrides opcionales (`icon`, `subtitle`) + foco externo; trailing: check si `selected`, chevron oculto en hover/focus (igual que la tarjeta TV).
- `tv_library_modal.dart`: usa `LibraryGridCard`; se borra `_TvLibraryCard`; se mantiene foco inicial a la biblioteca activa y Escape/atras.
- `desktop_library_dialog.dart`: se borra `_LibraryRow` (muerta, sin usos).
- Sin ARB nuevas; sin tocar `PrimeCardBadge`.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Params de foco en `AppHover`
- [x] Overrides en `LibraryGridCard`
- [x] Modal TV migrado + `_LibraryRow` borrada
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!`.
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Revisar visualmente el modal TV (foco inicial + LED) en escritorio/TV; el diálogo de escritorio ya comparte la misma tarjeta.
