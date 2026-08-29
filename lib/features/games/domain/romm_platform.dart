/// Plataforma (sistema) de la biblioteca de ROMM.
class RommPlatform {
  const RommPlatform({
    required this.id,
    required this.slug,
    required this.name,
    this.customName,
    this.romCount = 0,
    this.logoUrl,
  });

  final int id;
  final String slug;
  final String name;
  final String? customName;
  final int romCount;
  final String? logoUrl;

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

  RommPlatform copyWith({String? customName, String? logoUrl}) {
    return RommPlatform(
      id: id,
      slug: slug,
      name: name,
      customName: customName ?? this.customName,
      romCount: romCount,
      logoUrl: logoUrl ?? this.logoUrl,
    );
  }
}