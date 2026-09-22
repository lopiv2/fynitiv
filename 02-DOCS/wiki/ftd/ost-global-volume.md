# OST: botón de volumen con slider + volumen global compartido

## Intent
El botón de volumen del reproductor OST solo silencia. Debe abrir un slider como el del player de música, y ese volumen debe ser el global (`appVolumeProvider` 0..100) compartido con el player de música. El OST hoy ignora el global (volumen fijo 0.5 hardcoded).

## Scope
- In: widget genérico reutilizable `VolumePopupButton` en `core/widgets` (botón + popup con slider, % y mute); `GameOstPlayer.setVolume` + volumen por defecto desde el global; `SoloudSinglePlayer.applyVolume` (aplica en vivo); `_OstNowPlayingCard` → ConsumerState con `ref.listen` al global (sin side-effects en build); reutilizar ARB existentes (`volume`, `ostMute`, `ostUnmute`).
- Out: cambios en el player de música (ya usa el global; adoptará el widget genérico después), GameBgPlayer/ItemThemePlayer, nuevos textos ARB.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] `SoloudSinglePlayer.applyVolume` (guarda + aplica en vivo si suena)
- [x] `GameOstPlayer.setVolume` + usa `_volume` en vez de 0.5 fijo
- [x] `VolumeSliderRow` genérico en `core/widgets` (mute + slider 0..100 + %; inline como el player de música, sin overlay → sin problemas de foco TV ni back button)
- [x] OST usa la fila expansible + lee/aplica `appVolumeProvider` (init + listen, sin escribir de vuelta; `_OstNowPlayingCard` → ConsumerState)
- [x] `flutter analyze` (4 ficheros) → "No issues found!" (sin textos nuevos → sin regen ARB; tooltips reutilizan `volume`, `ostMute`, `ostUnmute`)

## Evidence
- Global ya existe: `app_volume_provider.dart` (0..100, persistido) usado por `soloud_music_provider`, `music_player_provider`, `deezer_preview_player`.
- OST hardcoded: `game_ost_player.dart` `volume: 0.5` y `SoloudSinglePlayer(volume: 0.5)`; botón actual `game_detail_screen.dart:1045-1055` solo hace `setMuted`.
- Patrón slider música: `deezer_preview_player.dart:115-155` (IconButton + Slider + %).
- `flutter analyze` → pendiente.

## Next
Abrir detalle con OST, pulsar volumen, mover slider y comprobar que el player de música hereda el mismo nivel.
