import 'package:jellyfin_dart/jellyfin_dart.dart' hide MediaSourceType;

import '../domain/channel.dart';
import '../domain/channel_capabilities.dart';
import '../domain/live_repository.dart';
import '../domain/media_source_type.dart';
import '../domain/program.dart';

/// Adaptador Jellyfin: mapea los DTO del servidor al dominio de FYNITIV LIVE.
class JellyfinLiveRepository implements LiveRepository {
  JellyfinLiveRepository({
    required this.client,
    required this.userId,
    this.serverUrl,
  });

  final JellyfinDart client;
  final String userId;
  final String? serverUrl;

  @override
  Future<List<Channel>> getChannels() async {
    final res = await client.getLiveTvApi().getLiveTvChannels(
          userId: userId,
          limit: 500,
          enableImages: true,
          enableUserData: true,
          addCurrentProgram: true,
          fields: [
            ItemFields.primaryImageAspectRatio,
            ItemFields.channelImage,
            ItemFields.isHD,
          ],
          enableImageTypes: [ImageType.primary],
        );
    return [
      for (final c in res.data?.items ?? const <BaseItemDto>[]) _mapChannel(c),
    ];
  }

  @override
  Future<List<Program>> getGuide({
    required DateTime start,
    required DateTime end,
  }) async {
    final res = await client.getLiveTvApi().getLiveTvPrograms(
          userId: userId,
          minStartDate: start,
          maxEndDate: end,
          enableImages: false,
          fields: [ItemFields.genres],
          enableTotalRecordCount: false,
        );
    return [
      for (final p in res.data?.items ?? const <BaseItemDto>[]) _mapProgram(p),
    ];
  }

  Channel _mapChannel(BaseItemDto c) => jellyfinChannelFromDto(c, serverUrl: serverUrl);

  Program _mapProgram(BaseItemDto p) => jellyfinProgramFromDto(p);
}

/// Mapea un canal de Jellyfin al dominio.
Channel jellyfinChannelFromDto(BaseItemDto c, {String? serverUrl}) {
  final tags = c.imageTags;
  String? logoUrl;
  if (serverUrl != null && tags != null && tags.isNotEmpty) {
    final tagPrimary = tags['Primary'];
    final tagChannel = tags['channelImage'];
    if (tagPrimary != null && tagPrimary.isNotEmpty) {
      logoUrl = '$serverUrl/Items/${c.id}/Images/Primary?maxWidth=160&tag=$tagPrimary';
    } else if (tagChannel != null && tagChannel.isNotEmpty) {
      logoUrl = '$serverUrl/Items/${c.id}/Images/channelImage?maxWidth=160&tag=$tagChannel';
    }
  }
  return Channel(
    id: c.id ?? '',
    name: c.name ?? '',
    number: c.channelNumber ?? c.number?.toString(),
    logoUrl: logoUrl,
    sourceType: MediaSourceType.jellyfin,
    sourceId: c.id ?? '',
    group: c.channelType?.value,
    genres: c.genres ?? const [],
    isFavorite: c.userData?.isFavorite ?? false,
    isHd: c.isHD ?? false,
    capabilities: const ChannelCapabilities(),
  );
}

/// Mapea un programa de la guía de Jellyfin al dominio (fechas en UTC).
Program jellyfinProgramFromDto(BaseItemDto p) {
  final end = p.endDate ?? p.startDate?.add(const Duration(hours: 1));
  final genres = p.genres ?? const <String>[];
  return Program(
    id: p.id ?? '',
    channelId: p.channelId ?? '',
    title: p.name ?? '',
    subtitle: p.episodeTitle ?? p.seriesName,
    description: p.overview,
    startTime: (p.startDate ?? DateTime.now()).toUtc(),
    endTime: (end ?? DateTime.now()).toUtc(),
    genre: genres.isNotEmpty ? genres.first : null,
    episodeNumber: p.indexNumber?.toString(),
    seasonNumber: p.parentIndexNumber?.toString(),
    sourceType: MediaSourceType.jellyfin,
    sourceId: p.id ?? '',
  );
}
