/// Pista de OST con URL directa de audio (sin resolución intermedia).
class GameOstTrack {
  const GameOstTrack({
    required this.name,
    required this.url,
    this.duration,
    this.sizeBytes = 0,
    this.artist,
    this.album,
  });

  final String name;
  final String url;
  final String? duration;

  /// Tamaño del fichero (solo informativo/diagnóstico).
  final int sizeBytes;

  /// Artista/álbum de la Music API de ROMM (pueden venir null).
  final String? artist;
  final String? album;
}
