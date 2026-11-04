# FTD — Vídeo Pascua en selección de usuario

## Intent

Cablear `assets/images/seasonal/easter_video.mp4` (añadido por el usuario) como fondo en bucle de la pantalla de selección de usuario cuando `activeSeasonalEventProvider` sea `SeasonalEvent.easter`, reutilizando `AssetVideoBackground` con `easter_user.jpg` como póster, igual que Halloween/Navidad/San Valentín.

## Scope

- Solo `lib/features/users/presentation/user_selection_screen.dart` (mapeos `_seasonalVideoFor` / `_seasonalPosterFor` / `_seasonalImageFor` + comentario).
- Sin cambios de textos (no ARB), sin navegación, sin tocar `PrimeCardBadge`, todo sobre `main`.
- Sin cambios de pubspec: `assets/images/seasonal/` ya cubre el mp4.

## Checklist

- [x] `_seasonalVideoFor` devuelve `easter_video.mp4` en `easter`.
- [x] `_seasonalPosterFor` devuelve `easter_user.jpg` en `easter`.
- [x] `_seasonalImageFor` queda sin casos (todas las épocas con asset pasan a vídeo); el fallback a degradado sigue intacto.
- [x] `flutter analyze` limpio en los ficheros tocados.

## Evidence

- `flutter analyze lib/features/users/presentation/user_selection_screen.dart lib/core/widgets/asset_video_background.dart` → No issues found.
- `UserSelectionScreen`: `easter` resuelve vídeo+poster en `AssetVideoBackground` (con `ValueKey` por asset para reiniciar al cambiar de época); sin época, degradado.

## Next

- Verificar visualmente con override `easter` en Apariencia/barra debug.
