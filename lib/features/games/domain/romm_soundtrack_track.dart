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
    this.isFavorite = false,
    this.gameName,
  });

  final int romFileId;
  final int romId;
  final String? title;
  final String? artist;
  final String? album;
  final double? durationSeconds;
  final int? trackNo;
  final String streamUrl;

  /// `is_favorite` de `MusicTrackSchema` (GET /api/music/tracks la incluye
  /// para el usuario que pide). False si el servidor no la envía.
  final bool isFavorite;

  /// Juego dueño de la pista (`game_name`): útil en listados globales
  /// (Jukebox) donde no hay contexto de juego. Null en respuestas antiguas.
  final String? gameName;

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
      isFavorite: json['is_favorite'] == true,
      gameName: optString('game_name'),
    );
  }

  /// Nombre visible: etiqueta, nombre del fichero o `Track {nº}`.
  /// Algunos rips (p. ej. Loom FM-Towns) no traen etiquetas en la Music API:
  /// en ese caso se usa el stem del fichero de `stream_url`.
  String get displayName {
    if (title != null && title!.isNotEmpty) return title!;
    final file = _fileStem(streamUrl);
    if (file.isNotEmpty) return file;
    if (trackNo != null) return 'Track $trackNo';
    return 'Track';
  }

  /// Stem legible del fichero de [url]: URL-decodificado, sin extensión,
  /// `_` → espacio y sin prefijo de número (`01 - `, `03_`) porque la lista
  /// ya numera los items. '' si no se puede deducir.
  String _fileStem(String url) {
    try {
      final segs = Uri.parse(url.trim()).pathSegments;
      var name = segs.isEmpty
          ? ''
          : Uri.decodeComponent(segs.last).trim();
      final dot = name.lastIndexOf('.');
      if (dot > 0) name = name.substring(0, dot).trim();
      name = name.replaceAll('_', ' ').trim();
      name = name.replaceFirst(RegExp(r'^\d{1,3}\s*[-_.]\s*'), '').trim();
      return name;
    } catch (_) {
      return '';
    }
  }

  /// Número efectivo para ordenar la lista: manda el número líder del
  /// título (`01. The Adventure Continues`) o del nombre de fichero en
  /// `stream_url` (`01. The Adventure Continues.mp3`), aunque los metadatos
  /// no traigan `track`. Fallback al tag `track`, null si no hay número.
  int? get sortNumber {
    final fromTitle = _leadingNumber(title);
    if (fromTitle != null) return fromTitle;
    final fromFile = _leadingNumber(_rawFileName(streamUrl));
    if (fromFile != null) return fromFile;
    return trackNo;
  }

  /// Número líder de [text] (`01. X`, `03 - X`, `04_X`, `(05) X`, `[06] X`).
  /// null si no empieza por número.
  static int? _leadingNumber(String? text) {
    final s = text?.trim() ?? '';
    if (s.isEmpty) return null;
    final m = RegExp(r'^[\(\[]?\s*(\d{1,4})(?:\s*[\).\]\-_\s]|$)').firstMatch(s);
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!);
    if (n == null || n <= 0) return null;
    return n;
  }

  /// Nombre crudo del fichero de [url]: URL-decodificado y sin extensión,
  /// conservando el prefijo numérico (al contrario que [_fileStem]).
  /// '' si no se puede deducir.
  static String _rawFileName(String url) {
    try {
      final segs = Uri.parse(url.trim()).pathSegments;
      if (segs.isEmpty) return '';
      var name = Uri.decodeComponent(segs.last).trim();
      final dot = name.lastIndexOf('.');
      if (dot > 0) name = name.substring(0, dot).trim();
      return name;
    } catch (_) {
      return '';
    }
  }

  /// Duración `m:ss` o null si ROMM no la da.
  String? get displayDuration {
    final secs = durationSeconds;
    if (secs == null || secs <= 0) return null;
    final total = secs.round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }
}
