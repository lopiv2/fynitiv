import 'package:dio/dio.dart';

class LrcLine {
  const LrcLine({required this.time, required this.text});
  final Duration time;
  final String text;
}

class LrcResult {
  const LrcResult({
    required this.plainLyrics,
    this.syncedLines,
    this.isInstrumental = false,
  });

  final String plainLyrics;
  final List<LrcLine>? syncedLines;
  final bool isInstrumental;

  bool get hasSynced => syncedLines != null && syncedLines!.isNotEmpty;
}

class LrclibRepository {
  LrclibRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static final RegExp _lrcRegex = RegExp(r'\[(\d+):(\d+)\.(\d+)\]');

  List<LrcLine> _parseSynced(String raw) {
    final lines = <LrcLine>[];
    for (final row in raw.split('\n')) {
      final match = _lrcRegex.firstMatch(row);
      if (match == null) continue;
      final min = int.tryParse(match.group(1) ?? '') ?? 0;
      final sec = int.tryParse(match.group(2) ?? '') ?? 0;
      final msRaw = match.group(3) ?? '0';
      // LRC puede venir como .xx (centésimas) o .xxx (milis)
      final ms = msRaw.length == 2 ? int.parse(msRaw) * 10 : int.tryParse(msRaw.padRight(3, '0').substring(0, 3)) ?? 0;
      final text = row.replaceFirst(_lrcRegex, '').trim();
      if (text.isEmpty) continue;
      lines.add(LrcLine(time: Duration(minutes: min, seconds: sec, milliseconds: ms), text: text));
    }
    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  Future<LrcResult?> fetch({
    required String artist,
    required String track,
    String? album,
    Duration? duration,
  }) async {
    if (artist.trim().isEmpty || track.trim().isEmpty) return null;
    final durSec = duration != null && duration.inSeconds > 0 ? duration.inSeconds.toString() : null;

    // Intento principal: GET /api/get con duración para desambiguar
    try {
      final res = await _dio.get(
        'https://lrclib.net/api/get',
        queryParameters: {
          'artist_name': artist,
          'track_name': track,
          if (album != null && album.isNotEmpty) 'album_name': album,
          if (durSec != null) 'duration': durSec,
        },
        options: Options(validateStatus: (_) => true),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final m = res.data as Map;
        final plain = (m['plainLyrics'] as String?) ?? '';
        final synced = m['syncedLyrics'] as String?;
        final instrumental = m['instrumental'] as bool? ?? false;
        if (instrumental) {
          return LrcResult(plainLyrics: plain, syncedLines: const [], isInstrumental: true);
        }
        if (synced != null && synced.trim().isNotEmpty) {
          return LrcResult(plainLyrics: plain, syncedLines: _parseSynced(synced));
        }
        if (plain.trim().isNotEmpty) {
          return LrcResult(plainLyrics: plain, syncedLines: null);
        }
      }
    } catch (_) {}

    // Fallback: search y coger primer resultado con synced
    try {
      final res = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {
          'artist_name': artist,
          'track_name': track,
          if (album != null && album.isNotEmpty) 'album_name': album,
        },
        options: Options(validateStatus: (_) => true),
      );
      if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
        final first = (res.data as List).first;
        if (first is Map) {
          final plain = (first['plainLyrics'] as String?) ?? '';
          final synced = first['syncedLyrics'] as String?;
          final instrumental = first['instrumental'] as bool? ?? false;
          if (instrumental) return LrcResult(plainLyrics: plain, syncedLines: const [], isInstrumental: true);
          if (synced != null && synced.trim().isNotEmpty) {
            return LrcResult(plainLyrics: plain, syncedLines: _parseSynced(synced));
          }
          if (plain.trim().isNotEmpty) return LrcResult(plainLyrics: plain, syncedLines: null);
        }
      }
    } catch (_) {}
    return null;
  }
}
