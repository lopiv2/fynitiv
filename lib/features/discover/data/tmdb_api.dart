import 'package:dio/dio.dart';

import '../domain/tmdb_models.dart';

/// Cliente mínimo de TMDB (v3 api_key o v4 Bearer token, BYO-key).
class TmdbApi {
  TmdbApi(this.key)
    : _dio = Dio(
        BaseOptions(
          baseUrl: 'https://api.themoviedb.org/3',
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );

  final String key;
  final Dio _dio;

  /// Los tokens v4 empiezan por `eyJ` (JWT) y se envían como Bearer.
  bool get _isV4Token => key.startsWith('eyJ');

  Options get _options =>
      _isV4Token ? Options(headers: {'Authorization': 'Bearer $key'}) : Options();

  Map<String, dynamic> _q(Map<String, dynamic> params) =>
      _isV4Token ? params : {...params, 'api_key': key};

  Future<List<TmdbTitle>> trending({required String language}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/trending/all/week',
      queryParameters: _q({'language': language}),
      options: _options,
    );
    return _titles(res.data?['results'], null);
  }

  Future<List<TmdbTitle>> upcoming({
    required String language,
    required String region,
  }) async {
    final movie = await _dio.get<Map<String, dynamic>>(
      '/movie/upcoming',
      queryParameters: _q({'language': language, 'region': region}),
      options: _options,
    );
    final tv = await _dio.get<Map<String, dynamic>>(
      '/tv/on_the_air',
      queryParameters: _q({'language': language}),
      options: _options,
    );
    final out = <TmdbTitle>[
      ..._titles(movie.data?['results'], TmdbMediaType.movie),
      ..._titles(tv.data?['results'], TmdbMediaType.tv),
    ];
    return out;
  }

  Future<TmdbDetail> detail({
    required TmdbMediaType mediaType,
    required int id,
    required String language,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/${mediaType.value}/$id',
      queryParameters: _q({'language': language}),
      options: _options,
    );
    return TmdbDetail.fromJson(res.data ?? const {}, mediaType: mediaType);
  }

  Future<TmdbWatchAvailability> watchProviders({
    required TmdbMediaType mediaType,
    required int id,
    required String region,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/${mediaType.value}/$id/watch/providers',
      options: _options,
    );
    final results = res.data?['results'];
    final entry = (results is Map) ? results[region] : null;
    if (entry is! Map) return const TmdbWatchAvailability();
    final link = entry['link'] as String?;
    final providers = <TmdbProvider>[];
    void addAll(String type) {
      final list = entry[type];
      if (list is! List) return;
      for (final p in list) {
        if (p is Map) {
          providers.add(
            TmdbProvider(
              name: (p['provider_name'] ?? '').toString(),
              type: type,
              logoPath: p['logo_path'] as String?,
              link: link,
            ),
          );
        }
      }
    }

    for (final type in const ['flatrate', 'free', 'ads', 'rent', 'buy']) {
      addAll(type);
    }
    return TmdbWatchAvailability(link: link, providers: providers);
  }

  List<TmdbTitle> _titles(Object? raw, TmdbMediaType? fallback) {
    if (raw is! List) return const [];
    final out = <TmdbTitle>[];
    for (final e in raw) {
      if (e is Map) {
        final title = TmdbTitle.fromJson(
          e.cast<String, dynamic>(),
          fallbackType: fallback,
        );
        if (title.title.isNotEmpty) out.add(title);
      }
    }
    return out;
  }
}

/// URLs del CDN de imágenes de TMDB (no requieren key).
abstract final class TmdbImages {
  static String? poster(String? path, {String size = 'w342'}) =>
      _url(path, size);

  static String? backdrop(String? path, {String size = 'w1280'}) =>
      _url(path, size);

  static String? logo(String? path, {String size = 'w92'}) => _url(path, size);

  static String? _url(String? path, String size) =>
      (path == null || path.isEmpty) ? null : 'https://image.tmdb.org/t/p/$size$path';
}
