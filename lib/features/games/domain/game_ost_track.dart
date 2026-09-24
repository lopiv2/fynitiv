/// Pista de OST con URL directa de audio (sin resolución intermedia).
class GameOstTrack {
  const GameOstTrack({
    required this.name,
    required this.url,
    this.duration,
    this.sizeBytes = 0,
    this.artist,
    this.album,
    this.romFileId = 0,
    this.isFavorite = false,
    this.gameName,
    this.gameId = 0,
    this.coverUrl,
  });

  final String name;
  final String url;
  final String? duration;

  /// Duración en segundos (`duration_seconds`): 0 si se desconoce.
  double get durationSeconds {
    final d = duration;
    if (d == null || d.isEmpty) return 0;
    final parts = d.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final s = int.tryParse(parts[1]);
      if (m != null && s != null) return (m * 60 + s).toDouble();
    }
    return 0;
  }

  /// Tamaño del fichero (solo informativo/diagnóstico).
  final int sizeBytes;

  /// Artista/álbum de la Music API de ROMM (pueden venir null).
  final String? artist;
  final String? album;

  /// `rom_file_id` de la Music API: id necesario para
  /// `POST`/`DELETE /api/music/favorites`. 0 si se desconoce (sin corazón).
  final int romFileId;

  /// Estado inicial de favorita según `is_favorite` del servidor.
  final bool isFavorite;

  /// Juego dueño (listados globales del Jukebox): subtítulo cuando no hay
  /// artista. Null en el detalle de juego (ahí manda el juego abierto).
  final String? gameName;

  /// `rom_id` del juego dueño (0 si se desconoce). Sirve para resolver la
  /// portada cuando la pista no trae cover propio.
  final int gameId;

  /// Portada del juego dueño (frontal `coverLargeUrl` > `coverSmallUrl` en
  /// el detalle, `cover_url` de `GET /api/music/games` en el Jukebox).
  /// Null/vacía = sin cover (la UI cae al icono musical).
  final String? coverUrl;

  /// Subtítulo visible: artista, juego dueño o [fallback].
  String subtitle(String fallback) {
    if (artist != null && artist!.isNotEmpty) return artist!;
    if (gameName != null && gameName!.isNotEmpty) return gameName!;
    return fallback;
  }
}
