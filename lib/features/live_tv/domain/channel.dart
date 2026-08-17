import 'channel_capabilities.dart';
import 'media_source_type.dart';

/// Canal de Live TV independiente de la fuente.
class Channel {
  const Channel({
    required this.id,
    required this.name,
    this.number,
    this.logoUrl,
    required this.sourceType,
    required this.sourceId,
    this.group,
    this.genres = const [],
    this.streamUrl,
    this.isFavorite = false,
    this.isHd = false,
    this.capabilities = const ChannelCapabilities(),
  });

  final String id;
  final String name;

  /// Número de canal mostrado (p. ej. "101").
  final String? number;

  /// URL absoluta del logotipo, si hay.
  final String? logoUrl;

  final MediaSourceType sourceType;

  /// Identificador dentro de la fuente (p. ej. el id de Jellyfin).
  final String sourceId;

  /// Grupo (para M3U/IPTV); en Jellyfin se deriva del tipo de canal.
  final String? group;

  final List<String> genres;

  /// URL directa del stream, cuando la fuente la expone sin resolver.
  final String? streamUrl;

  final bool isFavorite;
  final bool isHd;
  final ChannelCapabilities capabilities;
}
