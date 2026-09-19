import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:path_provider/path_provider.dart';

/// Tope de la caché de themes descargados (150 MB ≈ 20-40 themes).
const kThemeCacheMaxBytes = 150 * 1024 * 1024;

/// Antigüedad máxima de un theme en caché (30 días, limpieza en arranque).
const kThemeCacheMaxAge = Duration(days: 30);

/// Carpeta de themes descargados dentro del temporal. La crea si no existe.
Future<Directory> ensureThemeCacheDir() async {
  final tmp = await getTemporaryDirectory();
  final dir = Directory('${tmp.path}/item_themes');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Borra los ficheros más antiguos (LRU) hasta volver bajo [maxBytes].
Future<void> pruneThemeCacheDir(
  Directory dir, {
  int maxBytes = kThemeCacheMaxBytes,
}) async {
  try {
    final entries = <({File file, int size, DateTime modified})>[];
    var total = 0;
    await for (final e in dir.list()) {
      if (e is! File) continue;
      try {
        final stat = await e.stat();
        total += stat.size;
        entries.add((file: e, size: stat.size, modified: stat.modified));
      } catch (_) {}
    }
    if (total <= maxBytes) return;
    entries.sort((a, b) => a.modified.compareTo(b.modified));
    var freed = 0;
    var count = 0;
    for (final entry in entries) {
      if (total <= maxBytes) break;
      try {
        await entry.file.delete();
        total -= entry.size;
        freed += entry.size;
        count++;
      } catch (_) {}
    }
    debugPrint('[Theme] cache prune freed=$freed bytes files=$count total=$total');
  } catch (error) {
    debugPrint('[Theme] cache prune error: $error');
  }
}

/// Limpieza best-effort en arranque: borra themes más viejos que
/// [kThemeCacheMaxAge]. No debe retrasar ni romper el inicio.
Future<void> pruneStaleThemeCache() async {
  try {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/item_themes');
    if (!await dir.exists()) return;
    final cutoff = DateTime.now().subtract(kThemeCacheMaxAge);
    var count = 0;
    await for (final e in dir.list()) {
      if (e is! File) continue;
      try {
        if ((await e.stat()).modified.isBefore(cutoff)) {
          await e.delete();
          count++;
        }
      } catch (_) {}
    }
    if (count > 0) debugPrint('[Theme] cache startup prune files=$count');
  } catch (error) {
    debugPrint('[Theme] cache startup prune error: $error');
  }
}

/// Resultado de ThemerrDB para un item: URL de YouTube del theme + videoId.
class ThemerrHit {
  const ThemerrHit({required this.youtubeUrl, required this.youtubeId});

  final String youtubeUrl;
  final String youtubeId;
}

/// Resolver cliente de ThemerrDB (LizardByte).
///
/// Base de datos curada de themes para películas y series:
/// `https://app.lizardbyte.dev/ThemerrDB/<type>/<db>/<id>.json`
/// con clave `youtube_theme_url`.
///
/// No requiere API key. Los 404 son misses normales (DB incompleta).
class ThemerrResolver {
  ThemerrResolver({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _base = 'https://app.lizardbyte.dev/ThemerrDB';

  /// Extrae un providerId sin importar mayúsculas (Tmdb/tmdb/TMDB...).
  static String? providerIdOf(BaseItemDto item, String name) {
    final ids = item.providerIds;
    if (ids == null || ids.isEmpty) return null;
    for (final entry in ids.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        final v = entry.value.trim();
        if (v.isNotEmpty) return v;
      }
    }
    return null;
  }

  /// Extrae el videoId de una URL de YouTube (watch?v=, youtu.be, /shorts/).
  static String? youtubeIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    if ((uri.host.contains('youtu.be')) && uri.pathSegments.isNotEmpty) {
      final id = uri.pathSegments.first;
      if (id.isNotEmpty) return id;
    }
    if (uri.pathSegments.contains('shorts')) {
      final i = uri.pathSegments.indexOf('shorts');
      if (i + 1 < uri.pathSegments.length) {
        final id = uri.pathSegments[i + 1];
        if (id.isNotEmpty) return id;
      }
    }
    return null;
  }

  /// Candidatos ThemerrDB para el item, en orden de prioridad.
  /// Películas: movies/themoviedb, movies/imdb.
  /// Series/temporadas/episodios: tv_shows/themoviedb (con el Tmdb propio).
  /// Para episodios/temporadas cuyo Tmdb es del capítulo, el llamador puede
  /// pasar el Tmdb de la serie vía [seriesTmdbId] (resuelto con SeriesId).
  static List<String> candidateUrls(
    BaseItemDto item, {
    String? seriesTmdbId,
  }) {
    final tmdb = providerIdOf(item, 'Tmdb');
    final imdb = providerIdOf(item, 'Imdb');
    final type = item.type;
    final urls = <String>[];
    if (type == BaseItemKind.movie) {
      if (tmdb != null) urls.add('$_base/movies/themoviedb/$tmdb.json');
      if (imdb != null) urls.add('$_base/movies/imdb/$imdb.json');
    } else if (type == BaseItemKind.series ||
        type == BaseItemKind.season ||
        type == BaseItemKind.episode) {
      final seriesTmdb = (seriesTmdbId != null && seriesTmdbId.isNotEmpty)
          ? seriesTmdbId
          : tmdb;
      if (seriesTmdb != null) {
        urls.add('$_base/tv_shows/themoviedb/$seriesTmdb.json');
      }
      // Fallback: la película con el mismo Tmdb (raro, pero barato).
      if (tmdb != null && tmdb != seriesTmdb) {
        urls.add('$_base/movies/themoviedb/$tmdb.json');
      }
    } else {
      if (tmdb != null) urls.add('$_base/movies/themoviedb/$tmdb.json');
      if (imdb != null) urls.add('$_base/movies/imdb/$imdb.json');
    }
    return urls;
  }

  /// Resuelve el theme de ThemerrDB probando los candidatos en orden.
  /// Devuelve null si no hay cobertura (404 o sin youtube_theme_url).
  Future<ThemerrHit?> resolve(
    BaseItemDto item, {
    String? seriesTmdbId,
  }) async {
    final candidates = candidateUrls(item, seriesTmdbId: seriesTmdbId);
    debugPrint('[Theme] ThemerrDB candidates item=${item.name}: $candidates');
    if (candidates.isEmpty) {
      debugPrint('[Theme] ThemerrDB sin candidatos (sin Tmdb/Imdb) item=${item.name}');
      return null;
    }
    for (final url in candidates) {
      try {
        final res = await _dio
            .get<Map<String, dynamic>>(
              url,
              options: Options(
                responseType: ResponseType.json,
                sendTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            )
            .timeout(const Duration(seconds: 10));
        final data = res.data;
        final themeUrl = data?['youtube_theme_url'];
        debugPrint(
          '[Theme] ThemerrDB GET $url status=${res.statusCode} '
          'theme=${themeUrl is String && themeUrl.isNotEmpty ? themeUrl : '(vacío)'}',
        );
        if (themeUrl is String && themeUrl.isNotEmpty) {
          final id = youtubeIdFromUrl(themeUrl);
          if (id != null && id.isNotEmpty) {
            return ThemerrHit(youtubeUrl: themeUrl, youtubeId: id);
          }
          debugPrint('[Theme] ThemerrDB videoId inválido en $url');
        }
        // 200 sin theme: seguir con el siguiente candidato de la lista.
        if (res.statusCode == 200) continue;
      } on DioException catch (e) {
        // 404 = sin cobertura: probar siguiente candidato en silencio.
        debugPrint(
          '[Theme] ThemerrDB GET $url error status=${e.response?.statusCode} ${e.type}',
        );
        if (e.response?.statusCode == 404) continue;
        return null;
      } catch (error) {
        debugPrint('[Theme] ThemerrDB GET $url excepción: $error');
        return null;
      }
    }
    return null;
  }
}
