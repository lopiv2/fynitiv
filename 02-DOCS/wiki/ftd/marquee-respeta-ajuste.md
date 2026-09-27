# Intent
Todos los `MarqueeText` respetan el ajuste `titleMarqueeOnHover` del skin (Ajustes → Apariencia). Hoy 4 sitios de juegos/Jukebox fuerzan `enabled: true` y se desplazan siempre.

# Scope
- `game_list_screen.dart`, `game_detail_screen.dart` (`_OstNowPlayingCard`), `jukebox_screen.dart` (`_GameTileWithMarquee`) y `jukebox_now_playing_panel.dart` (`_HoverArtistMarquee`): `enabled` desde `skin?.titleMarqueeOnHover ?? false`.
- Sin ARB; sin tocar `PrimeCardBadge` ni el widget `MarqueeText`.

# Checklist
- [x] FTD creado antes del primer cambio
- [x] `enabled` desde skin en los 4 sitios
- [x] `flutter analyze` limpio

# Evidence
- `flutter analyze` (27/09/2026): `No issues found!` (un `),` duplicado intermedio al editar el panel, corregido).
- Sin `flutter build` como verificación (norma del proyecto); sin tests (no pedidos).

# Next
- Revisar en Jukebox con el ajuste off/on que no hay desplazamiento indebido.
