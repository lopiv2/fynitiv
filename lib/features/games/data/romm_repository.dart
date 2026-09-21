// ignore_for_file: use_null_aware_elements
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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

  /// Resuelve el logo de plataforma a URL absoluta o null si no hay logo.
  String? _logoUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final url = assetUrl(trimmed);
    return url.isEmpty ? null : url;
  }

  String _scopesFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 'unknown';
      var p = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (p.length % 4 != 0) {
        p += '=';
      }
      final jsonStr = utf8.decode(base64.decode(p));
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final scopes = map['scopes'] ?? map['scope'] ?? '';
      return scopes.toString();
    } catch (e) {
      return 'decode err $e';
    }
  }

  /// Autentica contra /api/token (grant_type=password) y guarda el access token.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    Response? res;
    DioException? lastErr;
    for (final scope in ['user', null]) {
      try {
        final qp = <String, String>{
          'grant_type': 'password',
          'username': username,
          'password': password,
          'scope': ?scope,
        };
        res = await _dio.post(
          '/api/token',
          data: Uri(queryParameters: qp).query,
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        break;
      } on DioException catch (e) {
        lastErr = e;
        if (scope == null) rethrow;
      }
    }
    final accessToken = res?.data?['access_token'];
    if (accessToken == null || accessToken.toString().isEmpty) {
      throw lastErr ??
          DioException(
            requestOptions: res?.requestOptions ?? RequestOptions(path: '/api/token'),
            error: 'ROMM no devolvió un token de acceso. Respuesta: ${res?.data}',
          );
    }
    _token = accessToken.toString();
    final scopes = _scopesFromToken(_token!);
    if (scopes.isEmpty) {
      // Token con scopes vacío puede causar 403 en /api/platforms - se loguea solo en debug si se necesita
    }
  }

  /// Lista de plataformas de la biblioteca.
  Future<List<RommPlatform>> getPlatforms() async {
    try {
      final res = await _dio.get('/api/platforms', options: _authOptions);
      final raw = res.data;
      List list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map<String, dynamic> && raw['items'] is List) {
        list = raw['items'] as List;
      } else if (raw is Map<String, dynamic> && raw['platforms'] is List) {
        list = raw['platforms'] as List;
      } else {
        list = const [];
      }
      String strVal(dynamic v) => v?.toString().trim() ?? '';
      String pickName(Map p) {
        final n = strVal(p['name']);
        if (n.isNotEmpty) return n;
        final fs = strVal(p['fs_name']);
        if (fs.isNotEmpty) return fs;
        final cn = strVal(p['custom_name']);
        if (cn.isNotEmpty) return cn;
        return strVal(p['slug']).isNotEmpty ? strVal(p['slug']) : strVal(p['fs_slug']);
      }

      String pickSlug(Map p) {
        final s = strVal(p['slug']);
        if (s.isNotEmpty) return s;
        return strVal(p['fs_slug']);
      }

      String? pickOptString(Map p, List<String> keys) {
        for (final k in keys) {
          final v = p[k];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
        return null;
      }

      int pickSize(Map p) {
        final v = p['fs_size_bytes'];
        if (v is num) return v.toInt();
        return 0;
      }

      int? pickGeneration(Map p) {
        final v = p['generation'];
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v.trim());
        return null;
      }

      int pickFirmwareCount(Map p) {
        final c = p['firmware_count'];
        if (c is num) return c.toInt();
        final f = p['firmware'];
        if (f is List) return f.length;
        return 0;
      }

      final mapped = [
        for (final p in list)
          if (p is Map<String, dynamic>)
            RommPlatform(
              id: (p['id'] as num?)?.toInt() ?? 0,
              slug: pickSlug(p),
              name: pickName(p),
              customName: () {
                final c = p['custom_name'] as String?;
                return c != null && c.trim().isNotEmpty ? c.trim() : null;
              }(),
              romCount: ((p['rom_count'] ?? p['roms_count'] ?? p['count']) as num?)?.toInt() ?? 0,
              logoUrl: _logoUrl(
                // Prioridad: logo_path interno de ROMM > url_logo externo IGDB
                (p['logo_path'] ?? p['path_logo'] ?? p['url_logo'] ?? p['img_path'] ?? p['logo']) as String?,
              ),
              category: pickOptString(p, const ['category']),
              generation: pickGeneration(p),
              familyName: pickOptString(p, const ['family_name']),
              familySlug: pickOptString(p, const ['family_slug']),
              fsSizeBytes: pickSize(p),
              firmwareCount: pickFirmwareCount(p),
            )
          else if (p is Map)
            RommPlatform(
              id: (p['id'] as num?)?.toInt() ?? 0,
              slug: pickSlug(p),
              name: pickName(p),
              customName: () {
                final c = p['custom_name']?.toString();
                return c != null && c.trim().isNotEmpty ? c.trim() : null;
              }(),
              romCount: (p['rom_count'] ?? p['roms_count'] ?? p['count']) is num ? ((p['rom_count'] ?? p['roms_count'] ?? p['count']) as num).toInt() : 0,
              logoUrl: _logoUrl((p['logo_path'] ?? p['path_logo'] ?? p['url_logo'])?.toString()),
              category: pickOptString(p, const ['category']),
              generation: pickGeneration(p),
              familyName: pickOptString(p, const ['family_name']),
              familySlug: pickOptString(p, const ['family_slug']),
              fsSizeBytes: pickSize(p),
              firmwareCount: pickFirmwareCount(p),
            ),
      ];
      final filtered = mapped.where((p) => p.romCount > 0).toList();
      // DEBUG: plataformas recibidas de ROMM (para identificar las no mapeadas)
      debugPrint('[ROMM] GET /api/platforms -> raw=${list.length} mapped=${mapped.length} filtered(romCount>0)=${filtered.length} server=$serverUrl');
      for (final p in filtered) {
        debugPrint('[ROMM] platform id=${p.id} slug="${p.slug}" name="${p.name}" customName="${p.customName}" romCount=${p.romCount} logoUrl="${p.logoUrl}" category="${p.category}" generation=${p.generation} family="${p.familyName}" size=${p.fsSizeBytes} firmware=${p.firmwareCount}');
      }
      // También loguea las descartadas por romCount 0 (útil para ver si faltan identificadas)
      final zero = mapped.where((p) => p.romCount == 0).toList();
      if (zero.isNotEmpty) {
        debugPrint('[ROMM] zero-count platforms (${zero.length}):');
        for (final p in zero) {
          debugPrint('[ROMM]   zero id=${p.id} slug="${p.slug}" name="${p.name}" customName="${p.customName}"');
        }
      }
      // Log crudo de claves para detectar campos nuevos (slug/fs_slug, name/fs_name, logo_path/url_logo)
      if (list.isNotEmpty && list.first is Map) {
        final sample = list.first as Map;
        debugPrint('[ROMM] sample raw keys: ${sample.keys.toList()} values: id=${sample['id']} slug=${sample['slug']}/${sample['fs_slug']} name=${sample['name']}/${sample['fs_name']} logo_path=${sample['logo_path']} url_logo=${sample['url_logo']} custom_name=${sample['custom_name']} category=${sample['category']} generation=${sample['generation']} family=${sample['family_name']} size=${sample['fs_size_bytes']} firmware=${sample['firmware_count'] ?? (sample['firmware'] is List ? (sample['firmware'] as List).length : null)}');
      }
      return filtered;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403) {
        try {
          final noAuthDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl, connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 8)));
          final noAuthRes = await noAuthDio.get('/api/platforms');
          if (noAuthRes.statusCode == 200 && noAuthRes.data is List) {
            final list = noAuthRes.data as List;
            final res = [
              for (final p in list)
                if (p is Map<String, dynamic>)
                  RommPlatform(
                    id: (p['id'] as num?)?.toInt() ?? 0,
                    slug: (p['slug'] ?? p['fs_slug']) as String? ?? '',
                    name: (p['name'] ?? p['fs_name']) as String? ?? '',
                    customName: p['custom_name'] as String?,
                    romCount: ((p['rom_count'] ?? p['roms_count'] ?? p['count']) as num?)?.toInt() ?? 0,
                    logoUrl: _logoUrl((p['logo_path'] ?? p['url_logo']) as String?),
                    category: (p['category'] as String?)?.trim().isNotEmpty == true ? (p['category'] as String).trim() : null,
                    generation: (p['generation'] as num?)?.toInt(),
                    familyName: (p['family_name'] as String?)?.trim().isNotEmpty == true ? (p['family_name'] as String).trim() : null,
                    familySlug: (p['family_slug'] as String?)?.trim().isNotEmpty == true ? (p['family_slug'] as String).trim() : null,
                    fsSizeBytes: (p['fs_size_bytes'] as num?)?.toInt() ?? 0,
                    firmwareCount: (p['firmware_count'] as num?)?.toInt() ?? (p['firmware'] is List ? (p['firmware'] as List).length : 0),
                  ),
            ];
            debugPrint('[ROMM] fallback noAuth platforms count=${res.length}');
            for (final p in res) {
              debugPrint('[ROMM][fallback-noAuth] id=${p.id} slug="${p.slug}" name="${p.name}"');
            }
            return res;
          }
        } catch (_) {}
      }
      if (code == 500) {
        try {
          final fallback = await _dio.get('/platforms', options: _authOptions);
          if (fallback.statusCode == 200 && fallback.data is List) {
            final list = fallback.data as List;
            final res = [
              for (final p in list)
                if (p is Map<String, dynamic>)
                  RommPlatform(
                    id: (p['id'] as num?)?.toInt() ?? 0,
                    slug: (p['slug'] ?? p['fs_slug']) as String? ?? '',
                    name: (p['name'] ?? p['fs_name']) as String? ?? '',
                    customName: p['custom_name'] as String?,
                    romCount: ((p['rom_count'] ?? p['roms_count'] ?? p['count']) as num?)?.toInt() ?? 0,
                    logoUrl: _logoUrl((p['logo_path'] ?? p['url_logo']) as String?),
                    category: (p['category'] as String?)?.trim().isNotEmpty == true ? (p['category'] as String).trim() : null,
                    generation: (p['generation'] as num?)?.toInt(),
                    familyName: (p['family_name'] as String?)?.trim().isNotEmpty == true ? (p['family_name'] as String).trim() : null,
                    familySlug: (p['family_slug'] as String?)?.trim().isNotEmpty == true ? (p['family_slug'] as String).trim() : null,
                    fsSizeBytes: (p['fs_size_bytes'] as num?)?.toInt() ?? 0,
                    firmwareCount: (p['firmware_count'] as num?)?.toInt() ?? (p['firmware'] is List ? (p['firmware'] as List).length : 0),
                  ),
            ];
            debugPrint('[ROMM] fallback /platforms count=${res.length}');
            return res;
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  /// Lista paginada de juegos de una plataforma (o de toda la biblioteca).
  /// Soporta orden por `last_played` para “Continuar jugando”:
  /// `GET /api/roms?last_played=true&order_by=last_played&order_dir=desc`
  Future<RommGamesPage> getGames({
    List<int>? platformIds,
    String? searchTerm,
    int limit = 60,
    int offset = 0,
    bool? lastPlayed,
    String? orderBy,
    String? orderDir,
  }) async {
    final res = await _dio.get(
      '/api/roms',
      queryParameters: {
        if (platformIds?.isNotEmpty == true) for (final id in platformIds!) 'platform_ids': id,
        if (searchTerm != null && searchTerm.isNotEmpty) 'search_term': searchTerm,
        if (lastPlayed != null) 'last_played': lastPlayed,
        if (orderBy != null && orderBy.isNotEmpty) 'order_by': orderBy,
        if (orderDir != null && orderDir.isNotEmpty) 'order_dir': orderDir,
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
    final res = await _dio.get('/api/roms/$id', options: _authOptions);
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final keys = data.keys.toList();
      debugPrint('[ROMM] GET /api/roms/$id keys=$keys back=${data['path_backcover'] ?? data['backcover_path'] ?? data['url_backcover']} spine=${data['path_spine'] ?? data['side_path'] ?? data['url_spine']} box3d=${data['box3d_path'] ?? data['path_box3d'] ?? data['url_box3d']}');
    }
    return _mapGame(res.data);
  }

  RommGame _mapGame(Map<String, dynamic>? g) {
    final files = g?['files'] as List? ?? const [];
    final firstFile = files.isNotEmpty ? (files.first['file_name'] as String?) : null;
    DateTime? lastPlayed;
    final ru = g?['rom_user'] as Map<String, dynamic>?;
    final rawLast = ru?['last_played'] as String?;
    if (rawLast != null && rawLast.isNotEmpty) {
      lastPlayed = DateTime.tryParse(rawLast);
    }
    String pickFirst(List<String> keys) {
      for (final k in keys) {
        final v = g?[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final frontLarge = pickFirst(const ['path_cover_large', 'cover_large_path']);
    final frontSmall = pickFirst(const ['path_cover_small', 'cover_small_path']);
    final frontFallback = pickFirst(const ['url_cover', 'cover_url']);
    final backRaw = pickFirst(const [
      'path_backcover',
      'backcover_path',
      'path_cover_back',
      'cover_back_path',
      'url_backcover',
      'backcover_url',
    ]);
    final spineRaw = pickFirst(const [
      'path_spine',
      'spine_path',
      'path_side',
      'side_path',
      'path_cover_side',
      'path_cover_spine',
      'cover_side_path',
      'cover_spine_path',
      'url_spine',
      'url_side',
      'spine_url',
      'side_url',
    ]);
    final box3dRaw = pickFirst(const [
      'box3d_path',
      'path_box3d',
      'path_box_3d',
      'url_box3d',
      'box3d_url',
    ]);
    String norm(String raw) {
      if (raw.isEmpty) return '';
      return assetUrl(raw);
    }

    final coverSmall = norm(frontSmall.isNotEmpty ? frontSmall : frontFallback);
    final coverLarge = norm(
      frontLarge.isNotEmpty ? frontLarge : (frontSmall.isNotEmpty ? frontSmall : frontFallback),
    );
    return RommGame(
      id: (g?['id'] as num?)?.toInt() ?? 0,
      name: g?['name'] as String? ?? g?['fs_name'] as String? ?? '',
      platformId: (g?['platform_id'] as num?)?.toInt() ?? 0,
      platformSlug: g?['platform_slug'] as String? ?? '',
      platformDisplayName: g?['platform_display_name'] as String? ?? g?['platform_custom_name'] as String? ?? '',
      summary: g?['summary'] as String?,
      coverSmallUrl: coverSmall,
      coverLargeUrl: coverLarge,
      coverBackUrl: norm(backRaw),
      coverSpineUrl: norm(spineRaw),
      box3dUrl: norm(box3dRaw),
      firstFile: firstFile,
      lastPlayed: lastPlayed,
    );
  }

  /// Descarga un asset protegido de RomM a bytes (para inyectar en WebView
  /// como base64 sin exponer el token).
  Future<List<int>?> downloadAssetBytes(String url) async {
    try {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(
          headers: {
            if (_token != null && _token!.isNotEmpty)
              'Authorization': 'Bearer $_token',
          },
          responseType: ResponseType.bytes,
        ),
      );
      return res.data;
    } catch (e) {
      debugPrint('[ROMM] asset bytes failed url=$url err=$e');
      return null;
    }
  }

  /// Marca un juego como jugado: PUT /api/roms/{id}/props?update_last_played=true
  Future<void> markPlayed(int romId) async {
    try {
      await _dio.put('/api/roms/$romId/props', queryParameters: {'update_last_played': true}, data: {}, options: _authOptions);
    } catch (_) {}
  }

  /// Config de streaming: devuelve si hay un contenedor para una plataforma.
  Future<bool> hasStreamingFor(String platformSlug) async {
    try {
      final res = await _dio.get('/api/streaming/config', options: _authOptions);
      final data = res.data as Map<String, dynamic>? ?? const {};
      final enabled = data['enabled'] == true;
      if (!enabled) return false;
      final containers = data['containers'] as List? ?? const [];
      return containers.any(
        (c) => (c as Map<String, dynamic>?)?['platform']?.toString().toLowerCase() == platformSlug.toLowerCase(),
      );
    } catch (_) {
      return false;
    }
  }

  /// Reclama una sesión de streaming y devuelve la URL del emulador web.
  Future<String?> claimStreamingSession(int romId) async {
    final res = await _dio.post(
      '/api/streaming/sessions',
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
    return '$base/api/roms/$romId/content/${Uri.encodeComponent(fileName)}';
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
