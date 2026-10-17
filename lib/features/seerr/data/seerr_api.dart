import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/skin/layout_section.dart';
import '../domain/seerr_models.dart';

/// Tipo de error de conexión con Seerr (para traducir en la UI).
enum SeerrErrorKind {
  certificate,
  network,
  unauthorized,

  /// 403: sin permiso de petición, cuota agotada o título en la lista negra.
  forbidden,

  /// 409: ya existe una petición para ese título.
  duplicate,

  /// 202: no quedan temporadas nuevas que pedir.
  noSeasons,

  /// 403 de la protección CSRF de Seerr.
  csrf,
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
       ) {
    _seedCookies(credential);
    // Seerr rota `connect.sid` y, con la protección CSRF activa, manda el par
    // `_csrf`/`XSRF-TOKEN` en cada respuesta: hay que devolverlo en los POST.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (res, handler) {
          _absorbSetCookie(res.headers['set-cookie']);
          handler.next(res);
        },
      ),
    );
  }

  final String baseUrl;
  final String? credential; // connect.sid=...

  /// `user:pass` de la URL (basic-auth de un proxy delante de Seerr).
  final String? basicAuth;
  final String? apiKey;
  final Dio _dio;

  /// Bote de cookies del servidor (`connect.sid`, `_csrf`, `XSRF-TOKEN`…): se
  /// envían en cada petición y se actualizan con lo que devuelva Seerr.
  final Map<String, String> _cookies = {};

  /// Siembra el bote desde la credencial guardada (`connect.sid=s%3A…`).
  void _seedCookies(String? raw) {
    if (raw == null || raw.isEmpty) return;
    for (final part in raw.split(';')) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      final name = part.substring(0, eq).trim();
      final value = part.substring(eq + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) _cookies[name] = value;
    }
  }

  /// Acumula las cookies de `set-cookie` (Dio puede plegar varias en una).
  void _absorbSetCookie(List<String>? values) {
    if (values == null) return;
    for (final value in values) {
      for (final raw in value.split(RegExp(r',(?=\s*[A-Za-z0-9_-]+=)'))) {
        final pair = raw.split(';').first.trim();
        final eq = pair.indexOf('=');
        if (eq <= 0) continue;
        final name = pair.substring(0, eq).trim();
        final cookie = pair.substring(eq + 1).trim();
        if (name.isNotEmpty && cookie.isNotEmpty) _cookies[name] = cookie;
      }
    }
  }

  /// Token CSRF que exige Seerr (cabecera `X-XSRF-TOKEN`) cuando la
  /// protección CSRF está activa.
  String? get _xsrfToken {
    final raw = _cookies['XSRF-TOKEN'];
    if (raw == null || raw.isEmpty) return null;
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      // El valor ya venía decodificado.
      return raw;
    }
  }

  static bool _isSafeMethod(String method) =>
      method == 'GET' || method == 'HEAD' || method == 'OPTIONS';

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
  Map<String, dynamic> _asMap(Response<dynamic> res) {
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
    // 5xx (validados como error por `validateStatus`): es un fallo del
    // servidor, no de la conexión.
    if (e.type == DioExceptionType.badResponse) {
      final status = e.response?.statusCode;
      return SeerrException(
        e.response == null
            ? 'Server error'
            : _messageOf(e.response!),
        statusCode: status,
        kind: SeerrErrorKind.http,
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
      final res = await _dio.get<Object>('/status', options: _options('GET'));
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

  /// Cabeceras de una petición. [jsonBody] marca los cuerpos JSON: sin él,
  /// Dio serializaría el `Map` como `application/x-www-form-urlencoded` y el
  /// validador OpenAPI de Seerr rechazaría el POST (su API es JSON).
  Options _options(String method, {bool jsonBody = false}) {
    final headers = <String, String>{'Accept': 'application/json'};
    // Basic-auth del proxy (si la URL traía user:pass).
    if (basicAuth != null && basicAuth!.isNotEmpty) {
      headers['Authorization'] =
          'Basic ${base64Encode(utf8.encode(basicAuth!))}';
    }
    if (apiKey != null && apiKey!.isNotEmpty) headers['X-Api-Key'] = apiKey!;
    if (_cookies.isNotEmpty) {
      headers['Cookie'] = _cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    } else if (credential != null && credential!.trim().isNotEmpty) {
      // Credencial sin formato de cookie (`name=value`): se envía tal cual.
      headers['Cookie'] = credential!.trim();
    }
    // Protección CSRF de Seerr: token obligatorio en métodos no seguros.
    final token = _xsrfToken;
    if (token != null && !_isSafeMethod(method)) {
      headers['X-XSRF-TOKEN'] = token;
    }
    return Options(
      headers: headers,
      contentType: jsonBody ? Headers.jsonContentType : null,
    );
  }

  Future<bool> checkStatus() async {
    try {
      final res = await _dio.get<Object>('/status', options: _options('GET'));
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
        options: _options('POST'),
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
        options: _options('GET'),
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
        options: _options('POST', jsonBody: true),
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
      options: _options('GET'),
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
    final res = await _dio.get<Object>(path, options: _options('GET'));
    if (res.statusCode != 200) return const [];
    return _mediaList(res.data);
  }

  Future<List<SeerrMedia>> search(String query, {int page = 1}) async {
    final res = await _dio.get<Object>(
      '/search',
      queryParameters: {'query': query, 'page': page},
      options: _options('GET'),
    );
    return _mediaList(res.data);
  }

  /// Crea una petición en Seerr. Lanza [SeerrException] con el motivo real que
  /// devuelve el servidor (permiso, cuota, duplicada, CSRF…) para poder
  /// mostrarlo, en lugar de devolver un booleano sin contexto.
  Future<void> createRequest({
    required SeerrMediaType type,
    required int mediaId,
    List<int>? seasons,
  }) async {
    // Con la protección CSRF activa, el token llega en la primera respuesta
    // (`XSRF-TOKEN`). Si el POST es lo primero que hace este cliente, se pide
    // antes un /status para obtenerlo.
    if (_xsrfToken == null) {
      try {
        await _dio.get<Object>('/status', options: _options('GET'));
      } catch (_) {}
    }
    Response<Object> res;
    try {
      res = await _dio.post<Object>(
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
        options: _options('POST', jsonBody: true),
      );
    } on DioException catch (e) {
      throw _classify(e);
    }
    final code = res.statusCode ?? 0;
    if (code == 200 || code == 201) return;
    throw SeerrException(
      _messageOf(res),
      statusCode: code,
      kind: _requestErrorKind(code, res),
    );
  }

  /// Traduce el estado de un `POST /request` a un tipo de error concreto.
  SeerrErrorKind _requestErrorKind(int code, Response<Object> res) {
    switch (code) {
      case 202:
        // Seerr: `NoSeasonsAvailableError` (ya están pedidas o disponibles).
        return SeerrErrorKind.noSeasons;
      case 401:
        return SeerrErrorKind.unauthorized;
      case 403:
        return _messageOf(res).toLowerCase().contains('csrf')
            ? SeerrErrorKind.csrf
            : SeerrErrorKind.forbidden;
      case 409:
        return SeerrErrorKind.duplicate;
      default:
        return SeerrErrorKind.http;
    }
  }

  /// Mensaje de error de Seerr (`{ message, errors }`) con respaldo legible.
  String _messageOf(Response<dynamic> res) {
    try {
      final map = _asMap(res);
      final message = map['message'] ?? map['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    } catch (_) {}
    return 'Seerr HTTP ${res.statusCode}';
  }

  Future<List<SeerrRequest>> requests({int take = 20}) async {
    final res = await _dio.get<Object>(
      '/request',
      queryParameters: {'take': take, 'sort': 'added'},
      options: _options('GET'),
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
