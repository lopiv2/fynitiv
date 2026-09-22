/// Pista de la Music API (jukebox) de ROMM: `GET /api/music/tracks`.
///
/// El NAS guarda `soundtrack/` junto a cada ROM y ROMM lo indexa con sus
/// etiquetas (título, artista, álbum, duración) y una `stream_url` propia.
class RommSoundtrackTrack {
  const RommSoundtrackTrack({
    required this.romFileId,
    required this.romId,
    this.title,
    this.artist,
    this.album,
    this.durationSeconds,
    this.trackNo,
    required this.streamUrl,
  });

  final int romFileId;
  final int romId;
  final String? title;
  final String? artist;
  final String? album;
  final double? durationSeconds;
  final int? trackNo;
  final String streamUrl;

  factory RommSoundtrackTrack.fromJson(
    Map<String, dynamic> json,
    String serverUrl,
  ) {
    String? optString(String key) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      return null;
    }

    int? optInt(String key) {
      final v = json[key];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim());
      return null;
    }

    double? optDouble(String key) {
      final v = json[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.trim());
      return null;
    }

    final rawUrl = optString('stream_url') ?? '';
    final base = serverUrl.replaceAll(RegExp(r'/$'), '');
    final absolute = rawUrl.startsWith('http')
        ? rawUrl
        : (rawUrl.isEmpty
            ? ''
            : '$base${rawUrl.startsWith('/') ? '' : '/'}$rawUrl');
    return RommSoundtrackTrack(
      romFileId: (json['rom_file_id'] as num?)?.toInt() ?? 0,
      romId: (json['rom_id'] as num?)?.toInt() ?? 0,
      title: optString('title'),
      artist: optString('artist'),
      album: optString('album'),
      durationSeconds: optDouble('duration_seconds'),
      trackNo: optInt('track'),
      streamUrl: absolute,
    );
  }

  /// Nombre visible: etiqueta o `Track {nº}` como fallback.
  String get displayName {
    if (title != null && title!.isNotEmpty) return title!;
    if (trackNo != null) return 'Track $trackNo';
    return 'Track';
  }

  /// Duración `m:ss` o null si ROMM no la da.
  String? get displayDuration {
    final secs = durationSeconds;
    if (secs == null || secs <= 0) return null;
    final total = secs.round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }
}
