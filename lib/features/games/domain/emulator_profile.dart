/// Especificación de un emulador para un SO concreto.
class EmulatorOsSpec {
  const EmulatorOsSpec({
    this.downloadUrl,
    this.package,
    this.activity,
    this.cores = const {},
    this.args,
    this.subtitlesFlag,
    this.fullscreenFlag,
    this.retroarchCore,
  });

  /// URL para descargar/instalar (Play Store, web oficial, GitHub…).
  final String? downloadUrl;

  /// Paquete Android (`com.retroarch`).
  final String? package;

  /// Activity Android a lanzar.
  final String? activity;

  /// Mapa plataforma → core libretro (Android/RetroArch).
  final Map<String, String> cores;

  /// Plantilla de argumentos de Windows (`%ROM%` = ruta del juego).
  final String? args;

  /// Flag para habilitar subtítulos (si el emulador lo soporta).
  final String? subtitlesFlag;

  /// Flag para forzar pantalla completa (si el emulador lo soporta).
  final String? fullscreenFlag;

  /// Si está definido, este emulador es un **core de RetroArch**: el lanzador
  /// usa RetroArch con `-L <core>` en vez de un ejecutable propio.
  final String? retroarchCore;

  static EmulatorOsSpec fromJson(Map<String, dynamic> json) {
    return EmulatorOsSpec(
      downloadUrl: json['download_url']?.toString(),
      package: json['package']?.toString(),
      activity: json['activity']?.toString(),
      cores: (json['cores'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
      args: json['args']?.toString(),
      subtitlesFlag: json['subtitles_flag']?.toString(),
      fullscreenFlag: json['fullscreen_flag']?.toString(),
      retroarchCore: json['retroarch_core']?.toString(),
    );
  }
}

/// Emulador con sus especificaciones por SO.
class Emulator {
  const Emulator({
    required this.id,
    required this.name,
    this.android,
    this.windows,
  });

  final String id;
  final String name;
  final EmulatorOsSpec? android;
  final EmulatorOsSpec? windows;

  static Emulator fromJson(String id, Map<String, dynamic> json) {
    return Emulator(
      id: id,
      name: json['name']?.toString() ?? id,
      android: json['android'] is Map
          ? EmulatorOsSpec.fromJson(
              (json['android'] as Map).cast<String, dynamic>(),
            )
          : null,
      windows: json['windows'] is Map
          ? EmulatorOsSpec.fromJson(
              (json['windows'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

/// Descriptor declarativo de cómo un emulador/core de una plataforma
/// guarda sus partidas/estados, para poder mapearlas al `rom_id` de RomM.
class EmulatorSaveLayout {
  const EmulatorSaveLayout({
    this.idSource = 'stem',
    this.savesSubdir = '',
    this.statesSubdir = '',
  });

  /// Cómo se identifica el juego en el nombre del save:
  /// `stem` (nombre base del ROM), `scummvm_gameid` (gameid de ScummVM) o
  /// `title_id` (ID nativo, futuro).
  final String idSource;

  /// Subcarpeta (relativa a `saves/`) donde el emulador/core escribe; '' = raíz.
  final String savesSubdir;

  /// Subcarpeta (relativa a `states/`) donde el emulador/core escribe; '' = raíz.
  final String statesSubdir;

  bool get usesScummVmGameId => idSource == 'scummvm_gameid';

  static EmulatorSaveLayout fromJson(Map<String, dynamic> json) {
    return EmulatorSaveLayout(
      idSource: json['id_source']?.toString() ?? 'stem',
      savesSubdir: json['saves_subdir']?.toString() ?? '',
      statesSubdir: json['states_subdir']?.toString() ?? '',
    );
  }
}

/// Emuladores disponibles para una plataforma.
class PlatformEmulators {
  const PlatformEmulators({
    required this.emulators,
    this.recommendedAndroid,
    this.recommendedWindows,
    this.saveLayout = const EmulatorSaveLayout(),
  });

  final List<String> emulators;
  final String? recommendedAndroid;
  final String? recommendedWindows;
  final EmulatorSaveLayout saveLayout;

  static PlatformEmulators fromJson(Map<String, dynamic> json) {
    final rec = (json['recommended'] as Map?)?.cast<String, dynamic>() ?? const {};
    final layout = json['save_layout'];
    return PlatformEmulators(
      emulators: (json['emulators'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      recommendedAndroid: rec['android']?.toString(),
      recommendedWindows: rec['windows']?.toString(),
      saveLayout: layout is Map
          ? EmulatorSaveLayout.fromJson(layout.cast<String, dynamic>())
          : const EmulatorSaveLayout(),
    );
  }
}

/// Catálogo completo cargado desde `assets/data/emulators.json`.
class EmulatorCatalog {
  const EmulatorCatalog({
    required this.emulators,
    required this.platforms,
    required this.aliases,
  });

  final Map<String, Emulator> emulators;
  final Map<String, PlatformEmulators> platforms;
  final Map<String, String> aliases;

  static String normalize(String slug) => slug
      .trim()
      .toLowerCase()
      .replaceAll('-', '')
      .replaceAll('_', '')
      .replaceAll(' ', '');

  /// Resuelve un slug de RomM a la clave canónica del catálogo (con alias).
  String canonicalSlug(String slug) {
    final norm = normalize(slug);
    return aliases[norm] ?? norm;
  }

  PlatformEmulators? forPlatform(String slug) => platforms[canonicalSlug(slug)];

  Emulator? emulatorById(String? id) =>
      id == null ? null : emulators[id];

  static EmulatorCatalog fromJson(Map<String, dynamic> json) {
    final emulators = <String, Emulator>{};
    (json['emulators'] as Map? ?? const {}).forEach((k, v) {
      emulators[k.toString()] =
          Emulator.fromJson(k.toString(), (v as Map).cast<String, dynamic>());
    });
    final platforms = <String, PlatformEmulators>{};
    (json['platforms'] as Map? ?? const {}).forEach((k, v) {
      platforms[k.toString()] = PlatformEmulators.fromJson(
        (v as Map).cast<String, dynamic>(),
      );
    });
    final aliases = <String, String>{};
    (json['aliases'] as Map? ?? const {}).forEach((k, v) {
      aliases[normalize(k.toString())] = v.toString();
    });
    return EmulatorCatalog(
      emulators: emulators,
      platforms: platforms,
      aliases: aliases,
    );
  }
}
