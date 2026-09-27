# Intent
Skin Disney: quitar el scroll vertical de bibliotecas de la barra lateral (sobrecarga). Dejar un único item Biblioteca → pantalla con grid de tarjetas de todas las bibliotecas Jellyfin. Añadir item Seerr (FontAwesome `cloudArrowDown`) entre Juego online y Biblioteca, con pantalla placeholder para la futura integración de peticiones a demanda.

# Scope
- Solo skin `disney_plus` (condicional por `skin.id`); resto de skins y barra Prime/isla intactos.
- Nuevas rutas `/library` (grid) y `/seerr` (placeholder) en la primera rama del shell (sin renumerar ramas).
- Nueva `LibrariesScreen` + widget genérico reutilizable `LibraryGridCard` (Hover universal, loader, foco TV); `desktop_library_dialog.dart` pasa a usar el widget compartido.
- ARB EN+ES: `seerr`, `seerrComingSoon`, `librariesEmpty` (regenerado con `flutter gen-l10n`, sin tocar dart a mano).
- No se toca `PrimeCardBadge` ni otros elementos manuales.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Rutas `/library` y `/seerr` en `app_router.dart`
- [x] `LibraryGridCard` genérico + refactor de `desktop_library_dialog.dart`
- [x] `LibrariesScreen` (grid, AppLoader, foco TV, empty state)
- [x] `SeerrScreen` placeholder
- [x] Sidebar Disney: Seerr + Biblioteca únicos (foco TV ajustado)
- [x] ARB EN+ES + `flutter gen-l10n`
- [x] `flutter analyze` limpio

# Evidence
- `flutter gen-l10n`: getters `seerr`, `seerrComingSoon`, `librariesEmpty` generados en `app_localizations.dart`.
- `flutter analyze` (27/09/2026): `No issues found!`. Antes del fix de imports hubo 7 errores `uri_does_not_exist` en `library_grid_card.dart`, corregidos (profundidad `../../../../`).
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Integración Seerr real (config servidor/token + API de peticiones) en otro FTD; retirar placeholder entonces.
