import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import 'khinsider_models.dart';

/// Wrapper scraper para downloads.khinsider.com
/// Usa Dio + html para buscar álbum por nombre y extraer lista de pistas.
class KhinsiderScraper {
  KhinsiderScraper({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 12),
              followRedirects: true,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml',
                'Accept-Language': 'en-US,en;q=0.9,es;q=0.8',
                'Referer': 'https://downloads.khinsider.com/',
              },
            ),
          );

  final Dio _dio;
  static const _base = 'https://downloads.khinsider.com';

  String _normalizeQuery(String input) {
    var s = input.toLowerCase().trim();
    // Con unicode:true, \w cubre letras acentuadas, ñ, etc.
    s = s.replaceAll(RegExp(r'[^\w\s\-]', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Busca álbum por nombre de juego. Retorna el mejor match o null.
  Future<KhinsiderAlbum?> searchAlbum(String gameName) async {
    final query = _normalizeQuery(gameName);
    if (query.isEmpty) return null;

    try {
      final url = '$_base/search?search=${Uri.encodeComponent(query)}';
      final resp = await _dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final html = resp.data ?? '';
      final doc = html_parser.parse(html);

      // Detectar el caso "búsqueda no filtrada": khinsider devuelve el catálogo
      // completo con un texto tipo "Found 10000 matching albums."
      final resultText = doc.querySelector('#pageContent p')?.text.trim() ?? '';
      final unfiltered = RegExp(
        r'Found \d{3,} matching albums',
      ).hasMatch(resultText);
      if (unfiltered) {
        debugPrint(
          '[KHINSIDER] búsqueda no filtró (catálogo completo) para "$query"',
        );
        return _searchWithFallbackVariants(query);
      }

      final albumLinks = doc.querySelectorAll(
        'table.albumList a[href*="/game-soundtracks/album/"]',
      );
      if (albumLinks.isNotEmpty) {
        final a = albumLinks.first;
        final href = a.attributes['href'] ?? '';
        final albumUrl = href.startsWith('http') ? href : '$_base$href';
        return KhinsiderAlbum(title: a.text.trim(), albumUrl: albumUrl);
      }
    } catch (e, st) {
      debugPrint('[KHINSIDER] searchAlbum error: $e\n$st');
    }

    return _searchWithFallbackVariants(query);
  }

  /// Reintenta con variantes más cortas del nombre cuando la búsqueda
  /// principal no filtra o no encuentra nada (p. ej. quitar subtítulos
  /// tras ":" o "-", o probar solo las primeras 2-3 palabras).
  Future<KhinsiderAlbum?> _searchWithFallbackVariants(String query) async {
    final variants = <String>{
      query.split(RegExp(r'[:\-]')).first.trim(),
      query.split(' ').take(2).join(' '),
    }..removeWhere((v) => v.isEmpty || v == query);

    for (final variant in variants) {
      debugPrint('[KHINSIDER] reintentando con variante="$variant"');
      try {
        final url = '$_base/search?search=${Uri.encodeComponent(variant)}';
        final resp = await _dio.get<String>(
          url,
          options: Options(responseType: ResponseType.plain),
        );
        final doc = html_parser.parse(resp.data ?? '');
        final resultText =
            doc.querySelector('#pageContent p')?.text.trim() ?? '';
        if (RegExp(r'Found \d{3,} matching albums').hasMatch(resultText))
          continue;

        final albumLinks = doc.querySelectorAll(
          'table.albumList a[href*="/game-soundtracks/album/"]',
        );
        if (albumLinks.isNotEmpty) {
          final a = albumLinks.first;
          final href = a.attributes['href'] ?? '';
          return KhinsiderAlbum(
            title: a.text.trim(),
            albumUrl: href.startsWith('http') ? href : '$_base$href',
          );
        }
      } catch (_) {}
    }
    debugPrint('[KHINSIDER] todas las variantes fallaron');
    return null;
  }

  /// Obtiene todas las pistas del álbum.
  Future<List<KhinsiderTrack>> getTracks(KhinsiderAlbum album) async {
    debugPrint('[KHINSIDER] getTracks albumUrl=${album.albumUrl}');
    try {
      final resp = await _dio.get<String>(
        album.albumUrl,
        options: Options(responseType: ResponseType.plain),
      );
      debugPrint(
        '[KHINSIDER] getTracks status=${resp.statusCode} length=${resp.data?.length}',
      );
      final html = resp.data ?? '';
      final doc = html_parser.parse(html);

      final table = doc.querySelector('table#songlist');
      debugPrint(
        '[KHINSIDER] table#songlist ${table == null ? 'NO ENCONTRADA' : 'encontrada'}',
      );
      if (table == null) {
        debugPrint(
          '[KHINSIDER] HTML snippet: ${html.substring(0, html.length.clamp(0, 800))}',
        );
        return [];
      }

      final rows = table.querySelectorAll('tr');
      final tracks = <KhinsiderTrack>[];

      for (final tr in rows) {
        if (tr.id == 'songlist_header') continue;
        // Cada fila tiene varios <a href="...mp3"> con mismo href; coger el primero de nombre
        final links = tr.querySelectorAll('a[href*=".mp3"]');
        if (links.isEmpty) continue;
        final first = links.first;
        final href = first.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        final name = first.text.trim();
        if (name.isEmpty) continue;

        // El href puede estar como /game-soundtracks/album/.../01%2520Title.mp3
        final absolute = href.startsWith('http') ? href : '$_base$href';
        // intentar duración: segunda columna clickable-row a[href$=".mp3"] texto tipo 0:14
        String? duration;
        if (links.length >= 2) {
          final durText = links[1].text.trim();
          if (RegExp(r'^\d+:\d+$').hasMatch(durText)) duration = durText;
        }
        tracks.add(
          KhinsiderTrack(name: name, pageUrl: absolute, duration: duration),
        );
      }
      debugPrint(
        '[KHINSIDER] getTracks TOTAL ${tracks.length} pistas para ${album.albumUrl}',
      );
      return tracks;
    } catch (e, st) {
      debugPrint('[KHINSIDER] getTracks error: $e\n$st');
      return [];
    }
  }

  /// Dado el href de la "página" de una canción (el que aparece en la tabla),
  /// resuelve la URL real y descargable del audio.
  Future<String?> resolveDownloadUrl(String songPageUrl) async {
    try {
      final resp = await _dio.get<String>(
        songPageUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final doc = html_parser.parse(resp.data ?? '');

      // 1) Caso más común: <p class="songDownloadLink"><a href="...mp3">
      final downloadLink = doc
          .querySelector('p.songDownloadLink a')
          ?.attributes['href'];
      if (downloadLink != null && downloadLink.isNotEmpty) {
        debugPrint('[KHINSIDER] resolved via songDownloadLink: $downloadLink');
        return downloadLink;
      }

      // 2) Fallback: <audio><source src="...">
      final audioSrc =
          doc.querySelector('audio source')?.attributes['src'] ??
          doc.querySelector('audio')?.attributes['src'];
      if (audioSrc != null && audioSrc.isNotEmpty) {
        debugPrint('[KHINSIDER] resolved via <audio>: $audioSrc');
        return audioSrc;
      }

      debugPrint('[KHINSIDER] no se pudo resolver mp3 real en $songPageUrl');
      return null;
    } catch (e, st) {
      debugPrint('[KHINSIDER] resolveDownloadUrl error: $e\n$st');
      return null;
    }
  }

  Future<List<KhinsiderTrack>> searchAndGetTracks(String gameName) async {
    final album = await searchAlbum(gameName);
    if (album == null) return [];
    return getTracks(album);
  }
}
