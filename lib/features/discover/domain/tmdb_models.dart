// Modelos mínimos de TMDB usados por Novedades / detalle / "Dónde ver".

/// Tipo de medio TMDB.
enum TmdbMediaType {
  movie('movie'),
  tv('tv');

  const TmdbMediaType(this.value);

  final String value;

  static TmdbMediaType? fromString(String? raw) {
    switch (raw) {
      case 'movie':
        return TmdbMediaType.movie;
      case 'tv':
        return TmdbMediaType.tv;
      default:
        return null;
    }
  }
}

/// Elemento de listado (Novedades): póster + título + año.
class TmdbTitle {
  const TmdbTitle({
    required this.id,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.date,
  });

  final int id;
  final TmdbMediaType mediaType;
  final String title;
  final String? posterPath;

  /// Fecha de estreno (movie) o primera emisión (tv), en formato `yyyy-MM-dd`.
  final String? date;

  int? get year {
    final value = date;
    if (value == null || value.length < 4) return null;
    return int.tryParse(value.substring(0, 4));
  }

  factory TmdbTitle.fromJson(Map<String, dynamic> json, {TmdbMediaType? fallbackType}) {
    final mediaType =
        TmdbMediaType.fromString(json['media_type'] as String?) ?? fallbackType;
    return TmdbTitle(
      id: (json['id'] as num).toInt(),
      mediaType: mediaType ?? TmdbMediaType.movie,
      title: (json['title'] ?? json['name'] ?? '') as String,
      posterPath: json['poster_path'] as String?,
      date: (json['release_date'] ?? json['first_air_date']) as String?,
    );
  }
}

/// Ficha completa de una película/serie.
class TmdbDetail {
  const TmdbDetail({
    required this.id,
    required this.mediaType,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.date,
    this.voteAverage,
    this.genres = const [],
  });

  final int id;
  final TmdbMediaType mediaType;
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? date;
  final double? voteAverage;
  final List<String> genres;

  int? get year {
    final value = date;
    if (value == null || value.length < 4) return null;
    return int.tryParse(value.substring(0, 4));
  }

  factory TmdbDetail.fromJson(
    Map<String, dynamic> json, {
    required TmdbMediaType mediaType,
  }) {
    final rawGenres = json['genres'];
    final genres = rawGenres is List
        ? rawGenres
              .whereType<Map>()
              .map((g) => (g['name'] ?? '').toString())
              .where((g) => g.isNotEmpty)
              .toList()
        : const <String>[];
    return TmdbDetail(
      id: (json['id'] as num).toInt(),
      mediaType: mediaType,
      title: (json['title'] ?? json['name'] ?? '') as String,
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      date: (json['release_date'] ?? json['first_air_date']) as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      genres: genres,
    );
  }
}

/// Proveedor de streaming/alquiler/compra.
class TmdbProvider {
  const TmdbProvider({
    required this.name,
    required this.type,
    this.logoPath,
    this.link,
  });

  final String name;

  /// flatrate | rent | buy | free | ads
  final String type;
  final String? logoPath;
  final String? link;
}

/// Disponibilidad de un título en una región.
class TmdbWatchAvailability {
  const TmdbWatchAvailability({this.link, this.providers = const []});

  /// Enlace "ver en TMDB"/JustWatch para esa región.
  final String? link;
  final List<TmdbProvider> providers;

  bool get isEmpty => providers.isEmpty;
}
