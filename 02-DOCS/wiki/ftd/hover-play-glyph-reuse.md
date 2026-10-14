# Intent
Reutilizar `HoverPlayGlyph` en las tarjetas que usan hover con icono de play explícito (`showPlayIcon`), eliminando el `Container`+`Icon` duplicado de `_PlayOverlay`.

# Scope
- `lib/core/widgets/hover_play_glyph.dart`: overrides opcionales (`backgroundColor`, `iconColor`, `borderColor`, `borderWidth`); sin cambio visual por defecto.
- `lib/core/widgets/hover_play_card.dart`: `_PlayOverlay` usa `HoverPlayGlyph` (estilo `prime`, 48px, icono negro para preservar el visual actual); nuevo param opcional `playGlyphStyle` (retrocompatible).
- Beneficiarias automáticas (usan `showPlayIcon` explícito): `poster_card.dart`, `backdrop_card.dart`, `content_row.dart`, `game_poster_card.dart` (vía `HoverPlayCard`).
- Excluidas a propósito: `game_continue_card.dart` y `media_card.dart` (play verde de marca con `playBackground`/LED propio, sin flag `showPlayIcon`); `station_card.dart` (botón fijo, no hover); sin tocar `PrimeCardBadge`.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] Overrides en `HoverPlayGlyph`
- [x] `_PlayOverlay` usa `HoverPlayGlyph`
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze lib/core/widgets/hover_play_glyph.dart lib/core/widgets/hover_play_card.dart`: `No issues found!`.
- `flutter analyze` completo: `No issues found!`.
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Revisión visual del hover con play (oscurecido + círculo blanco 48px) en una fila de biblioteca.
