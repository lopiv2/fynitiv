import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:media_kit/media_kit.dart';

import '../../auth/application/auth_controller.dart';
import '../../../core/di/providers.dart';
import '../../library/application/library_providers.dart'
    hide jellyfinClientProvider;

/// Sesión de reproducción resuelta para un item: datos necesarios para abrir
/// el stream con media_kit (URL directa o HLS) y sus pistas.
class PlaybackSession {
  const PlaybackSession({
    required this.itemId,
    required this.itemName,
    required this.serverUrl,
    required this.streamUrl,
    this.mediaSource,
    this.externalSubtitles = const [],
    this.start,
  });

  final String itemId;
  final String itemName;
  final String serverUrl;
  final String streamUrl;
  final MediaSourceInfo? mediaSource;

  /// Subtítulos externos (ficheros .srt/.vtt servidos por Jellyfin).
  final List<SubtitleTrack> externalSubtitles;

  /// Posición de reanudación (Continuar viendo), si existe.
  final Duration? start;
}

/// Convierte ticks de Jellyfin (100ns) a [Duration]. Devuelve null si no hay
/// posición válida (0 → null para no saltar).
Duration? durationFromTicks(int? ticks) {
  if (ticks == null || ticks <= 0) return null;
  return Duration(microseconds: ticks ~/ 10);
}

Duration? _durationFromTicks(int? ticks) => durationFromTicks(ticks);

/// Resuelve la información de reproducción de un item y construye la URL
/// directa del stream (direct play) o HLS (transcode) para media_kit.
///
/// `isAutoDispose`: se refetcha en cada apertura del reproductor, para que la
/// lista de pistas (subtítulos externos añadidos en el servidor después de la
/// primera reproducción) no quede congelada por la caché del provider.
final playbackSessionProvider = FutureProvider.family<PlaybackSession?, String>((
  ref,
  itemId,
) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  final serverUrl = ref.watch(authServerUrlProvider);
  if (client == null || userId == null || serverUrl == null || itemId.isEmpty) {
    return null;
  }

  final info = await client
      .getMediaInfoApi()
      .getPlaybackInfo(itemId: itemId, userId: userId);
  final source = info.data?.mediaSources?.firstOrNull;
  if (source == null || source.id == null) return null;

  final token = await ref.read(sessionStorageProvider).readToken();
  final tokenValue = token ?? '';
  final apiKey = tokenValue.isEmpty ? '' : '&api_key=$tokenValue';

  // Nombre del item y posición de reanudación para la cabecera del player.
  var itemName = '';
  Duration? start;
  try {
    final detail = await client
        .getUserLibraryApi()
        .getItem(itemId: itemId, userId: userId);
    itemName = detail.data?.name ?? '';
    start = _durationFromTicks(detail.data?.userData?.playbackPositionTicks);
  } catch (_) {
    // No crítico: nombre y reanudación quedan vacíos.
  }

  final directPlay = source.supportsDirectPlay != false;
  final String streamUrl;
  if (directPlay) {
    streamUrl =
        '$serverUrl/Videos/$itemId/stream?static=true&MediaSourceId=${source.id}$apiKey';
  } else {
    // HLS: el servidor transcodifica lo que el cliente no soporta.
    // Incluir PlaySessionId si existe (requerido por el servidor para HLS).
    final sessionId = info.data?.playSessionId;
    final sessionParam =
        (sessionId != null && sessionId.isNotEmpty) ? '&PlaySessionId=$sessionId' : '';
    streamUrl =
        '$serverUrl/Videos/$itemId/master.m3u8?MediaSourceId=${source.id}$sessionParam$apiKey';
  }

  // Subtítulos servidos por Jellyfin (ficheros externos y extraídos del
  // contenedor). El GET PlaybackInfo puede omitir `DeliveryUrl`, así que se
  // construye la URL a partir del índice del stream cuando falta.
  final externalSubtitles = <SubtitleTrack>[];
  for (final stream in source.mediaStreams ?? const <MediaStream>[]) {
    if (stream.type != MediaStreamType.subtitle) continue;
    final url = _subtitleStreamUrl(
      serverUrl: serverUrl,
      itemId: itemId,
      mediaSourceId: source.id!,
      stream: stream,
      token: tokenValue,
    );
    if (url == null) continue;
    externalSubtitles.add(
      SubtitleTrack.uri(
        url,
        title: stream.displayTitle ?? stream.title,
        language: stream.language,
      ),
    );
  }

  return PlaybackSession(
    itemId: itemId,
    itemName: itemName,
    serverUrl: serverUrl,
    streamUrl: streamUrl,
    mediaSource: source,
    externalSubtitles: externalSubtitles,
    start: start,
  );
}, isAutoDispose: true);

/// URL de un subtítulo servido por Jellyfin. Usa `DeliveryUrl` si viene; si no
/// (el GET PlaybackInfo puede omitirlo), lo construye con el índice del stream
/// para subtítulos externos (ficheros aparte como los descargados).
String? _subtitleStreamUrl({
  required String serverUrl,
  required String itemId,
  required String mediaSourceId,
  required MediaStream stream,
  required String token,
}) {
  final delivery = stream.deliveryUrl;
  if (delivery != null && delivery.isNotEmpty) {
    final sep = delivery.contains('?') ? '&' : '?';
    return token.isEmpty
        ? '$serverUrl$delivery'
        : '$serverUrl$delivery${sep}api_key=$token';
  }
  final index = stream.index;
  if (index == null || stream.isExternal != true) return null;
  final format = _subtitleFormat(stream.codec);
  final query = token.isEmpty ? '' : '?api_key=$token';
  return '$serverUrl/Videos/$itemId/$mediaSourceId/Subtitles/$index/Stream.$format$query';
}

/// Formato que espera la ruta `.../Subtitles/{index}/Stream.{format}` de
/// Jellyfin a partir del códec del stream (acepta srt/ass/ssa/vtt).
String _subtitleFormat(String? codec) {
  switch (codec?.toLowerCase()) {
    case 'ass':
      return 'ass';
    case 'ssa':
      return 'ssa';
    case 'webvtt':
    case 'vtt':
      return 'vtt';
    default:
      return 'srt';
  }
}
