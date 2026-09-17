import '../domain/romm_platform.dart';

/// Resuelve la imagen de la **máquina/consola** centrada en la tarjeta de plataforma.
///
/// Usa assets en `assets/images/videogames/machines/` (ej. `Atari 2600.png`).
/// Si no hay coincidencia devuelve `null` para no mostrar nada en el centro.
///
/// Estructura idéntica a [PlatformAssetResolver]: single source [_machineAssets],
/// alias manual slug -> clave canónica normalizada, fallback normalizado.
class PlatformMachineAssetResolver {
  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // Single source: lista de assets de máquinas. Añadir aquí cada nuevo png..
  static const List<String> _machineAssets = [
    'assets/images/videogames/machines/Atari 2600.png',
    'assets/images/videogames/machines/Atari 5200.png',
    'assets/images/videogames/machines/Atari 7800.png',
    'assets/images/videogames/machines/Coleco Vision.png',
    'assets/images/videogames/machines/Gameboy Advance.png',
    'assets/images/videogames/machines/Gameboy Color.png',
    'assets/images/videogames/machines/Gameboy.png',
    'assets/images/videogames/machines/Gamecube.png',
    'assets/images/videogames/machines/NeoGeo AVS.png',
    'assets/images/videogames/machines/Nintendo 3DS.png',
    'assets/images/videogames/machines/Nintendo 64.png',
    'assets/images/videogames/machines/Nintendo DS.png',
    'assets/images/videogames/machines/Nintendo Switch.png',
    'assets/images/videogames/machines/Nintendo Wii.png',
    'assets/images/videogames/machines/Sega Genesis.png',
    'assets/images/videogames/machines/Sony PS1.png',
    'assets/images/videogames/machines/Sony PS2.png',
    'assets/images/videogames/machines/Sony PS3.png',
    'assets/images/videogames/machines/Sony PSP.png',
    'assets/images/videogames/machines/Computer.png',
    'assets/images/videogames/machines/ScummVM.png',
    'assets/images/videogames/machines/Arcade Machine.png',
  ];

  static Map<String, String>? _byNormalized;

  static Map<String, String> get _normalizedMap {
    if (_byNormalized != null) return _byNormalized!;
    final m = <String, String>{};
    for (final p in _machineAssets) {
      final base = p.split('/').last.replaceAll('.png', '');
      m[_normalize(base)] = p;
    }
    _byNormalized = m;
    return m;
  }

  // Alias slug corto -> clave canónica normalizada (no repite el path).
  // Claves ajustadas a los nombres reales de assets en machines/
  // (ej. gba -> gameboyadvance, neogeo -> neogeoavs, ps1 -> sonyps1).
  static const Map<String, String> _aliasKey = {
    // Nintendo
    'nes': 'nintendoentertainmentsystem',
    'famicom': 'nintendofamicom',
    'fds': 'nintendofamicomdisksystem',
    'snes': 'supernintendoentertainmentsystem',
    'super-nintendo': 'supernintendoentertainmentsystem',
    'super-famicom': 'nintendosuperfamicom',
    'n64': 'nintendo64',
    'n64dd': 'nintendo64dd',
    '64dd': 'nintendo64dd',
    'gb': 'gameboy',
    'gameboy': 'gameboy',
    'game-boy': 'gameboy',
    'nintendo-game-boy': 'gameboy',
    'gbc': 'gameboycolor',
    'gameboy-color': 'gameboycolor',
    'gameboycolor': 'gameboycolor',
    'nintendo-game-boy-color': 'gameboycolor',
    'gba': 'gameboyadvance',
    'gameboy-advance': 'gameboyadvance',
    'gameboyadvance': 'gameboyadvance',
    'nintendo-game-boy-advance': 'gameboyadvance',
    'gc': 'gamecube',
    'ngc': 'gamecube',
    'gamecube': 'gamecube',
    'wii': 'nintendowii',
    'wiiu': 'nintendowii',
    'wii-u': 'nintendowii',
    'switch': 'nintendoswitch',
    'nswitch': 'nintendoswitch',
    'virtualboy': 'nintendovirtualboy',
    'vb': 'nintendovirtualboy',
    // Sega
    'genesis': 'segagenesis',
    'megadrive': 'segagenesis',
    'mega-drive': 'segagenesis',
    'segagenesis': 'segagenesis',
    'sms': 'segamastersystem',
    'mastersystem': 'segamastersystem',
    'mark-iii': 'segamarkiii',
    'sg-1000': 'segasg1000',
    'sg1000': 'segasg1000',
    '32x': 'sega32x',
    'sega32x': 'sega32x',
    'sega-cd': 'segacd',
    'segacd': 'segacd',
    'mega-cd': 'segamegacd',
    'megacd': 'segamegacd',
    'saturn': 'segasaturn',
    'sega-saturn': 'segasaturn',
    'dreamcast': 'segadreamcast',
    'dc': 'segadreamcast',
    // Sony - máquinas usan Sony PS1/PS2/PS3
    'ps': 'sonyps1',
    'psx': 'sonyps1',
    'ps1': 'sonyps1',
    'sonyps1': 'sonyps1',
    'playstation': 'sonyps1',
    'ps2': 'sonyps2',
    'sonyps2': 'sonyps2',
    'ps3': 'sonyps3',
    'sonyps3': 'sonyps3',
    'ps4': 'sonyplaystation4',
    'ps5': 'sonyplaystation5',
    'psn': 'sonyplaystationnetwork',
    'psvr': 'sonyplaystationvr',
    // Microsoft
    'xbox': 'microsoftxbox',
    'xbox360': 'microsoftxbox360',
    'x360': 'microsoftxbox360',
    'xbox-one': 'microsoftxboxone',
    'xbone': 'microsoftxboxone',
    'xbox-series': 'microsoftxboxseries',
    'series-x': 'microsoftxboxseries',
    // NEC
    'pce': 'necpcengine',
    'pcengine': 'necpcengine',
    'tg16': 'necturbografx16',
    'turbografx16': 'necturbografx16',
    'turbo-cd': 'necturbografxcd',
    'pc-fx': 'necpcfx',
    'pcfx': 'necpcfx',
    'supergrafx': 'necpcenginesupergrafx',
    'turboduo': 'necturboduo',
    // SNK - máquina es NeoGeo AVS.png -> neogeoavs
    'neogeo': 'neogeoavs',
    'neo-geo': 'neogeoavs',
    'neo_geo': 'neogeoavs',
    'snk-neo-geo': 'neogeoavs',
    'neogeoaes': 'neogeoavs',
    'neo-geo-aes': 'neogeoavs',
    'aes': 'neogeoavs',
    'neogeo-mvs': 'neogeoavs',
    'neo-geo-mvs': 'neogeoavs',
    'mvs': 'neogeoavs',
    'ng': 'neogeoavs',
    'neogeoavs': 'neogeoavs',
    'snkneogeo': 'neogeoavs',
    'neogeocd': 'neogeocd',
    'neo-geo-cd': 'neogeocd',
    // Atari
    'atari2600': 'atari2600',
    '2600': 'atari2600',
    'atari5200': 'atari5200',
    '5200': 'atari5200',
    'atari7800': 'atari7800',
    '7800': 'atari7800',
    'jaguar': 'atarijaguar',
    'jaguar-cd': 'atarijaguarcd',
    // Sony Handhelds
    'psp': 'sonypsp',
    'sony-psp': 'sonypsp',
    'psvita': 'sonypsvita',
    'ps-vita': 'sonypsvita',
    'vita': 'sonypsvita',
    'psv': 'sonypsvita',
    'sonypsvita': 'sonypsvita',
    'pspminis': 'sonypspminis',
    'psp-minis': 'sonypspminis',
    // Handhelds varios
    'lynx': 'atarilynx',
    'atari-lynx': 'atarilynx',
    'gamegear': 'segagamegear',
    'sega-game-gear': 'segagamegear',
    'nds': 'nintendods',
    'n3ds': 'nintendo3ds',
    '3ds': 'nintendo3ds',
    'neogeopocket': 'snkneogeopocket',
    'ngp': 'snkneogeopocket',
    'ngpc': 'snkneogeopocketcolor',
    // Windows / PC / DOS -> Computer.png
    'windows': 'computer',
    'win': 'computer',
    'pc': 'computer',
    'dos': 'computer',
    'msdos': 'computer',
    'ms-dos': 'computer',
    'msdospc': 'computer',
    'win3x': 'computer',
    'windows3x': 'computer',
    'windows-3x': 'computer',
    'computer': 'computer',
    // ScummVM -> ScummVM.png (separado de Computer.png)
    'scummvm': 'scummvm',
    'scumm': 'scummvm',
    // Arcade -> Arcade Machine.png
    'arcade': 'arcademachine',
    'arcade-machine': 'arcademachine',
    'arcademachine': 'arcademachine',
    'mame': 'arcademachine',
    // Otros
    '3do': '3dointeractivemultiplayer',
    'amiga-cd32': 'commodoreamigacd32',
    'cd32': 'commodoreamigacd32',
    'cdtv': 'commodorecdtv',
    'vectrex': 'gcevectrex',
    'intellivision': 'mattelintellivision',
    'odyssey2': 'magnavoxodyssey2',
    'odyssey': 'magnavoxodyssey',
    'colecovision': 'colecovision',
    'coleco': 'colecovision',
    'cdi': 'philipscdi',
  };

  /// Devuelve el asset de máquina para [platform] o null si no hay imagen.
  static String? resolve(RommPlatform platform) {
    final map = _normalizedMap;

    // 1. alias por slug exacto
    final slugKey = platform.slug.trim().toLowerCase();
    final alias = _aliasKey[slugKey];
    if (alias != null) {
      final path = map[alias];
      if (path != null) return path;
    }

    // 2. alias por slug normalizado
    final slugNorm = _normalize(slugKey);
    final aliasNorm = _aliasKey[slugNorm];
    if (aliasNorm != null) {
      final path = map[aliasNorm];
      if (path != null) return path;
    }

    // 3. fallback normalizado: probar displayName, name, slug, customName
    final candidates = [
      platform.displayName,
      platform.name,
      platform.slug,
      platform.customName ?? '',
    ];
    for (final c in candidates) {
      if (c.trim().isEmpty) continue;
      final n = _normalize(c);
      if (map.containsKey(n)) return map[n];
    }

    // 4. último intento: contiene / contenido
    for (final c in candidates) {
      if (c.trim().length < 3) continue;
      final n = _normalize(c);
      for (final entry in map.entries) {
        if (entry.key.contains(n) || n.contains(entry.key)) {
          if (n.length >= 4 && entry.key.length >= 4) return entry.value;
        }
      }
    }

    return null;
  }
}
