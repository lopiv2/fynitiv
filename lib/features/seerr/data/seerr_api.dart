import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/skin/layout_section.dart';
import '../domain/seerr_models.dart';

/// Tipo de error de conexión con Seerr (para traducir en la UI).
enum SeerrErrorKind {
  certificate,
  network,
  unauthorized,
  notFound,
  http,
  response,
  unknown,
}

/// Error de la API de Seerr con mensaje legible.
class SeerrException implements Exception {
  const SeerrException(
    this.message, {
    this.statusCode,
    this.kind = SeerrErrorKind.unknown,
  });

  final String message;
  final int? statusCode;
  final SeerrErrorKind kind;

  @override
  String toString() => message;
}

/// Cliente mínimo de la API de Seerr (`/api/v1`).
///
/// Autenticación: cookie de sesión (`connect.sid=...`, del Quick Connect o
/// login) o `X-Api-Key`.
class SeerrApi {
  factory SeerrApi({
    required String baseUrl,
    String? credential,
    String? apiKey,
  }) {
    final (clean, userInfo) = _splitUserInfo(baseUrl);
    return SeerrApi._(
      baseUrl: clean,
      basicAuth: userInfo,
      credential: credential,
      apiKey: apiKey,
    );
  }

  SeerrApi._({
    required String baseUrl,
    this.basicAuth,
    this.credential,
    this.apiKey,
  }) : baseUrl = _normalize(baseUrl),
       _dio = Dio(
         BaseOptions(
           baseUrl: '${_normalize(baseUrl)}/api/v1',
           connectTimeout: const Duration(seconds: 12),
           receiveTimeout: const Duration(seconds: 12),
           validateStatus: (s) => s != null && s < 500,
         ),
       );

  final String baseUrl;
  final String? credential; // connect.sid=...

  /// `user:pass` de la URL (basic-auth de un proxy delante de Seerr).
  final String? basicAuth;
  final String? apiKey;
  final Dio _dio;

  /// Separa el `user:pass` de la URL (basic-auth de proxy); devuelve
  /// (urlSinCredenciales, userInfo|null).
  static (String, String?) _splitUserInfo(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.userInfo.isEmpty) return (url, null);
    return (uri.replace(userInfo: '').toString(), uri.userInfo);
  }

  static String _normalize(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    // Tolerar que el usuario pegue la URL con el sufijo de la API.
    if (u.endsWith('/api/v1')) {
      u = u.substring(0, u.length - '/api/v1'.length);
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Interpreta la respuesta como JSON (Map), tolerando servidores que no
  /// fijan `application/json` (Dio devuelve String) y lanzando un error legible.
  Map<String, dynamic> _asMap(Response<Object> res) {
    final data = res.data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {}
    }
    var snippet = data?.toString() ?? '';
    if (snippet.length > 180) snippet = snippet.substring(0, 180);
    throw SeerrException(
      'Seerr ${res.statusCode}: ${snippet.isEmpty ? 'respuesta no válida' : snippet}',
      statusCode: res.statusCode,
      kind: SeerrErrorKind.response,
    );
  }

  SeerrErrorKind _httpKind(int? status) {
    if (status == 401 || status == 403) return SeerrErrorKind.unauthorized;
    if (status == 404) return SeerrErrorKind.notFound;
    return SeerrErrorKind.http;
  }

  /// Clasifica un [DioException] (certificado, red/DNS u otro).
  SeerrException _classify(DioException e) {
    final raw = '${e.error} ${e.message}'.toLowerCase();
    if (raw.contains('certificate') || raw.contains('handshake')) {
      return const SeerrException(
        'TLS certificate error',
        kind: SeerrErrorKind.certificate,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        raw.contains('socketexception') ||
        raw.contains('failed host lookup')) {
      return const SeerrException(
        'Network/DNS error',
        kind: SeerrErrorKind.network,
      );
    }
    return SeerrException(
      'Connection error: ${e.message ?? e.type.name}',
      kind: SeerrErrorKind.network,
    );
  }

  /// Comprueba la conectividad con Seerr (`/status`), lanzando un error legible.
  Future<void> assertReachable() async {
    try {
      final res = await _dio.get<Object>('/status', options: _options);
      if (res.statusCode != 200) {
        throw SeerrException(
          'Seerr responded HTTP ${res.statusCode} on /status',
          statusCode: res.statusCode,
          kind: SeerrErrorKind.http,
        );
      }
    } on DioException catch (e) {
      throw _classify(e);
    }
  }

  Options get _options {
    final headers = <String, String>{'Accept': 'application/json'};
    // Basic-auth del proxy (si la URL traía user:pass).
    if (basicAuth != null && basicAuth!.isNotEmpty) {
      headers['Authorization'] =
          'Basic ${base64Encode(utf8.encode(basicAuth!))}';
    }
    if (apiKey != null && apiKey!.isNotEmpty) headers['X-Api-Key'] = apiKey!;
    if (credential != null && credential!.isNotEmpty) {
      headers['Cookie'] = credential!;
    }
    return Options(headers: headers);
  }

  Future<bool> checkStatus() async {
    try {
      final res = await _dio.get<Object>('/status', options: _options);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<SeerrQuickConnect> initiateQuickConnect() async {
    Response<Object> res;
    try {
      res = await _dio.post<Object>(
        '/auth/jellyfin/quickconnect/initiate',
        options: _options,
      );
    } on DioException catch (e) {
      throw _classify(e);
    }
    if (res.statusCode != 200) {
      throw SeerrException(
        'Quick Connect HTTP ${res.statusCode}',
        statusCode: res.statusCode,
        kind: _httpKind(res.statusCode),
      );
    }
    final data = _asMap(res);
    final code = '${data['code'] ?? ''}';
    final secret = '${data['secret'] ?? ''}';
    if (code.isEmpty || secret.isEmpty) {
      throw const SeerrException(
        'La respuesta de Quick Connect no incluía código/secret.',
      );
    }
    return SeerrQuickConnect(code: code, secret: secret);
  }

  Future<bool> checkQuickConnect(String secret) async {
    try {
      final res = await _dio.get<Object>(
        '/auth/jellyfin/quickconnect/check',
        queryParameters: {'secret': secret},
        options: _options,
      );
      if (res.statusCode != 200) return false;
      final data = res.data;
      return data is Map && data['authenticated'] == true;
    } on DioException catch (e) {
      throw _classify(e);
    }
  }

  /// Devuelve la cookie de sesión si el login por Quick Connect tuvo éxito.
  Future<String?> authenticateQuickConnect(String secret) async {
    try {
      final res = await _dio.post<Object>(
        '/auth/jellyfin/quickconnect/authenticate',
        data: {'secret': secret},
        options: _options,
      );
      if (res.statusCode != 200) return null;
      return _sessionCookie(res);
    } on DioException catch (e) {
      throw _classify(e);
    }
  }

  Future<SeerrMedia> detail(
    SeerrMediaType type,
    int tmdbId, {
    String? region,
  }) async {
    final res = await _dio.get<Object>(
      '/${type.value}/$tmdbId',
      options: _options,
    );
    return SeerrMedia.fromDetailJson(
      (res.data as Map).cast<String, dynamic>(),
      type,
      region: region,
    );
  }

  /// Lista de descubrimiento de Seerr según la categoría.
  Future<List<SeerrMedia>> discover(SeerrDiscoverCategory category) async {
    final path = switch (category) {
      SeerrDiscoverCategory.trending => '/discover/trending',
      SeerrDiscoverCategory.popularMovies => '/discover/movies',
      SeerrDiscoverCategory.upcomingMovies => '/discover/movies/upcoming',
      SeerrDiscoverCategory.popularTv => '/discover/tv',
      SeerrDiscoverCategory.upcomingTv => '/discover/tv/upcoming',
    };
    final res = await _dio.get<Object>(path, options: _options);
    if (res.statusCode != 200) return const [];
    return _mediaList(res.data);
  }

  Future<List<SeerrMedia>> search(String query, {int page = 1}) async {
    final res = await _dio.get<Object>(
      '/search',
      queryParameters: {'query': query, 'page': page},
      options: _options,
    );
    return _mediaList(res.data);
  }

  Future<bool> createRequest({
    required SeerrMediaType type,
    required int mediaId,
    List<int>? seasons,
  }) async {
    final res = await _dio.post<Object>(
      '/request',
      data: {
        'mediaType': type.value,
        'mediaId': mediaId,
        // En series Seerr exige `seasons`; sin selección pedimos todas.
        if (type == SeerrMediaType.tv)
          'seasons': (seasons != null && seasons.isNotEmpty) ? seasons : 'all'
        else if (seasons != null && seasons.isNotEmpty)
          'seasons': seasons,
      },
      options: _options,
    );
    final code = res.statusCode ?? 0;
    return code >= 200 && code < 300;
  }

  Future<List<SeerrRequest>> requests({int take = 20}) async {
    final res = await _dio.get<Object>(
      '/request',
      queryParameters: {'take': take, 'sort': 'added'},
      options: _options,
    );
    if (res.statusCode != 200) return const [];
    final data = res.data;
    final results = (data is Map) ? data['results'] : null;
    if (results is! List) return const [];
    final out = <SeerrRequest>[];
    for (final e in results) {
      if (e is Map) {
        try {
          out.add(SeerrRequest.fromJson(e.cast<String, dynamic>()));
        } catch (_) {}
      }
    }
    return out;
  }

  List<SeerrMedia> _mediaList(Object? data) {
    final results = (data is Map) ? data['results'] : null;
    if (results is! List) return const [];
    final out = <SeerrMedia>[];
    for (final e in results) {
      if (e is! Map) continue;
      try {
        final m = SeerrMedia.fromJson(e.cast<String, dynamic>());
        if (m.mediaType == SeerrMediaType.movie ||
            m.mediaType == SeerrMediaType.tv) {
          out.add(m);
        }
      } catch (_) {}
    }
    return out;
  }

  String? _sessionCookie(Response<Object> res) {
    final list = res.headers['set-cookie'];
    if (list == null) return null;
    for (final raw in list) {
      for (final part in raw.split(',')) {
        final t = part.trim();
        if (t.startsWith('connect.sid=')) return t.split(';').first;
      }
    }
    return null;
  }
}
