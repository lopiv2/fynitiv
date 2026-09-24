# Mini-player escalado por plataforma

## Intent
El mini-player (OST/Jukebox) con `height: 64` y botones 18-22px se ve pequeño en TV (10-foot). Pasar a un factor de escala por `PlatformMode` centralizado en `ui_constants` y aplicado en `MiniPlayerBar`, con valor distinto por plataforma (`mobile 1.0 / desktop 1.0 / tv 1.4`), para ganar altura y hit-target en TV sin tocar PC/móvil.

## Scope
- In: `miniPlayerScaleFor(PlatformMode)` + `miniPlayerScaleProvider` en `lib/core/constants/ui_constants.dart` (mapa `mobile 1.0, desktop 1.0, tv 1.4`); `MiniPlayerBar` lee `s = ref.watch(miniPlayerScaleProvider)` y deriva `height 64*s`, `cover 48*s`, `iconos 22*s/20*s/18*s`, `fuentes 13*s/11*s`, `thumb 6*s/5*s`, `gaps/paddings/volWidth *s`; fallback `1.0` mientras `platformModeProvider` carga; Focus/D-pad intacto.
- Out: escalar resto de la app, persistir factor en settings, tocar `OstNowPlayingCard`/skins fullscreen, lógica de cola `soloud_music_provider`.

## Checklist
- [x] FTD doc creado antes del primer cambio — este fichero
- [x] `ui_constants.dart` expone mapa/provider — `flutter analyze` sin issues
- [x] `MiniPlayerBar` aplica `s` a alto/cover/iconos/textos/sliders — `flutter analyze` sin issues
- [x] `flutter analyze` global sin issues

## Evidence
- `flutter analyze` (2 ficheros) → "No issues found!"
- `flutter analyze` (global) → "No issues found!"

## Evidence
- Base: `MiniPlayerBar` en `lib/features/music/presentation/widgets/mini_player_bar.dart:84` con `height: 64`, `cover 48:130`, `iconos 18-22:172-229`, `textos 11/13:158-164` fijos; sin `PlatformMode`.
- `PlatformMode` en `lib/core/navigation/platform_mode.dart:19` (`FutureProvider<PlatformMode>` via `DeviceInfoPlugin` + `MethodChannel isTv` + `debugDeviceProvider`).
- `ui_constants.dart:1-51` sitio único de densidades; añadir mapa ahí evita duplicar y respeta reutilización (`AGENTS.md`).
- `home_shell.dart:265` aloja `MiniPlayerBar` en `Column` bajo `Expanded`; altura escalada no tapa contenido.

## Next
Ajustar valores del mapa si 1.4 queda invasivo (probar 1.35/1.5) y, si se quiere, replicar el patrón en `OstNowPlayingCard` (detalle) con el mismo provider.
