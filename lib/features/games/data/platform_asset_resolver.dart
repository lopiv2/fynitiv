import '../domain/romm_platform.dart';

/// Resuelve el logo local de una plataforma ROMM a un asset interno.
///
/// Single source de rutas: [_consoleAssets] es la única lista con paths completos.
/// [_aliasKey] mapea slug corto -> clave canónica normalizada (no repite el path).
/// El fallback normalizado usa [_normalizedMap] derivado de [_consoleAssets].
///
/// Si no hay coincidencia, devuelve null para que la UI use el logo de ROMM
/// o el fallback de icono.
class PlatformAssetResolver {
  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // Single source: lista completa de assets (Consoles + Handhelds Game Boy y ScummVM).
  static const List<String> _consoleAssets = [
    'assets/images/videogames/platforms/Consoles/3DO Interactive Multiplayer.png',
    'assets/images/videogames/platforms/Consoles/Amstrad GX4000.png',
    'assets/images/videogames/platforms/Consoles/APF Imagination Machine-04.png',
    'assets/images/videogames/platforms/Consoles/Apple Pippin.png',
    'assets/images/videogames/platforms/Arcade/Arcade Classics.png',
    'assets/images/videogames/platforms/Arcade/American Laser Games.png',
    'assets/images/videogames/platforms/Arcade/Atari Classics.png',
    'assets/images/videogames/platforms/Arcade/Banpresto.png',
    'assets/images/videogames/platforms/Arcade/Capcom Classics.png',
    'assets/images/videogames/platforms/Arcade/Capcom Play System II.png',
    'assets/images/videogames/platforms/Arcade/Capcom Play System III.png',
    'assets/images/videogames/platforms/Arcade/Capcom Play System.png',
    'assets/images/videogames/platforms/Arcade/Cave.png',
    'assets/images/videogames/platforms/Arcade/Daphne.png',
    'assets/images/videogames/platforms/Arcade/Data East Classics.png',
    'assets/images/videogames/platforms/Arcade/Eighting.png',
    'assets/images/videogames/platforms/Arcade/Final Burn Alpha.png',
    'assets/images/videogames/platforms/Arcade/Final Burn Neo.png',
    'assets/images/videogames/platforms/Arcade/Gaelco.png',
    'assets/images/videogames/platforms/Arcade/Hyper Neo Geo 64.png',
    'assets/images/videogames/platforms/Arcade/Irem Classics.png',
    'assets/images/videogames/platforms/Arcade/Jaleco Classics.png',
    'assets/images/videogames/platforms/Arcade/Kaneko.png',
    'assets/images/videogames/platforms/Arcade/Konami Classics.png',
    'assets/images/videogames/platforms/Arcade/MAME.png',
    'assets/images/videogames/platforms/Arcade/Midway Classics.png',
    'assets/images/videogames/platforms/Arcade/Namco Classics.png',
    'assets/images/videogames/platforms/Arcade/Namco System 22.png',
    'assets/images/videogames/platforms/Arcade/Nichibutsu.png',
    'assets/images/videogames/platforms/Arcade/Nintendo Classics.png',
    'assets/images/videogames/platforms/Arcade/Pinball.png',
    'assets/images/videogames/platforms/Arcade/PolyGame Master 2.png',
    'assets/images/videogames/platforms/Arcade/PolyGame Master.png',
    'assets/images/videogames/platforms/Arcade/Psikyo.png',
    'assets/images/videogames/platforms/Arcade/Raizing.png',
    'assets/images/videogames/platforms/Arcade/Romstar.png',
    'assets/images/videogames/platforms/Arcade/Sammy Atomiswave.png',
    'assets/images/videogames/platforms/Arcade/Sega Classics.png',
    'assets/images/videogames/platforms/Arcade/Sega Hikaru.png',
    'assets/images/videogames/platforms/Arcade/Sega Model 1.png',
    'assets/images/videogames/platforms/Arcade/Sega Model 2.png',
    'assets/images/videogames/platforms/Arcade/Sega Model 3 .png',
    'assets/images/videogames/platforms/Arcade/Sega Naomi 2.png',
    'assets/images/videogames/platforms/Arcade/Sega Naomi.png',
    'assets/images/videogames/platforms/Arcade/SEGA ST-V.png',
    'assets/images/videogames/platforms/Arcade/Sega System 16.png',
    'assets/images/videogames/platforms/Arcade/Sega System 32.png',
    'assets/images/videogames/platforms/Arcade/Sega Triforce.png',
    'assets/images/videogames/platforms/Arcade/Seibu Kaihatsu.png',
    'assets/images/videogames/platforms/Arcade/SNK Classics.png',
    'assets/images/videogames/platforms/Arcade/SNK Neo Geo MVS.png',
    'assets/images/videogames/platforms/Arcade/Stern.png',
    'assets/images/videogames/platforms/Arcade/Taito Classics.png',
    'assets/images/videogames/platforms/Arcade/Taito Type X.png',
    'assets/images/videogames/platforms/Arcade/Taito Type X2.png',
    'assets/images/videogames/platforms/Arcade/Technos.png',
    'assets/images/videogames/platforms/Arcade/Tecmo.png',
    'assets/images/videogames/platforms/Arcade/TeknoParrot.png',
    'assets/images/videogames/platforms/Arcade/Toaplan.png',
    'assets/images/videogames/platforms/Arcade/Universal.png',
    'assets/images/videogames/platforms/Arcade/Video System Co.png',
    'assets/images/videogames/platforms/Arcade/Visco.png',
    'assets/images/videogames/platforms/Arcade/Williams Classics.png',
    'assets/images/videogames/platforms/Consoles/Atari 2600.png',
    'assets/images/videogames/platforms/Consoles/Atari 5200.png',
    'assets/images/videogames/platforms/Consoles/Atari 7800.png',
    'assets/images/videogames/platforms/Consoles/Atari Jaguar CD.png',
    'assets/images/videogames/platforms/Consoles/Atari Jaguar.png',
    'assets/images/videogames/platforms/Consoles/Bally Astrocade.png',
    'assets/images/videogames/platforms/Consoles/Casio Loopy.png',
    'assets/images/videogames/platforms/Consoles/Casio PV-1000.png',
    'assets/images/videogames/platforms/Consoles/ColecoVision.png',
    'assets/images/videogames/platforms/Consoles/Commodore Amiga CD32.png',
    'assets/images/videogames/platforms/Consoles/Commodore CDTV.png',
    'assets/images/videogames/platforms/Consoles/Emerson Arcadia 2001.png',
    'assets/images/videogames/platforms/Consoles/Epoch Cassette Vision.png',
    'assets/images/videogames/platforms/Consoles/Epoch Super Cassette Vision.png',
    'assets/images/videogames/platforms/Consoles/Fairchild Channel F.png',
    'assets/images/videogames/platforms/Consoles/Fujitsu FM Towns Marty.png',
    'assets/images/videogames/platforms/Consoles/Funtech Super Acan.png',
    'assets/images/videogames/platforms/Consoles/GCE Vectrex.png',
    'assets/images/videogames/platforms/Consoles/Magnavox Odyssey 2.png',
    'assets/images/videogames/platforms/Consoles/Magnavox Odyssey.png',
    'assets/images/videogames/platforms/Consoles/Mattel Intellivision.png',
    'assets/images/videogames/platforms/Consoles/Microsoft Xbox 360.png',
    'assets/images/videogames/platforms/Consoles/Microsoft Xbox Game Pass.png',
    'assets/images/videogames/platforms/Consoles/Microsoft Xbox Live Arcade.png',
    'assets/images/videogames/platforms/Consoles/Microsoft Xbox One.png',
    'assets/images/videogames/platforms/Consoles/Microsoft Xbox Series.png',
    'assets/images/videogames/platforms/Consoles/Microsoft Xbox.png',
    'assets/images/videogames/platforms/Consoles/NEC PC Engine CD.png',
    'assets/images/videogames/platforms/Consoles/NEC PC Engine SuperGrafx.png',
    'assets/images/videogames/platforms/Consoles/NEC PC Engine.png',
    'assets/images/videogames/platforms/Consoles/NEC PC-FX.png',
    'assets/images/videogames/platforms/Consoles/NEC Turbo Duo.png',
    'assets/images/videogames/platforms/Consoles/NEC TurboGrafx-16.png',
    'assets/images/videogames/platforms/Consoles/NEC TurboGrafx-CD.png',
    'assets/images/videogames/platforms/Consoles/Nintendo 64.png',
    'assets/images/videogames/platforms/Consoles/Nintendo 64DD.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Color TV-Game.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Entertainment System.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Famicom Disk System.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Famicom.png',
    'assets/images/videogames/platforms/Handhelds/Nintendo Game Boy.png',
    'assets/images/videogames/platforms/Handhelds/Nintendo Game Boy Color.png',
    'assets/images/videogames/platforms/Handhelds/Nintendo Game Boy Advance.png',
    'assets/images/videogames/platforms/Handhelds/Android.png',
    'assets/images/videogames/platforms/Handhelds/Apple iOS.png',
    'assets/images/videogames/platforms/Handhelds/Atari Lynx.png',
    'assets/images/videogames/platforms/Handhelds/Sega Game Gear.png',
    'assets/images/videogames/platforms/Handhelds/Nintendo DS.png',
    'assets/images/videogames/platforms/Handhelds/Nintendo 3DS.png',
    'assets/images/videogames/platforms/Handhelds/Sony PSP.png',
    'assets/images/videogames/platforms/Handhelds/Sony PS Vita.png',
    'assets/images/videogames/platforms/Handhelds/SNK Neo Geo Pocket.png',
    'assets/images/videogames/platforms/Handhelds/SNK Neo Geo Pocket Color.png',
    'assets/images/videogames/platforms/Handhelds/Nokia N-Gage.png',
    'assets/images/videogames/platforms/Computers/ScummVM.png',
    'assets/images/videogames/platforms/Consoles/Nintendo GameCube.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Satellaview.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Sufami Turbo.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Super Famicom.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Super Game Boy 2.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Super Game Boy.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Switch eShop.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Switch.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Virtual Boy.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Wii U eShop.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Wii U.png',
    'assets/images/videogames/platforms/Consoles/Nintendo Wii.png',
    'assets/images/videogames/platforms/Consoles/Nintendo WiiWare.png',
    'assets/images/videogames/platforms/Consoles/OpenBOR.png',
    'assets/images/videogames/platforms/Consoles/Philips CD-i.png',
    'assets/images/videogames/platforms/Consoles/Phillips Videopac+.png',
    'assets/images/videogames/platforms/Consoles/Pico-8.png',
    'assets/images/videogames/platforms/Consoles/RCA Studio II.png',
    'assets/images/videogames/platforms/Consoles/Sega 32X.png',
    'assets/images/videogames/platforms/Consoles/Sega CD 32X.png',
    'assets/images/videogames/platforms/Consoles/Sega CD.png',
    'assets/images/videogames/platforms/Consoles/Sega Dreamcast.png',
    'assets/images/videogames/platforms/Consoles/Sega Genesis.png',
    'assets/images/videogames/platforms/Consoles/Sega Mark III.png',
    'assets/images/videogames/platforms/Consoles/Sega Master System.png',
    'assets/images/videogames/platforms/Consoles/Sega Mega Drive.png',
    'assets/images/videogames/platforms/Consoles/Sega Mega-CD.png',
    'assets/images/videogames/platforms/Consoles/Sega Saturn (Japan).png',
    'assets/images/videogames/platforms/Consoles/Sega Saturn.png',
    'assets/images/videogames/platforms/Consoles/Sega SG-1000.png',
    'assets/images/videogames/platforms/Consoles/SNK Neo Geo CD.png',
    'assets/images/videogames/platforms/Consoles/SNK Neo Geo.png',
    'assets/images/videogames/platforms/Consoles/Sony Playstation 2.png',
    'assets/images/videogames/platforms/Consoles/Sony PlayStation 3 Network.png',
    'assets/images/videogames/platforms/Consoles/Sony Playstation 3.png',
    'assets/images/videogames/platforms/Consoles/Sony Playstation 4.png',
    'assets/images/videogames/platforms/Consoles/Sony Playstation 5.png',
    'assets/images/videogames/platforms/Consoles/Sony PlayStation Network.png',
    'assets/images/videogames/platforms/Consoles/Sony Playstation VR.png',
    'assets/images/videogames/platforms/Consoles/Sony Playstation.png',
    'assets/images/videogames/platforms/Consoles/Super Nintendo Entertainment System.png',
    'assets/images/videogames/platforms/Consoles/VTech CreatiVision.png',
  ];

  static Map<String, String>? _byNormalized;

  static Map<String, String> get _normalizedMap {
    if (_byNormalized != null) return _byNormalized!;
    final m = <String, String>{};
    for (final p in _consoleAssets) {
      final base = p.split('/').last.replaceAll('.png', '');
      m[_normalize(base)] = p;
    }
    _byNormalized = m;
    return m;
  }

  // Alias slug corto -> clave canónica normalizada (no repite el path)
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
    'gb': 'nintendogameboy',
    'gameboy': 'nintendogameboy',
    'game-boy': 'nintendogameboy',
    'nintendo-game-boy': 'nintendogameboy',
    'gbc': 'nintendogameboycolor',
    'gameboy-color': 'nintendogameboycolor',
    'gameboycolor': 'nintendogameboycolor',
    'nintendo-game-boy-color': 'nintendogameboycolor',
    'gba': 'nintendogameboyadvance',
    'gameboy-advance': 'nintendogameboyadvance',
    'gameboyadvance': 'nintendogameboyadvance',
    'nintendo-game-boy-advance': 'nintendogameboyadvance',
    'gc': 'nintendogamecube',
    'ngc': 'nintendogamecube',
    'gamecube': 'nintendogamecube',
    'wii': 'nintendowii',
    'wiiu': 'nintendowiiu',
    'wii-u': 'nintendowiiu',
    'switch': 'nintendoswitch',
    'nswitch': 'nintendoswitch',
    'virtualboy': 'nintendovirtualboy',
    'vb': 'nintendovirtualboy',
    // Sega
    'genesis': 'segagenesis',
    'megadrive': 'segamegadrive',
    'mega-drive': 'segamegadrive',
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
    // Sony
    'ps': 'sonyplaystation',
    'psx': 'sonyplaystation',
    'ps1': 'sonyplaystation',
    'playstation': 'sonyplaystation',
    'ps2': 'sonyplaystation2',
    'ps3': 'sonyplaystation3',
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
    // SNK - Neo Geo AES usa misma imagen que SNK Neo Geo
    'neogeo': 'snkneogeo',
    'neo-geo': 'snkneogeo',
    'neo_geo': 'snkneogeo',
    'snk-neo-geo': 'snkneogeo',
    'neogeoaes': 'snkneogeo',
    'neo-geo-aes': 'snkneogeo',
    'aes': 'snkneogeo',
    'neogeo-mvs': 'snkneogeo',
    'neo-geo-mvs': 'snkneogeo',
    'mvs': 'snkneogeo',
    'ng': 'snkneogeo',
    'neogeocd': 'snkneogeocd',
    'neo-geo-cd': 'snkneogeocd',
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
    // Otros
    '3do': '3dointeractivemultiplayer',
    'scummvm': 'scummvm',
    'scumm': 'scummvm',
    'amiga-cd32': 'commodoreamigacd32',
    'cd32': 'commodoreamigacd32',
    'cdtv': 'commodorecdtv',
    'arcade': 'arcadeclassics',
    'mame': 'mame',
    'vectrex': 'gcevectrex',
    'intellivision': 'mattelintellivision',
    'odyssey2': 'magnavoxodyssey2',
    'odyssey': 'magnavoxodyssey',
    'colecovision': 'colecovision',
    'coleco': 'colecovision',
    'cdi': 'philipscdi',
  };

  /// Devuelve el asset local para [platform] o null si no hay coincidencia.
  static String? resolve(RommPlatform platform) {
    final map = _normalizedMap;
    // 1. alias por slug exacto -> clave canónica -> path
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

    // 3. fallback normalizado: probar name, displayName y slug contra mapa
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

    // 4. último intento: si el asset contiene al candidato o viceversa
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
