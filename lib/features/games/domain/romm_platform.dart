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

  String get displayName => customName ?? name;

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