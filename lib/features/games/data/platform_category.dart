/// Categoría derivada del asset path para filtrado UI.
enum PlatformCategory { all, consoles, handhelds, computers, arcade }

extension PlatformCategoryX on PlatformCategory {
  String get label {
    switch (this) {
      case PlatformCategory.all:
        return 'Todas';
      case PlatformCategory.consoles:
        return 'Consolas';
      case PlatformCategory.handhelds:
        return 'Portátiles';
      case PlatformCategory.computers:
        return 'Ordenadores';
      case PlatformCategory.arcade:
        return 'Arcade';
    }
  }
}

/// Determina categoría por el asset local; si no hay asset usa slug heurística.
PlatformCategory categoryForAsset(String? assetPath, String slug) {
  if (assetPath != null) {
    if (assetPath.contains('/Consoles/')) return PlatformCategory.consoles;
    if (assetPath.contains('/Handhelds/')) return PlatformCategory.handhelds;
    if (assetPath.contains('/Computers/')) return PlatformCategory.computers;
    if (assetPath.contains('/Arcade/')) return PlatformCategory.arcade;
  }
  final s = slug.toLowerCase();
  if (['gb', 'gbc', 'gba', 'nds', 'n3ds', 'psp', 'psvita', 'lynx', 'gamegear', 'ngp', 'ngpc'].contains(s)) {
    return PlatformCategory.handhelds;
  }
  if (['scummvm', 'dos', 'amiga', 'c64', 'msx', 'pc'].contains(s)) return PlatformCategory.computers;
  if (['arcade', 'mame', 'neogeo'].contains(s)) return PlatformCategory.arcade;
  return PlatformCategory.consoles;
}

PlatformCategory categoryForPlatform(String? assetPath, String slug) => categoryForAsset(assetPath, slug);
