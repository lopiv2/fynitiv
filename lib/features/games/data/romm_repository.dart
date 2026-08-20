import 'package:dio/dio.dart';

import '../domain/romm_game.dart';
import '../domain/romm_platform.dart';

/// Respuesta paginada de ROMM para /roms.
class RommGamesPage {
  const RommGamesPage({required this.items, required this.total});

  final List<RommGame> items;
  final int total;
}

/// Cliente de la API REST de ROMM (RomM).
class RommRepository {
  RommRepository({required this.serverUrl, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = serverUrl.replaceAll(RegExp(r'/$'), '');
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  final String serverUrl;
  final Dio _dio;

  String? _token;

  String? get token => _token;

  void setToken(String? token) => _token = token;

  Options get _authOptions => Options(
    headers: {
      if (_token != null && _token!.isNotEmpty)
        'Authorization': 'Bearer $_token',
    },
  );

  /// Normaliza una ruta de asset de ROMM (relativa) a una URL absoluta.
  String assetUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return path.startsWith('http')
        ? path
        : '$serverUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  /// Autentica contra /token (grant_type=password) y guarda el access token.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final res = await _dio.post(
      '/api/token',
      data: Uri(
        queryParameters: {
          'grant_type': 'password',
          'username': username,
          'password': password,
          // No enviamos 'scope' para que RomM asigne los permisos por defecto de tu rol
        },
      ).query,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final accessToken = res.data?['access_token'];
    if (accessToken == null || accessToken.toString().isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        error: 'ROMM no devolvió un token de acceso.',
      );
    }
    _token = accessToken.toString();
  }

  /// Lista de plataformas de la biblioteca.
  Future<List<RommPlatform>> getPlatforms() async {
    final res = await _dio.get('/platforms', options: _authOptions);
    final list = res.data as List? ?? const [];
    return [
      for (final p in list)
        RommPlatform(
          id: (p['id'] as num?)?.toInt() ?? 0,
          slug: p['slug'] as String? ?? '',
          name: p['name'] as String? ?? '',
          customName: p['custom_name'] as String?,
          romCount: (p['rom_count'] as num?)?.toInt() ?? 0,
          logoUrl: assetUrl(p['url_logo'] as String?),
        ),
    ];
  }

  /// Lista paginada de juegos de una plataforma (o de toda la biblioteca).
  Future<RommGamesPage> getGames({
    List<int>? platformIds,
    String? searchTerm,
    int limit = 60,
    int offset = 0,
  }) async {
    final res = await _dio.get(
      '/roms',
      queryParameters: {
        if (platformIds != null && platformIds.isNotEmpty)
          for (final id in platformIds) 'platform_ids': id,
        if (searchTerm != null && searchTerm.isNotEmpty)
          'search_term': searchTerm,
        'limit': limit,
        'offset': offset,
        'with_files': true,
        'with_char_index': false,
        'with_filter_values': false,
        'with_rom_id_index': false,
        'with_total': true,
      },
      options: _authOptions,
    );
    final data = res.data as Map<String, dynamic>? ?? const {};
    final items = data['items'] as List? ?? const [];
    final total = (data['total'] as num?)?.toInt() ?? items.length;
    return RommGamesPage(
      items: [for (final g in items) _mapGame(g)],
      total: total,
    );
  }

  /// Detalle de un juego.
  Future<RommGame> getGame(int id) async {
    final res = await _dio.get('/roms/$id', options: _authOptions);
    return _mapGame(res.data);
  }

  RommGame _mapGame(Map<String, dynamic>? g) {
    final files = g?['files'] as List? ?? const [];
    final firstFile = files.isNotEmpty
        ? (files.first['file_name'] as String?)
        : null;
    return RommGame(
      id: (g?['id'] as num?)?.toInt() ?? 0,
      name: g?['name'] as String? ?? g?['fs_name'] as String? ?? '',
      platformId: (g?['platform_id'] as num?)?.toInt() ?? 0,
      platformSlug: g?['platform_slug'] as String? ?? '',
      platformDisplayName:
          g?['platform_display_name'] as String? ??
          g?['platform_custom_name'] as String? ??
          '',
      summary: g?['summary'] as String?,
      coverSmallUrl: assetUrl(g?['path_cover_small'] as String?),
      coverLargeUrl: assetUrl(g?['path_cover_large'] as String?),
      firstFile: firstFile,
    );
  }

  /// Config de streaming: devuelve si hay un contenedor para una plataforma.
  Future<bool> hasStreamingFor(String platformSlug) async {
    try {
      final res = await _dio.get('/streaming/config', options: _authOptions);
      final data = res.data as Map<String, dynamic>? ?? const {};
      final enabled = data['enabled'] == true;
      if (!enabled) return false;
      final containers = data['containers'] as List? ?? const [];
      return containers.any(
        (c) =>
            (c as Map<String, dynamic>?)?['platform']
                ?.toString()
                .toLowerCase() ==
            platformSlug.toLowerCase(),
      );
    } catch (_) {
      return false;
    }
  }

  /// Reclama una sesión de streaming y devuelve la URL del emulador web.
  Future<String?> claimStreamingSession(int romId) async {
    final res = await _dio.post(
      '/streaming/sessions',
      data: {'rom_id': romId},
      options: _authOptions,
    );
    final host = res.data?['host'] as String?;
    if (host == null || host.isEmpty) return null;
    return host;
  }

  /// URL para descargar un archivo de un juego (requiere el token en headers).
  String downloadUrl(int romId, String fileName) {
    final base = serverUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/roms/$romId/content/${Uri.encodeComponent(fileName)}';
  }

  /// Descarga un archivo de un juego a un destino local.
  Future<String> downloadGameFile({
    required int romId,
    required String fileName,
    required String savePath,
  }) async {
    await _dio.download(
      downloadUrl(romId, fileName),
      savePath,
      options: _authOptions,
    );
    return savePath;
  }
}
