# FTD — Vídeo San Valentín en selección de usuario

## Intent

Cablear `assets/images/seasonal/valentines_video.mp4` (añadido por el usuario) como fondo en bucle de la pantalla de selección de usuario cuando `activeSeasonalEventProvider` sea `SeasonalEvent.valentinesDay`, reutilizando `AssetVideoBackground` con `valentine_user.jpg` como póster, igual que Halloween/Navidad.

## Scope

- Solo `lib/features/users/presentation/user_selection_screen.dart` (mapeos `_seasonalVideoFor` / `_seasonalPosterFor` / `_seasonalImageFor` + comentario).
- Sin cambios de textos (no ARB), sin navegación, sin tocar `PrimeCardBadge`, todo sobre `main`.
- Sin cambios de pubspec: `assets/images/seasonal/` ya cubre el mp4.

## Checklist

- [x] `_seasonalVideoFor` devuelve `valentines_video.mp4` en `valentinesDay`.
- [x] `_seasonalPosterFor` devuelve `valentine_user.jpg` en `valentinesDay`.
- [x] `_seasonalImageFor` deja solo Pascua (San Valentín pasa a vídeo).
- [x] `flutter analyze` limpio en los ficheros tocados.

## Evidence

- `flutter analyze lib/features/users/presentation/user_selection_screen.dart lib/core/widgets/asset_video_background.dart` → No issues found.
- `UserSelectionScreen`: `valentinesDay` resuelve vídeo+poster en `AssetVideoBackground` (con `ValueKey` por asset para reiniciar al cambiar de época); `easter` sigue en imagen fija; sin época, degradado.

## Next

- Verificar visualmente con override `valentinesDay` en Apariencia/barra debug.
