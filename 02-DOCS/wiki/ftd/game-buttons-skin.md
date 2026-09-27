# Intent
Botones Jugar/Descargar del detalle de juego con los colores del skin (primario con acento, secundario con borde de acento), manteniendo `AppHover`/`AppHoverButton` y el radius del skin.

# Scope
- Solo `_OriginButton` en `game_detail_screen.dart` (los tres estados: primario, secundario y carga).
- Sin ARB; sin tocar `PrimeCardBadge` ni la lógica de play/descarga.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Acento del skin en `_OriginButton`
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!`.
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Revisar visualmente en Disney (celeste) y Jellyfin (morado) los tres estados.
