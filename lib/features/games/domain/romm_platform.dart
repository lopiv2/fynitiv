/// Plataforma (sistema) de la biblioteca de ROMM.
class RommPlatform {
  const RommPlatform({
    required this.id,
    required this.slug,
    required this.name,
    this.customName,
    this.romCount = 0,
    this.logoUrl,
    this.category,
    this.generation,
    this.familyName,
    this.familySlug,
    this.fsSizeBytes = 0,
    this.firmwareCount = 0,
  });

  final int id;
  final String slug;
  final String name;
  final String? customName;
  final int romCount;
  final String? logoUrl;
  final String? category;
  final int? generation;
  final String? familyName;
  final String? familySlug;
  final int fsSizeBytes;
  final int firmwareCount;

  String get displayName {
    if (customName != null && customName!.trim().isNotEmpty) return customName!.trim();
    if (name.trim().isNotEmpty) return name.trim();
    if (slug.trim().isNotEmpty) return _humanizeSlug(slug);
    return 'Desconocido';
  }

  static String _humanizeSlug(String slug) {
    return slug
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  RommPlatform copyWith({
    String? customName,
    String? logoUrl,
    String? category,
    int? generation,
    String? familyName,
    String? familySlug,
    int? fsSizeBytes,
    int? firmwareCount,
  }) {
    return RommPlatform(
      id: id,
      slug: slug,
      name: name,
      customName: customName ?? this.customName,
      romCount: romCount,
      logoUrl: logoUrl ?? this.logoUrl,
      category: category ?? this.category,
      generation: generation ?? this.generation,
      familyName: familyName ?? this.familyName,
      familySlug: familySlug ?? this.familySlug,
      fsSizeBytes: fsSizeBytes ?? this.fsSizeBytes,
      firmwareCount: firmwareCount ?? this.firmwareCount,
    );
  }
}