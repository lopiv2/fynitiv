# FTD — Fondos estacionales en selección de usuario

## Intent

Poner los assets añadidos por el usuario como fondo de la pantalla de
selección de usuario según la época (`activeSeasonalEventProvider` por fecha u
override manual): vídeo en Halloween y Navidad, imagen fija en San Valentín y
Pascua. Mantener el degradado actual cuando no haya época activa.

## Scope

- Solo `lib/features/users/presentation/user_selection_screen.dart` + widget
  genérico reutilizable (`lib/core/widgets/asset_video_background.dart`).
- Sin cambios de textos (no ARB), sin cambios de navegación, sin tocar
  `PrimeCardBadge`, sin ramas (todo sobre `main`).
- Assets ya añadidos por el usuario (`halloween_video.mp4`,
  `halloween_user.jpg`, `christmas_video.mp4`, `christmas_user.jpg`,
  `valentine_user.jpg`, `easter_user.jpg`) cubiertos por
  `assets/images/seasonal/` en `pubspec.yaml`; sin cambios de pubspec.

## Checklist

- [x] Crear `AssetVideoBackground` genérico (media_kit, loop, mute, overlay, póster fallback).
- [x] Vídeo Halloween + póster cuando `SeasonalEvent.halloween`.
- [x] Vídeo Navidad + póster cuando `SeasonalEvent.christmas`.
- [x] Imagen fija San Valentín (`valentine_user.jpg`) y Pascua (`easter_user.jpg`).
- [x] Fallback al degradado actual si no hay época o si el vídeo falla/carga.
- [x] `flutter analyze` limpio.
- [x] Reiniciar el reproductor al cambiar de época sin salir de la pantalla
  (`didUpdateWidget` + `ValueKey`), con log de error si un vídeo falla.

## Evidence

- `flutter analyze lib/core/widgets/asset_video_background.dart lib/features/users/presentation/user_selection_screen.dart` → No issues found.
- `UserSelectionScreen` usa `activeSeasonalEventProvider`: vídeo+`_user.jpg` en Halloween y Navidad (`AssetVideoBackground`), imagen fija en San Valentín (`valentine_user.jpg`) y Pascua (`easter_user.jpg`); resto del año mantiene el degradado.
- Assets cubiertos por `- assets/images/seasonal/` en `pubspec.yaml` (sin cambios necesarios).

## Next

- Verificar visualmente en octubre o con override `halloween` en Apariencia/barra debug.
