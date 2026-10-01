/// Especificación de un emulador para un SO concreto.
class EmulatorOsSpec {
  const EmulatorOsSpec({
    this.downloadUrl,
    this.package,
    this.activity,
    this.cores = const {},
    this.args,
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

/// Emuladores disponibles para una plataforma.
class PlatformEmulators {
  const PlatformEmulators({
    required this.emulators,
    this.recommendedAndroid,
    this.recommendedWindows,
  });

  final List<String> emulators;
  final String? recommendedAndroid;
  final String? recommendedWindows;

  static PlatformEmulators fromJson(Map<String, dynamic> json) {
    final rec = (json['recommended'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PlatformEmulators(
      emulators: (json['emulators'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      recommendedAndroid: rec['android']?.toString(),
      recommendedWindows: rec['windows']?.toString(),
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
