# Intent
Poner `MarqueeText` (reutilizando el widget universal y validando la preferencia `titleMarqueeOnHover` del skin) al subtítulo (artista) de la canción en el "reproduciendo ahora" del detalle de juego, igual que ya lo tiene el título.

# Scope
- In: `lib/features/games/presentation/game_detail_screen.dart` (`_OstNowPlayingCard`): subtítulo `current?.artist ?? game.name` pasa de `Text` con ellipsis a `MarqueeText` con `isHovered: true` y `enabled` desde `skinControllerProvider`; se extrae `marqueeEnabled` local para no duplicar el `watch` (título y subtítulo lo comparten).
- Out: cambios en el player/OST, nuevos ARB (mismas cadenas), cambios visuales aparte del desplazamiento, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Subtítulo con `MarqueeText` + preferencia
- [x] `flutter analyze` sin issues

# Evidence (verificacion)
- `flutter analyze` (game_detail_screen) → "No issues found!".

# Evidence
- Título ya con marquee + preferencia: `game_detail_screen.dart:1124` (`MarqueeText` con `enabled: ...titleMarqueeOnHover ?? false`, `isHovered: true`).
- Subtítulo aún plano: `game_detail_screen.dart:1143` (`Text` con `maxLines: 1`, `ellipsis`).
- Widget universal: `lib/core/widgets/marquee_text.dart` (solo anima con overflow + `enabled` + `isHovered`; si no, ellipsis igual que hoy).

# Next
Abrir un detalle con artista largo, activar el ajuste en Apariencia y comprobar que título y subtítulo se desplazan al pasar el ratón.
