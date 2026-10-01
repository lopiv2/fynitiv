/// Modelos de caja 3D por plataforma.
///
/// Todas las cajas comparten la misma altura (mismo tamaño en escena); lo que
/// cambia es la forma: sobre todo el grosor (`depth`, que define el ancho del
/// lomo) y, en las cajas grandes, también el ancho (`width`).
///
/// La resolución es automática por slug de plataforma (normalizado sin `-`,
/// `_` ni espacios) y cae a [BoxModel.defaultBox] si no coincide.
enum BoxModel {
  /// Cartucho estándar (NES/SNES/N64/Mega Drive/Game Boy/Atari…).
  cartridge(width: 1.00, height: 1.00, depth: 0.15),

  /// Jewel case de CD (PS1, Saturn, Dreamcast, Sega CD, PC Engine CD…).
  cdJewel(width: 1.00, height: 1.00, depth: 0.10),

  /// Caja tipo DVD (PS2, Xbox, Wii, GameCube, DS, PSP, Vita…).
  dvdCase(width: 1.00, height: 1.40, depth: 0.16),

  /// Caja tipo Blu-ray (PS3/4/5, Xbox One/Series, Switch…).
  bluRayCase(width: 1.00, height: 1.40, depth: 0.13),

  /// Snap-lock grueso (Neo Geo AES/MVS).
  neoGeoSnap(width: 1.00, height: 1.40, depth: 0.34),

  /// Caja grande de PC/ordenadores (DOS, Amiga, C64, MSX, ScummVM…):
  /// más ancha y profunda.
  bigBox(width: 1.18, height: 1.40, depth: 0.22),

  /// Forma por defecto.
  defaultBox(width: 1.00, height: 1.40, depth: 0.18);

  const BoxModel({
    required this.width,
    required this.height,
    required this.depth,
  });

  final double width;
  final double height;
  final double depth;

  /// Dimensiones `[w, h, d]` que consume el visor.
  List<double> get size => <double>[width, height, depth];

  static String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Slugs (normalizados) por modelo. Un único origen por modelo; el orden de
  /// las claves importa solo si un slug apareciera en dos sets (no debería).
  static const Map<BoxModel, Set<String>> _slugs = <BoxModel, Set<String>>{
    BoxModel.cartridge: <String>{
      'nes', 'nintendones', 'famicom', 'fds', 'famicomdisksystem',
      'snes', 'supernes', 'supernintendo', 'superfamicom', 'sfc',
      'n64', 'nintendo64', 'n64dd',
      'gb', 'gameboy', 'gbc', 'gameboycolor', 'gba', 'gameboyadvance',
      'genesis', 'megadrive', 'segagenesis',
      'mastersystem', 'segamastersystem', 'sms', 'sg1000', 'segasg1000',
      'gamegear', 'segagamegear', 'gg',
      'vb', 'virtualboy',
      'atari2600', '2600', 'atari5200', '5200', 'atari7800', '7800',
      'jaguar', 'atarijaguar', 'atarilynx', 'lynx',
      'intellivision', 'mattelintellivision', 'colecovision', 'coleco',
      'odyssey2', 'magnavoxodyssey2', 'vectrex', 'gcevectrex',
      'neogeopocket', 'ngp', 'neogeopocketcolor', 'ngpc',
      'wonderswan', 'wonderswancolor', 'ws', 'wsc',
    },
    BoxModel.cdJewel: <String>{
      'ps', 'psx', 'ps1', 'playstation',
      'saturn', 'segasaturn',
      'dreamcast', 'segadreamcast', 'dc',
      'segacd', 'segacdm', 'megacd', 'segamegacd',
      'pcengine', 'pce', 'turbografx16', 'tg16', 'turbografxcd', 'pcecd',
      'neogeocd', '3do', '3dointeractivemultiplayer',
      'cdi', 'philipscdi', 'pcfx', 'necpcfx',
    },
    BoxModel.dvdCase: <String>{
      'ps2', 'sonyps2',
      'xbox', 'microsoftxbox', 'xbox360', 'x360', 'microsoftxbox360',
      'wii', 'nintendowii', 'gc', 'ngc', 'gamecube',
      'nds', 'nintendods', 'ds', 'n3ds', 'nintendo3ds', '3ds',
      'psp', 'sonypsp', 'psvita', 'sonypsvita', 'psv', 'vita',
    },
    BoxModel.bluRayCase: <String>{
      'ps3', 'sonyps3', 'ps4', 'ps5',
      'xboxone', 'xbone', 'microsoftxboxone',
      'xboxseries', 'seriesx', 'microsoftxboxseries',
      'switch', 'nswitch', 'nintendoswitch', 'wiiu', 'nintendowii',
    },
    BoxModel.neoGeoSnap: <String>{
      'neogeo', 'neogeoaes', 'aes', 'neogeomvs', 'mvs', 'snkneogeo', 'ng',
    },
    BoxModel.bigBox: <String>{
      'dos', 'msdos', 'msdospc', 'pc', 'windows', 'win', 'win3x',
      'windows3x', 'computer',
      'amiga', 'amigacd', 'amigacd32', 'cd32', 'commodoreamigacd32',
      'cdtv', 'commodorecdtv',
      'c64', 'commodore64', 'c128', 'msx', 'msx2',
      'scummvm', 'scumm', 'atarist',
    },
  };

  /// Modelo de caja para un slug de plataforma de ROMM.
  static BoxModel forSlug(String slug) {
    final n = _normalize(slug);
    if (n.isEmpty) return BoxModel.defaultBox;
    for (final entry in _slugs.entries) {
      if (entry.value.contains(n)) return entry.key;
    }
    return BoxModel.defaultBox;
  }
}
