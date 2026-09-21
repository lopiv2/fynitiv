import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/game_ost_track.dart';

/// OST de juegos vía API pública de archive.org (sin scraping ni auth).
///
/// Flujo: advancedsearch (título + mediatype:audio) → mejor item por
/// coincidencia → metadata/{id} → ficheros MP3 → URLs directas de stream
/// `https://archive.org/download/{id}/{fichero}`.
class ArchiveOstRepository {
  ArchiveOstRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
                'Accept': 'application/json',
              },
            ),
          );

  final Dio _dio;

  String _normalize(String input) {
    var s = input.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[^\w\s]', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  double _scoreItem(String title, String query) {
    final rawLower = title.toLowerCase();
    final norm = _normalize(title);
    final qTokens = query.split(' ').where((w) => w.length > 2).toSet();
    final tTokens = norm.split(' ').toSet();
    var score = qTokens.isEmpty
        ? 0.0
        : qTokens.intersection(tTokens).length / qTokens.length;
    if (norm.contains(query)) score += 0.5;
    if (norm.contains('soundtrack') || norm.contains('ost')) score += 0.3;
    if (norm.contains('music') || norm.contains('score')) score += 0.1;
    if (norm.contains('podcast') ||
        norm.contains('episode') ||
        norm.contains('interview') ||
        norm.contains('review') ||
        norm.contains('talk show')) {
      score -= 0.6;
    }
    // Marcadores de episodio/capítulo tipo "(SF 13)", "#69", "Ep. 5":
    // casi nunca son la banda sonora. Se mira el título crudo porque
    // la normalización quita paréntesis y '#' (ahí vive la señal).
    if (RegExp(
      r'(\(\s*(sf|ep|eps|episode|show|vol|part|n[ºo]|#)?\s*\.?\s*\d+\)|#\d+|\bep\.?\s*\d+|\bepisode\s*\d+|\bpart\s*\d+|\bvol\.?\s*\d+)',
    ).hasMatch(rawLower)) {
      score -= 0.7;
    }
    return score;
  }

  int _asInt(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
    return 0;
  }

  String _prettyName(String fileName) {
    var s = fileName;
    final dot = s.lastIndexOf('.');
    if (dot > 0) s = s.substring(0, dot);
    return s.replaceAll('_', ' ').trim();
  }

  String? _formatDuration(dynamic raw) {
    final secs = double.tryParse(raw?.toString() ?? '');
    if (secs == null || secs <= 0) return null;
    final m = (secs ~/ 60).toString();
    final s = (secs % 60).round().toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<List<GameOstTrack>> searchAndGetTracks(String gameName) async {
    final query = _normalize(gameName);
    if (query.isEmpty) return [];
    try {
      final ranked = await _rankedDocs('"$query" AND mediatype:audio', 50, query);
      if (ranked.isEmpty) return [];
      final cache = <String, List<GameOstTrack>>{};
      var winner = await _pickWinner(ranked, cache);
      // Ganador débil (nada, 1-2 pistas, o título sin pinta de OST como
      // una banda homónima): segunda búsqueda apuntando a bandas sonoras.
      if (winner == null ||
          winner.tracks.length <= 2 ||
          !_looksLikeSoundtrack(winner.title)) {
        final ranked2 = await _rankedDocs(
          '"$query" AND (soundtrack OR ost OR "original score" OR "video game music" OR vgm) AND mediatype:audio',
          20,
          query,
        );
        final merged = _mergeRanked(ranked, ranked2);
        winner = await _pickWinner(merged, cache);
      }
      if (winner != null) {
        debugPrint(
          '[ARCHIVE-OST] elegido ${winner.id} "${winner.title}" '
          '→ ${winner.tracks.length} pistas',
        );
        return winner.tracks;
      }
      debugPrint('[ARCHIVE-OST] sin MP3 en los mejores candidatos');
      return [];
    } catch (e) {
      debugPrint('[ARCHIVE-OST] search error: $e');
      return [];
    }
  }

  Future<List<({String id, String title, double score})>> _rankedDocs(
    String q,
    int rows,
    String query,
  ) async {
    final searchRes = await _dio.get<Map<String, dynamic>>(
      'https://archive.org/advancedsearch.php',
      queryParameters: {
        'q': q,
        'fl[]': ['identifier', 'title', 'creator'],
        'rows': rows,
        'output': 'json',
      },
    );
    final docs = (searchRes.data?['response']?['docs'] as List?) ?? const [];
    debugPrint('[ARCHIVE-OST] búsqueda "$q": ${docs.length} items');
    final ranked = [
      for (final d in docs)
        if (d is Map<String, dynamic> &&
            (d['identifier'] as String?)?.isNotEmpty == true)
          (
            id: d['identifier'] as String,
            title: (d['title'] as String?) ?? '',
            score: _scoreItem((d['title'] as String?) ?? '', query),
          ),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return ranked;
  }

  List<({String id, String title, double score})> _mergeRanked(
    List<({String id, String title, double score})> a,
    List<({String id, String title, double score})> b,
  ) {
    final byId = <String, ({String id, String title, double score})>{};
    for (final c in [...a, ...b]) {
      final prev = byId[c.id];
      if (prev == null || c.score > prev.score) byId[c.id] = c;
    }
    final merged = byId.values.toList()
      ..sort((x, y) => y.score.compareTo(x.score));
    return merged;
  }

  /// Metadata de los mejores por título y re-rank con nº de pistas:
  /// una OST real trae muchas; un podcast suele traer 1 (y de 100 MB,
  /// que además tarda una eternidad en cargar para streaming).
  Future<GameOstTrackResult?> _pickWinner(
    List<({String id, String title, double score})> ranked,
    Map<String, List<GameOstTrack>> cache,
  ) async {
    GameOstTrackResult? winner;
    for (final cand in ranked.take(5)) {
      final tracks = cache[cand.id] ??= await _itemTracks(cand.id);
      var totalMb = 0.0;
      for (final t in tracks) {
        totalMb += t.sizeBytes / 1048576;
      }
      final finalScore =
          cand.score + (tracks.length * 0.04).clamp(0.0, 0.4);
      debugPrint(
        '[ARCHIVE-OST] cand ${cand.id} "${cand.title}" '
        'title=${cand.score.toStringAsFixed(2)} tracks=${tracks.length} '
        'mb=${totalMb.toStringAsFixed(1)} final=${finalScore.toStringAsFixed(2)}',
      );
      if (tracks.isNotEmpty &&
          (winner == null || finalScore > winner.score)) {
        winner = GameOstTrackResult(
          tracks: tracks,
          score: finalScore,
          id: cand.id,
          title: cand.title,
        );
      }
    }
    return winner;
  }

  /// ¿El título parece una banda sonora (no un podcast/banda homónima)?
  bool _looksLikeSoundtrack(String title) {
    final norm = _normalize(title);
    return norm.contains('soundtrack') ||
        norm.contains('ost') ||
        norm.contains('original score') ||
        norm.contains('video game music') ||
        norm.contains('vgm') ||
        norm.contains('game music') ||
        norm.contains('music from');
  }

  Future<List<GameOstTrack>> _itemTracks(String id) async {
    try {
      final metaRes = await _dio.get<Map<String, dynamic>>(
        'https://archive.org/metadata/$id',
        options: Options(receiveTimeout: const Duration(seconds: 25)),
      );
      final files = (metaRes.data?['files'] as List?) ?? const [];
      // archive.org deriva cada tema en varios formatos ("MP3" y "VBR MP3"):
      // deduplicar por nombre quedándose el VBR (mejor calidad).
      final byStem = <String, Map<String, dynamic>>{};
      for (final f in files) {
        if (f is! Map<String, dynamic>) continue;
        // archive.org a veces tipa distinto: todo defensivo, nada de `as`.
        final format = f['format']?.toString().toUpperCase() ?? '';
        final name = f['name']?.toString() ?? '';
        if (!format.contains('MP3')) continue;
        if (name.isEmpty || name.startsWith('_')) continue;
        final stem = _prettyName(name).toLowerCase();
        final prev = byStem[stem];
        if (prev == null) {
          byStem[stem] = f;
        } else {
          final prevVbr = (prev['format']?.toString().toUpperCase() ?? '')
              .contains('VBR');
          if (!prevVbr && format.contains('VBR')) byStem[stem] = f;
        }
      }
      final mp3s = byStem.values.toList()
        ..sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
      return [
        for (final f in mp3s)
          GameOstTrack(
            name: _prettyName(f['name'] as String),
            url:
                'https://archive.org/download/$id/${Uri.encodeComponent(f['name'] as String)}',
            duration: _formatDuration(f['length']),
            sizeBytes: _asInt(f['size']),
          ),
      ];
    } catch (e) {
      debugPrint('[ARCHIVE-OST] metadata $id error: $e');
      return [];
    }
  }
}

/// Candidato ganador (interno): pistas + puntuación final.
class GameOstTrackResult {
  const GameOstTrackResult({
    required this.tracks,
    required this.score,
    required this.id,
    required this.title,
  });

  final List<GameOstTrack> tracks;
  final double score;
  final String id;
  final String title;
}
