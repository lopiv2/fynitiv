# Botón de parar en el reproductor de música a pantalla completa

## Intent
En el reproductor de música a pantalla completa (pestañas Portada / Letra /
Efectos) faltaba el botón de parar. Se añade entre play/pausa y "siguiente"
("forward"). El stop **no cierra** el reproductor: deja la pista cargada
detenida en la posición 0.

## Scope
- In: `lib/features/player/presentation/player_screen.dart`
  - `_stopAudio()`: si suena por SoLoud, `pause()` + `seek(Duration.zero)` (deja
    la pista cargada en stop, sin cerrar); si es el fallback local, pausa+seek(0)
    del `_player` legacy.
  - `_AudioCover`: nuevo callback `onStop`, cableado a `_stopAudio`.
  - Botón `Icons.stop_rounded` (vía `_CoverDarkButton`) insertado en las tres
    filas de controles (Portada, Letra, Efectos) entre play y siguiente.
- Out: `MiniPlayerBar` y el panel del Jukebox (fuera de alcance).

## Checklist
- [x] FTD antes del primer cambio
- [x] `_stopAudio` + callback `onStop`
- [x] Botón insertado en las 3 pestañas
- [x] El stop no cierra el reproductor
- [x] `flutter analyze` limpio

## Evidence
- `player_screen.dart`: `_stopAudio()` → `soloudMusicProvider.notifier).pause()`
  + `.seek(Duration.zero)` (o fallback `_player`), sin `pop`.
- `_AudioCover.onStop` cableado desde `onStop: _stopAudio`.
- Botón `_CoverDarkButton(Icons.stop_rounded)` entre `_CoverPlayButton` y el
  `skip_next` en los tres layouts.
- Revertido el cambio previo en `jukebox_now_playing_panel.dart` (target erróneo).
- `flutter analyze` → `No issues found!`.

## Next
- Cerrado. Validar en app que el stop deja la pista detenida en 0 sin salir del
  reproductor, en las tres pestañas.

