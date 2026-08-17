import 'media_source_type.dart';

/// Programa de la guía, independiente de la fuente.
///
/// Todas las fechas son UTC. La UI las convierte a hora local al pintar.
class Program {
  const Program({
    required this.id,
    required this.channelId,
    required this.title,
    this.subtitle,
    this.description,
    required this.startTime,
    required this.endTime,
    this.imageUrl,
    this.genre,
    this.episodeNumber,
    this.seasonNumber,
    required this.sourceType,
    required this.sourceId,
  });

  final String id;
  final String channelId;
  final String title;
  final String? subtitle;
  final String? description;

  /// UTC.
  final DateTime startTime;

  /// UTC.
  final DateTime endTime;

  final String? imageUrl;
  final String? genre;
  final String? episodeNumber;
  final String? seasonNumber;
  final MediaSourceType sourceType;
  final String sourceId;

  bool contains(DateTime utcTime) =>
      !utcTime.isBefore(startTime) && utcTime.isBefore(endTime);
}
