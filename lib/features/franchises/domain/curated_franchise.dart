import '../../seerr/domain/seerr_models.dart';

/// Orden de presentación de los títulos de una franquicia.
enum FranchiseSortOrder {
  /// Fecha de estreno, con el orden del catálogo como desempate.
  release,

  /// Orden narrativo (`storyOrder`); los títulos sin dato quedan al final.
  story,
}

/// Catálogo curado de franquicias (`assets/data/franchises.json`).
///
/// El orden de [CuratedFranchise.items] es el orden de la saga: es la fuente de
/// verdad frente a los BoxSets de Jellyfin, que no garantizan el orden TMDB.
class CuratedFranchiseCatalog {
  const CuratedFranchiseCatalog({
    required this.version,
    required this.franchises,
  });

  final int version;
  final List<CuratedFranchise> franchises;

  CuratedFranchise? byId(String id) {
    for (final franchise in franchises) {
      if (franchise.id == id) return franchise;
    }
    return null;
  }

  factory CuratedFranchiseCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['franchises'];
    final franchises = <CuratedFranchise>[];
    if (raw is List) {
      for (final value in raw) {
        if (value is! Map) continue;
        final franchise = CuratedFranchise.fromJson(
          value.cast<String, dynamic>(),
        );
        if (franchise != null) franchises.add(franchise);
      }
    }
    return CuratedFranchiseCatalog(
      version: (json['version'] as num?)?.toInt() ?? 1,
      franchises: franchises,
    );
  }
}

/// Una franquicia del catálogo.
class CuratedFranchise {
  const CuratedFranchise({
    required this.id,
    required this.name,
    required this.items,
    this.nameEn,
    this.collectionId,
    this.posterPath,
    this.backdropPath,
    this.posterAsset,
    this.logo,
  });

  final String id;
  final String name;
  final String? nameEn;

  /// Id de colección TMDB (opcional): permite resolver metadatos de los
  /// faltantes de una sola consulta en el futuro.
  final int? collectionId;

  /// Rutas TMDB (`/abc.jpg`) para carátula de la franquicia. Si faltan, el hub
  /// usa la primera película que tengas en Jellyfin.
  final String? posterPath;
  final String? backdropPath;

  /// Imagen local del bundle (`assets/...`) para la tarjeta de la franquicia.
  /// Tiene prioridad sobre TMDB/Jellyfin/Seerr; el usuario crea sus imágenes.
  final String? posterAsset;

  /// Logo de la franquicia (asset local o URL) para superponer en la tarjeta.
  final String? logo;

  /// Elementos en el orden curado de la saga.
  final List<CuratedFranchiseItem> items;

  String nameFor(String languageCode) =>
      languageCode == 'en' ? (nameEn ?? name) : name;

  String? posterUrl({String size = 'w500'}) => _tmdbImage(posterPath, size);

  String? backdropUrl({String size = 'w1280'}) =>
      _tmdbImage(backdropPath, size);

  static String? _tmdbImage(String? path, String size) {
    final value = path?.trim() ?? '';
    if (value.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/$size$value';
  }

  static CuratedFranchise? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    if (id.isEmpty) return null;
    final items = <CuratedFranchiseItem>[];
    final rawItems = json['items'];
    if (rawItems is List) {
      for (final value in rawItems) {
        if (value is! Map) continue;
        final item = CuratedFranchiseItem.fromJson(
          value.cast<String, dynamic>(),
        );
        if (item != null) items.add(item);
      }
    }
    final name = (json['name'] as String?)?.trim() ?? '';
    return CuratedFranchise(
      id: id,
      name: name.isEmpty ? id : name,
      nameEn: (json['nameEn'] as String?)?.trim(),
      collectionId: (json['collectionId'] as num?)?.toInt(),
      posterPath: (json['posterPath'] as String?)?.trim(),
      backdropPath: (json['backdropPath'] as String?)?.trim(),
      posterAsset: (json['posterAsset'] as String?)?.trim(),
      logo: (json['logo'] as String?)?.trim(),
      items: items,
    );
  }
}

/// Película o serie de una franquicia, con su id TMDB.
class CuratedFranchiseItem {
  const CuratedFranchiseItem({
    required this.type,
    required this.tmdbId,
    this.title,
    this.titleEn,
    this.year,
    this.storyOrder,
  });

  final SeerrMediaType type;
  final int tmdbId;
  final String? title;
  final String? titleEn;
  final int? year;

  /// Posición narrativa dentro de la franquicia (1 = primera en la historia).
  /// Sirve para el orden cronológico; si falta, el título queda al final.
  final int? storyOrder;

  /// Clave de ordenación para [order]; [catalogIndex] desempata y coloca al
  /// final los títulos sin `storyOrder` en el orden narrativo.
  int sortKey(FranchiseSortOrder order, {required int catalogIndex}) {
    if (order == FranchiseSortOrder.story) {
      return storyOrder ?? 100000 + catalogIndex;
    }
    return year ?? 0;
  }

  String titleFor(String languageCode) {
    final localized = languageCode == 'en' ? titleEn : null;
    final value = (localized ?? title)?.trim() ?? '';
    return value.isEmpty ? 'TMDB $tmdbId' : value;
  }

  static CuratedFranchiseItem? fromJson(Map<String, dynamic> json) {
    final tmdbId = (json['tmdbId'] as num?)?.toInt();
    if (tmdbId == null || tmdbId <= 0) return null;
    return CuratedFranchiseItem(
      type: SeerrMediaType.fromString(json['type'] as String?) ??
          SeerrMediaType.movie,
      tmdbId: tmdbId,
      title: (json['title'] as String?)?.trim(),
      titleEn: (json['titleEn'] as String?)?.trim(),
      year: (json['year'] as num?)?.toInt(),
      storyOrder: (json['storyOrder'] as num?)?.toInt(),
    );
  }
}
