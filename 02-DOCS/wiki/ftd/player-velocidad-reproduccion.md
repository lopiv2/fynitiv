# Velocidad de reproducción en el player de vídeo

## Intent
Añadir en el reproductor de películas/series un botón de velocidad a la derecha de `>>` que
abra un menú hacia arriba con velocidades de 0.5x a 2.0x en pasos de 0.25, aplicadas al vídeo
(no a música), mostrando la velocidad activa cuando no sea 1x, con la hora
estimada de fin ajustada a esa velocidad.

## Scope
- In:
  - Botón `_PlaybackSpeedButton` a la derecha de `fast_forward_rounded`, con badge `1.25x`
    cuando la velocidad no es 1x.
  - Menú `PopupMenuButton<double>` con `offset` negativo (hacia arriba), estilo de los menús de
    audio/subtítulos y navegable con D-pad.
  - Estado `_playbackRate` (reset a 1.0 por contenido) y `_setPlaybackRate`.
  - `_exitTrickPlay` restaura `_playbackRate` en lugar de forzar 1.0.
  - La hora estimada de fin divide el restante entre la velocidad activa.
  - Cadena ARB `playbackSpeed` (EN/ES) + `flutter gen-l10n`.
- Out:
  - Reproductor de música (SoLoud): el botón no se muestra (`_isAudio`).
  - Persistir la velocidad entre contenidos o entre sesiones.
  - Build o tests (según AGENTS.md).

## Checklist
- [x] FTD creado antes del primer cambio.
- [x] Cadena ARB `playbackSpeed` + `flutter gen-l10n`.
- [x] Estado y `setRate` integrados con el trick-play; `flutter analyze`.
- [x] Botón y menú hacia arriba en el transporte de vídeo; `flutter analyze`.
- [x] Hora de fin ajustada a la velocidad (`remaining / rate`); `flutter analyze`.
- [x] `flutter analyze` sin problemas (`No issues found!`).

## Evidence
- `_buildOverlay` en `player_screen.dart` monta `<<`, play y `>>` (`fast_forward_rounded`); el
  botón nuevo va inmediatamente después.
- `_SubtitleButton` y el menú de audio usan `PopupMenuButton` con `offset: Offset(0, -60)`,
  fondo `0xEE1A1A1A` y check en la opción activa: patrón a reutilizar.
- `media_kit` ya aplica `_player.setRate(...)`; hoy `_exitTrickPlay` fuerza `setRate(1.0)`, lo que
  borraría la velocidad elegida si no se cambia.
- `_isAudio`/`hasSoloud` distinguen audio de vídeo; el audio tiene su propia UI.
- Repositorio en rama `main`.
- `_playbackRate` (1.0) junto al estado del trick-play; `_setPlaybackRate` limita a 0.5–2.0,
  sale del trick-play y aplica `_player.setRate`.
- `_exitTrickPlay` restaura `_playbackRate` (antes forzaba 1.0), y `_stopPlayer` resetea a 1.0.
- `_PlaybackSpeedButton` (antes de `_SubtitleButton`): `PopupMenuButton<double>` con
  `offset: Offset(0, -60)`, fondo `0xEE1A1A1A`, título localizado, check y badge `Nx` cuando la
  velocidad no es 1. Se monta tras `fast_forward_rounded` y solo si `!_isAudio`.
- ARB `playbackSpeed` (EN/ES) generada con `flutter gen-l10n`.
- Hora de fin: el restante de medios (`effDuration - displayPos`) se divide por la velocidad
  activa (`_playbackRate` en vídeo, 1.0 en audio); a 2x queda la mitad de tiempo real que a 1x.
  Sin valor durante el trick-play, como antes.
- `flutter analyze` → `No issues found! (ran in 6.9s)`.

## Next
Probar en vídeo (directo y transcode) que el cambio de velocidad suena natural y que `<<`/`>>`
no la pierden; validar el menú con mando/TV. Con passthrough AC3/DTS puede no aplicarse en
algunos dispositivos (limitación conocida).
