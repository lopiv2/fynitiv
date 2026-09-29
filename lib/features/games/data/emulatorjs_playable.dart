/// Slugs jugables en navegador via EmulatorJS (ROMM Play button).
/// Fuente: docs ROMM In-Browser Play -> EmulatorJS (cores por plataforma).
/// Se normaliza quitando `-`, `_` y espacios para tolerar variantes
/// de slug (p. ej. `gameboy-advance`, `gba`, `megadrive`/`genesis`).
const _emulatorJsSlugs = <String>{
  // 3DO | opera
  '3do',
  // Amiga | puae
  'amiga',
  'amigacd',
  'amigacdtv',
  'cdtv',
  // Arcade/MAME | mame2003_plus, mame2003, fbneo
  'arcade',
  'mame',
  // Atari 2600/5200/7800/Jaguar/Lynx | stella2014, atari800, prosystem...
  'atari2600',
  'atari5200',
  'atari7800',
  'atari800',
  'atarijaguar',
  'jaguar',
  'atarilynx',
  'lynx',
  'atarist',
  // Commodore 64 | vice_x64sc
  'c64',
  'commodore64',
  'c128',
  // ColecoVision | gearcoleco
  'colecovision',
  'coleco',
  // DOOM | prboom
  'doom',
  // Game Boy/Color/Advance | gambatte, mgba
  'gb',
  'gbc',
  'gba',
  'gameboy',
  'gameboycolor',
  'gameboyadvance',
  // MS-DOS | dosbox-pure
  'msdos',
  'dos',
  'msx',
  'msx2',
  // Neo Geo Pocket/Color | mednafen_ngp
  'ngp',
  'ngpc',
  'neogeopocket',
  'neogeopocketcolor',
  // Nintendo DS | melonds, desmume
  'nds',
  'nintendods',
  'ds',
  // Nintendo 64 | mupen64plus_next, parallel_n64
  'n64',
  'nintendo64',
  // NES/Famicom | fceumm, nestopia
  'nes',
  'famicom',
  'fc',
  'fds',
  'famicomdisksystem',
  // PC-FX | mednafen_pcfx
  'pcfx',
  'pcengine',
  'pce',
  'tg16',
  'turbografx16',
  'turbografxcd',
  // PlayStation | mednafen_psx_hw, pcsx_rearmed
  'ps',
  'psx',
  'ps1',
  'playstation',
  // PSP | ppsspp
  'psp',
  // Sega 32X/CD/Game Gear/Master System/Genesis | picodrive, genesis_plus_gx
  'sega32x',
  '32x',
  'segacd',
  'segacdm',
  'megacd',
  'gamegear',
  'gg',
  'mastersystem',
  'sms',
  'genesis',
  'megadrive',
  'sg1000',
  // Sega Saturn | mednafen_saturn, yabause
  'saturn',
  'segasaturn',
  // SNES/Super Famicom | snes9x, bsnes
  'snes',
  'sfc',
  'supernintendo',
  'superfamicom',
  // Virtual Boy | mednafen_vb
  'virtualboy',
  'vb',
  // WonderSwan/Color | mednafen_wswan
  'wonderswan',
  'wonderswancolor',
  'ws',
  'wsc',
};

String _normalizeSlug(String slug) => slug
    .trim()
    .toLowerCase()
    .replaceAll('-', '')
    .replaceAll('_', '')
    .replaceAll(' ', '');

/// True si la plataforma tiene core EmulatorJS y por tanto
/// muestra el badge play en la tarjeta de /games.
bool isEmulatorJsPlayable(String slug) =>
    _emulatorJsSlugs.contains(_normalizeSlug(slug));
