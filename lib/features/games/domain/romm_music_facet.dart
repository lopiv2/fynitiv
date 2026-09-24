/// Facets del Jukebox de ROMM (`GET /api/music/games|artists|albums|…`).
/// El Jukebox agrupa todas las bandas sonoras de la biblioteca: juegos
/// (la "album list"), tags con counts y totales globales.
///
/// Un juego con banda sonora: entrada de la "album list" del Jukebox
/// (`MusicGameFacetSchema`).
class MusicGameEntry {
  const MusicGameEntry({
    required this.romId,
    required this.name,
    required this.platformId,
    required this.platformSlug,
    required this.platformName,
    this.coverUrl,
    this.count = 0,
  });

  final int romId;
  final String name;
  final int platformId;
  final String platformSlug;
  final String platformName;
  final String? coverUrl;
  final int count;

  factory MusicGameEntry.fromJson(
    Map<String, dynamic> json,
    String serverUrl,
  ) {
    String str(String key) {
      final v = json[key];
      return v is String ? v : '';
    }

    int intOf(String key) {
      final v = json[key];
      return v is num ? v.toInt() : 0;
    }

    final rawCover = json['cover_url'];
    String? cover;
    if (rawCover is String && rawCover.trim().isNotEmpty) {
      final t = rawCover.trim();
      if (t.startsWith('http')) {
        cover = t;
      } else {
        final base = serverUrl.replaceAll(RegExp(r'/$'), '');
        cover = '$base${t.startsWith('/') ? '' : '/'}$t';
      }
    }
    return MusicGameEntry(
      romId: intOf('rom_id'),
      name: str('name'),
      platformId: intOf('platform_id'),
      platformSlug: str('platform_slug'),
      platformName: str('platform_name'),
      coverUrl: cover,
      count: intOf('count'),
    );
  }
}

/// Valor de un facet de tags (`FacetValueSchema`): artista, álbum, género
/// o año con su nº de pistas. `value` siempre se guarda como texto (los
/// años llegan como int y se parsean al filtrar).
class MusicFacetValue {
  const MusicFacetValue({
    required this.value,
    required this.count,
    this.platformId,
  });

  final String value;
  final int count;
  final int? platformId;

  factory MusicFacetValue.fromJson(Map<String, dynamic> json) {
    final v = json['value'];
    return MusicFacetValue(
      value: v == null ? '' : v.toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Totales globales del Jukebox (`MusicStatsSchema`).
class MusicStats {
  const MusicStats({
    required this.totalTracks,
    required this.totalDurationSeconds,
  });

  final int totalTracks;
  final double totalDurationSeconds;

  /// Duración total `H:MM:SS` (o `M:SS` si baja de una hora).
  String get displayTotal {
    final total = totalDurationSeconds.round().clamp(0, 1 << 31);
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  factory MusicStats.fromJson(Map<String, dynamic> json) {
    double secs(dynamic v) => v is num ? v.toDouble() : 0;
    return MusicStats(
      totalTracks: (json['total_tracks'] as num?)?.toInt() ?? 0,
      totalDurationSeconds: secs(json['total_duration_seconds']),
    );
  }
}
