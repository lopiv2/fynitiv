# Jukebox — Ecualizador lateral (reuso AudioEqDrawer, sin auto-EQ)

## Intent
Cablear el botón `tune` ya existente arriba a la derecha del Jukebox para abrir el drawer lateral de ecualizador del music player normal (`AudioEqDrawer`), reutilizando `audioEqProvider`/`soloudMusicProvider` (mismo SoLoud). Sin lógica auto-EQ para ROMM porque `RommSoundtrackTrack` no trae género fiable.

## Scope
- In: FTD previo; `jukebox_screen.dart` importa `audio_eq_provider.dart` + `audio_eq_drawer.dart`; `_JukeboxTopHeader` envuelve tune en `AppHover` con `eqDrawerOpenProvider.notifier.toggle()`; `JukeboxScreen.build` envuelve `Scaffold` en `Stack` con overlay `Positioned.fill` (scrim + `Align(centerRight, AudioEqDrawer)` idéntico a `player_screen.dart:879`); no se invoca `applyAutoEqForGenres` para OST; `flutter analyze` sin issues.
- Out: Presets nuevos, auto-EQ por artista/álbum, ocultar switch auto-EQ solo en Jukebox (v2 si se pide), gen-l10n nuevo.

## Checklist
- [ ] FTD creado antes del primer cambio — este fichero
- [ ] Tune cableado a `eqDrawerOpenProvider` — `flutter analyze` sin issues
- [ ] Stack overlay con `AudioEqDrawer` + scrim — `flutter analyze` sin issues

## Evidence
- Botón inerte: `jukebox_screen.dart:1545` `Container tune_rounded` sin onTap.
- Drawer reutilizable: `lib/features/music/presentation/widgets/audio_eq_drawer.dart:15` 360px, `lib/features/music/application/audio_eq_provider.dart:323` `eqDrawerOpenProvider`, `lib/features/music/application/soloud_music_provider.dart:263` `_applyEq`.
- Track ROMM sin género: `lib/features/games/domain/romm_soundtrack_track.dart:6`.
- Patrón overlay: `lib/features/player/presentation/player_screen.dart:879`.

## Next
Probar que `SoLoud · EQ aplicado en vivo` se activa en Jukebox al mover bandas y que el scrim cierra el drawer; decidir si ocultar el toggle auto-EQ solo en Jukebox.
