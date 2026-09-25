# Transporte con rebobinado clásico + volumen en línea en el player

## Intent
El player de vídeo no tiene botones visibles de rebobinado/avance (solo teclado ←/→) y el volumen vive en un popup. Añadir transporte `<< play >>` con saltos acumulativos de 10s e insignia temporal x2/x3/x4, etiqueta "Termina a las HH:MM", y slider de volumen en línea (sin diálogo) reutilizado en vídeo y en la portada de música.

## Scope
- In: `lib/features/player/presentation/player_screen.dart` — estado `_ffPresses`+`Timer` en `_PlayerViewState`, botones `_SkipButton`, insignia de velocidad, etiqueta de hora fin, widget `_InlineVolume` usado en `_buildOverlay()` y `_AudioCover`; clave ARB `endsAtHour` (EN+ES) + `flutter gen-l10n`.
- Out: velocidad negativa real (`setRate`, no fiable en mpv), cambios en skins, otros botones de la imagen 2 (favorito, ajustes, modos).

## Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] Transporte `<< play >>` con saltos acumulativos e insignia xN temporal
- [x] Etiqueta "Termina a las HH:MM" junto al transporte
- [x] `_InlineVolume` en vídeo y en `_AudioCover` (adiós al popup)
- [x] ARB `endsAtHour` (+ `rewind`/`fastForward`) EN+ES + gen-l10n
- [x] `flutter analyze` sin issues en el fichero tocado

## Evidence
- `flutter analyze lib/features/player/presentation/player_screen.dart` → "No issues found!".
- `flutter gen-l10n` regeneró `rewind`/`fastForward`/`endsAtHour` (verificado en `app_localizations*.dart`).
- Caso borde: `<<` desde la pantalla de fin reanuda desde el punto del salto (`resumeFromEnd`), sin pasar por el replay desde cero.

## Next
- Prueba manual del usuario: pulsaciones acumuladas, fin → play reanuda, volumen inline en vídeo y música.

---

# Follow-up: trick-play estilo Amazon x2→x64

## Intent
Lo acumulativo no era lo pedido: estilo Amazon — mientras se pulsa avanzar, la peli/serie avanza a 2x real, otra pulsación 4x, en múltiplos de 2 hasta 64x. `media_kit` 1.2.6 rechaza `setRate <= 0`, así que el avance es velocidad real y el rebobinado se emula con seeks periódicos.

## Scope
- In: máquina de estados `_trickDir`/`_trickLevel` (`[2,4,8,16,32,64]`, tope se queda en 64x), avance con `setRate`, reversa emulada (pausa + `Timer.periodic(250ms)` con seek atrás), mute durante trick-play con restauración, insignia persistente, "Termina a las" oculta en trick-play; ARB `rewind`/`fastForward` actualizadas (ya no son 10 s).
- Out: modo audio (`_AudioCover` conserva saltos ±10 s), skins.

## Checklist
- [x] FTD follow-up creado antes del primer cambio — este apartado
- [x] Avance real 2x→64x con `setRate` + insignia persistente
- [x] Rebobinado emulado −2x→−64x por temporizador
- [x] Mute durante trick-play + restauración al salir; salidas: play, dirección contraria, seek, slider, flechas
- [x] ARB actualizadas + gen-l10n
- [x] `flutter analyze` sin issues

## Evidence
- `flutter analyze lib/features/player/presentation/player_screen.dart` → "No issues found!".
- `flutter gen-l10n` regeneró `rewind`/`fastForward` (`Rebobinar (x2, x4, hasta x64)` / `Fast forward (x2, x4, up to x64)`).
- `setRate <= 0` lanza `ArgumentError` en media_kit 1.2.6 (`native/real.dart:809`): la reversa solo puede ser emulada.
- Limitación conocida: en streams transcodificados el servidor envía a tiempo real → a 16x+ puede buferear; en direct play va fluido.

## Next
- Prueba manual en direct play: subir a 64x, salir con play (volumen restaurado), reversa escalonada.
