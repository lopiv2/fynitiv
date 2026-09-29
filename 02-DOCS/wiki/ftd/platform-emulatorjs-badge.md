# Intent
Mostrar el icono play verde en tarjetas de plataforma de /games cuando la plataforma es jugable en navegador via EmulatorJS. Causa actual: el badge solo mira `/api/streaming/config` (contenedores nativos, `streaming.enabled=false` por defecto), asi que nunca aparece.

# Scope
- In: nuevo `lib/features/games/data/emulatorjs_playable.dart` con set de slugs EmulatorJS + `isEmulatorJsPlayable()` con normalizacion; `_PlatformCard` en `games_screen.dart` usa esa funcion pura en vez de `rommStreamingSlugsProvider`; solo tarjetas de /games, sin tocar `PrimeCardBadge` ni hover.
- Out: cambios en lista/detalle, streaming nativo, nuevos ARB, tests.

# Checklist
- [x] FTD creado antes del primer cambio — este fichero
- [x] `emulatorjs_playable.dart` con slugs EmulatorJS documentados
- [x] `_PlatformCard` muestra badge con funcion pura
- [x] `flutter analyze` sin issues

# Evidence
- Actual: `games_screen.dart:790` usa `rommStreamingSlugsProvider.select(...)` que devuelve `{}` si `streaming.enabled != true` (`romm_repository.dart:1175`).
- Docs ROMM EmulatorJS: `3DO | opera, Amiga | puae, Arcade/MAME | mame2003_plus/mame2003/fbneo, Atari 2600/5200/7800/Jaguar/Lynx, C64 | vice_x64sc, ColecoVision | gearcoleco, DOOM | prboom, GB/C/A | gambatte/mgba, MS-DOS | dosbox-pure, NGP/C | mednafen_ngp, NDS | melonds/desmume, N64 | mupen64plus_next/parallel_n64, NES | fceumm/nestopia, PC-FX | mednafen_pcfx, PS | mednafen_psx_hw/pcsx_rearmed, PSP | ppsspp, Sega 32X/CD/GG/MS/Genesis | picodrive/genesis_plus_gx, Saturn | mednafen_saturn/yabause, SNES | snes9x/bsnes, TG16/PCE | mednafen_pce, VB | mednafen_vb, WS/C | mednafen_wswan`.
- Respuesta usuario: Solo EmulatorJS + Solo tarjetas /games.

# Next
Validar visualmente en /games que NES/SNES/GB/Genesis/PS muestran play y que PS2/NGC sin EmulatorJS no lo muestran; decidir si se extiende a lista/detalle.
