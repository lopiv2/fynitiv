// Modelos mínimos de la API de Seerr (/api/v1).

enum SeerrMediaType {
  movie('movie'),
  tv('tv');

  const SeerrMediaType(this.value);

  final String value;

  static SeerrMediaType? fromString(String? raw) {
    switch (raw) {
      case 'movie':
        return SeerrMediaType.movie;
      case 'tv':
        return SeerrMediaType.tv;
      default:
        return null;
    }
  }
}

/// Estado de disponibilidad de Seerr (`MediaInfo.status`).
enum SeerrMediaStatus {
  unknown(1),
  pending(2),
  processing(3),
  partiallyAvailable(4),
  available(5),
  deleted(6);

  const SeerrMediaStatus(this.value);

  final int value;

  static SeerrMediaStatus? fromValue(int? value) {
    if (value == null) return null;
    for (final s in SeerrMediaStatus.values) {
      if (s.value == value) return s;
    }
    return null;
  }
}

/// Plataforma donde se emite un título (según Seerr/TMDB, región del usuario).
class SeerrWatchProvider {
  const SeerrWatchProvider({
    required this.name,
    required this.type,
    this.logoPath,
    this.link,
  });

  final String name;

  /// `flatrate` (suscripción) o `buy` (compra).
  final String type;
  final String? logoPath;
  final String? link;

  String? logoUrl({String size = 'w92'}) {
    final path = logoPath;
    if (path == null || path.isEmpty) return null;
    return 'https://image.tmdb.org/t/p/$size$path';
  }
}

/// Persona asociada a una ficha de Seerr/TMDB.
class SeerrCredit {
  const SeerrCredit({
    required this.name,
    required this.type,
    this.role,
  });

  final String name;
  final String type;
  final String? role;
}

/// Resultado de búsqueda / descubrimiento / ficha (película o serie).
class SeerrMedia {
  const SeerrMedia({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.overview,
    this.date,
    this.voteAverage,
    this.status,
    this.requested = false,
    this.genres = const [],
    this.watchProviders = const [],
    this.credits = const [],
    this.studios = const [],
    this.officialRating,
    this.runtimeMinutes,
  });

  final int tmdbId;
  final SeerrMediaType mediaType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final String? overview;
  final String? date;
  final double? voteAverage;
  final SeerrMediaStatus? status;

  /// Ya existe una petición para este título.
  final bool requested;
  final List<String> genres;

  /// Plataformas donde se emite (solo en la ficha, región del usuario).
  final List<SeerrWatchProvider> watchProviders;
  final List<SeerrCredit> credits;
  final List<String> studios;
  final String? officialRating;
  final int? runtimeMinutes;

  int? get year {
    final value = date;
    if (value == null || value.length < 4) return null;
    return int.tryParse(value.substring(0, 4));
  }

  String? posterUrl({String size = 'w342'}) => _url(posterPath, size);

  String? backdropUrl({String size = 'w1280'}) => _url(backdropPath, size);

  static String? _url(String? path, String size) =>
      (path == null || path.isEmpty) ? null : 'https://image.tmdb.org/t/p/$size$path';

  factory SeerrMedia.fromJson(Map<String, dynamic> json) {
    final mediaInfo = json['mediaInfo'];
    final requests = (mediaInfo is Map) ? mediaInfo['requests'] : null;
    // Seerr/TMDB pueden devolver `mediaType` o `media_type`; además hay
    // resultados que no son película/serie (p. ej. `person`) que se descartan.
    final rawType =
        (json['mediaType'] ?? json['media_type']) as String?;
    final SeerrMediaType mediaType;
    if (rawType == null || rawType.isEmpty) {
      mediaType = json['title'] != null
          ? SeerrMediaType.movie
          : SeerrMediaType.tv;
    } else {
      final parsed = SeerrMediaType.fromString(rawType);
      if (parsed == null) {
        throw FormatException('Tipo de medio no soportado: $rawType');
      }
      mediaType = parsed;
    }
    return SeerrMedia(
      tmdbId: (json['id'] as num).toInt(),
      mediaType: mediaType,
      title: (json['title'] ?? json['name'] ?? '') as String,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      overview: json['overview'] as String?,
      date: (json['releaseDate'] ?? json['firstAirDate']) as String?,
      voteAverage: (json['voteAverage'] as num?)?.toDouble(),
      status: mediaInfo is Map
          ? SeerrMediaStatus.fromValue((mediaInfo['status'] as num?)?.toInt())
          : null,
      requested: (requests is List) && requests.isNotEmpty,
    );
  }

  /// Ficha completa (`/movie/{id}`, `/tv/{id}`): incluye `genres` y
  /// `watchProviders` (plataformas de la región del usuario).
  factory SeerrMedia.fromDetailJson(
    Map<String, dynamic> json,
    SeerrMediaType type, {
    String? region,
  }) {
    final genres = json['genres'];
    final names = genres is List
        ? genres
              .whereType<Map>()
              .map((g) => (g['name'] ?? '').toString())
              .where((g) => g.isNotEmpty)
              .toList()
        : const <String>[];
    return SeerrMedia(
      tmdbId: (json['id'] as num).toInt(),
      mediaType: type,
      title: (json['title'] ?? json['name'] ?? '') as String,
      posterPath: json['posterPath'] as String?,
      backdropPath: json['backdropPath'] as String?,
      overview: json['overview'] as String?,
      date: (json['releaseDate'] ?? json['firstAirDate']) as String?,
      voteAverage: (json['voteAverage'] as num?)?.toDouble(),
      status: _statusOf(json['mediaInfo']),
      requested: _requestedOf(json['mediaInfo']),
      genres: names,
      watchProviders: _parseWatchProviders(json['watchProviders'], region),
      credits: _parseCredits(json['credits']),
      studios: _parseStudios(json),
      officialRating: _parseRating(json, region),
      runtimeMinutes: _parseRuntime(json, type),
    );
  }

  static List<SeerrCredit> _parseCredits(Object? raw) {
    if (raw is! Map) return const [];
    final out = <SeerrCredit>[];
    final cast = raw['cast'];
    if (cast is List) {
      for (final value in cast) {
        if (value is! Map) continue;
        final name = (value['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        out.add(
          SeerrCredit(
            name: name,
            type: 'Actor',
            role: (value['character'] ?? '').toString().trim(),
          ),
        );
      }
    }
    final crew = raw['crew'];
    if (crew is List) {
      for (final value in crew) {
        if (value is! Map) continue;
        final name = (value['name'] ?? '').toString().trim();
        final job = (value['job'] ?? '').toString().trim();
        if (name.isEmpty || job.isEmpty) continue;
        if (job.toLowerCase() != 'director' &&
            job.toLowerCase() != 'producer' &&
            job.toLowerCase() != 'creator') {
          continue;
        }
        out.add(SeerrCredit(name: name, type: job));
      }
    }
    return out;
  }

  static List<String> _parseStudios(Map<String, dynamic> json) {
    final out = <String>[];
    void add(Object? raw) {
      if (raw is! List) return;
      for (final value in raw) {
        if (value is! Map) continue;
        final name = (value['name'] ?? '').toString().trim();
        if (name.isNotEmpty && !out.contains(name)) out.add(name);
      }
    }

    add(json['productionCompanies']);
    add(json['networks']);
    return out;
  }

  static String? _parseRating(Map<String, dynamic> json, String? region) {
    final contentRatings = json['contentRatings'];
    if (contentRatings is Map) {
      final results = contentRatings['results'];
      if (results is List) {
        for (final value in results) {
          if (value is! Map) continue;
          if ('${value['iso_3166_1']}'.toUpperCase() !=
              (region ?? '').toUpperCase()) {
            continue;
          }
          final rating = (value['rating'] ?? '').toString().trim();
          if (rating.isNotEmpty) return rating;
        }
        for (final value in results) {
          if (value is! Map) continue;
          final rating = (value['rating'] ?? '').toString().trim();
          if (rating.isNotEmpty) return rating;
        }
      }
    }

    final releases = json['releases'];
    final results = releases is Map ? releases['results'] : null;
    if (results is List) {
      Iterable<Object?> candidates = results;
      if (region != null && region.isNotEmpty) {
        candidates = results.where(
          (value) =>
              value is Map &&
              '${value['iso_3166_1']}'.toUpperCase() == region.toUpperCase(),
        );
      }
      for (final value in candidates) {
        if (value is! Map) continue;
        final dates = value['release_dates'];
        if (dates is! List) continue;
        for (final date in dates) {
          if (date is! Map) continue;
          final rating = (date['certification'] ?? '').toString().trim();
          if (rating.isNotEmpty) return rating;
        }
      }
    }
    return null;
  }

  static int? _parseRuntime(Map<String, dynamic> json, SeerrMediaType type) {
    if (type == SeerrMediaType.movie) {
      return (json['runtime'] as num?)?.toInt();
    }
    final runtimes = json['episodeRunTime'];
    if (runtimes is List) {
      for (final value in runtimes) {
        if (value is num && value > 0) return value.toInt();
      }
    }
    return null;
  }

  /// Extrae las plataformas de la región indicada (o la primera si no hay
  /// región). Seerr devuelve `flatrate` (suscripción) y `buy` (compra).
  static List<SeerrWatchProvider> _parseWatchProviders(
    Object? raw,
    String? region,
  ) {
    if (raw is! List) return const [];
    Map? entry;
    for (final e in raw) {
      if (e is! Map) continue;
      if (region == null || region.isEmpty) {
        entry = e;
        break;
      }
      if ('${e['iso_3166_1']}'.toUpperCase() == region.toUpperCase()) {
        entry = e;
        break;
      }
    }
    if (entry == null) return const [];
    final e = entry;
    final link = e['link'] as String?;
    final out = <SeerrWatchProvider>[];
    void addAll(String type) {
      final list = e[type];
      if (list is! List) return;
      for (final p in list) {
        if (p is Map) {
          final name = (p['name'] ?? '').toString();
          if (name.isEmpty) continue;
          out.add(
            SeerrWatchProvider(
              name: name,
              type: type,
              logoPath: p['logoPath'] as String?,
              link: link,
            ),
          );
        }
      }
    }

    addAll('flatrate');
    addAll('buy');
    return out;
  }

  static SeerrMediaStatus? _statusOf(Object? mediaInfo) =>
      mediaInfo is Map
      ? SeerrMediaStatus.fromValue((mediaInfo['status'] as num?)?.toInt())
      : null;

  static bool _requestedOf(Object? mediaInfo) {
    final requests = (mediaInfo is Map) ? mediaInfo['requests'] : null;
    return (requests is List) && requests.isNotEmpty;
  }
}

/// Petición de contenido.
class SeerrRequest {
  const SeerrRequest({
    required this.id,
    required this.status,
    required this.mediaType,
    required this.tmdbId,
    this.title,
    this.posterPath,
    this.mediaStatus,
  });

  final int id;

  /// 1 = pendiente, 2 = aprobada, 3 = rechazada.
  final int status;
  final SeerrMediaType mediaType;
  final int tmdbId;
  final String? title;
  final String? posterPath;
  final SeerrMediaStatus? mediaStatus;

  factory SeerrRequest.fromJson(Map<String, dynamic> json) {
    final media = (json['media'] as Map?)?.cast<String, dynamic>();
    return SeerrRequest(
      id: (json['id'] as num).toInt(),
      status: (json['status'] as num?)?.toInt() ?? 0,
      mediaType:
          SeerrMediaType.fromString(media?['mediaType'] as String?) ??
          SeerrMediaType.movie,
      tmdbId: (media?['tmdbId'] as num?)?.toInt() ?? 0,
      title: (media?['title'] ?? json['title']) as String?,
      posterPath: media?['posterPath'] as String?,
      mediaStatus: SeerrMediaStatus.fromValue(
        (media?['status'] as num?)?.toInt(),
      ),
    );
  }
}

/// Resultado del inicio de Quick Connect.
class SeerrQuickConnect {
  const SeerrQuickConnect({required this.code, required this.secret});

  final String code;
  final String secret;
}
