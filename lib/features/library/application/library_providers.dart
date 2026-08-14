import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../auth/application/auth_controller.dart';

/// userId del usuario autenticado actual.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).userId,
);

/// URL del servidor configurado.
final authServerUrlProvider = Provider<String?>(
  (ref) => ref.watch(authControllerProvider).serverUrl,
);

/// Cliente Jellyfin con token del usuario autenticado.
final jellyfinClientProvider = Provider<JellyfinDart?>(
  (ref) => ref.watch(authControllerProvider.notifier).client,
);

/// Lista de vistas (bibliotecas) del usuario: Películas, Series, etc.
final userViewsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getUserViewsApi().getUserViews(userId: userId);
  return res.data?.items ?? [];
});

/// Items "Continuar viendo".
final resumeItemsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getResumeItems(
        userId: userId,
        limit: 20,
        fields: [ItemFields.primaryImageAspectRatio],
        enableImageTypes: [ImageType.primary, ImageType.backdrop],
      );
  return res.data?.items ?? [];
});

/// Items recientes (Novedades).
final latestItemsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
        userId: userId,
        recursive: true,
        sortBy: [ItemSortBy.dateCreated],
        sortOrder: [SortOrder.descending],
        limit: 20,
        fields: [ItemFields.primaryImageAspectRatio],
        enableImageTypes: [ImageType.primary],
      );
  return res.data?.items ?? [];
});

/// Novedades para el carrusel de banners del home (estilo Disney+).
/// Máximo 10 items y con imágenes de fondo (backdrop) habilitadas.
final latestBannerItemsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
        userId: userId,
        recursive: true,
        sortBy: [ItemSortBy.dateCreated],
        sortOrder: [SortOrder.descending],
        limit: 10,
        fields: [
          ItemFields.dateCreated,
          ItemFields.genres,
          ItemFields.overview,
          ItemFields.primaryImageAspectRatio,
          ItemFields.providerIds,
        ],
        enableImageTypes: [
          ImageType.primary,
          ImageType.backdrop,
          ImageType.logo,
        ],
      );
  return res.data?.items ?? [];
});

/// Items de una vista/biblioteca concreta.
final libraryItemsProvider =
    FutureProvider.family<List<BaseItemDto>, String>((ref, viewId) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
        userId: userId,
        parentId: viewId,
        recursive: true,
        sortBy: [ItemSortBy.sortName],
        limit: 20,
        fields: [ItemFields.primaryImageAspectRatio],
        enableImageTypes: [ImageType.primary],
      );
  return res.data?.items ?? [];
});

/// Trailer (id de YouTube) de un item usando la API pública de KinoCheck.
/// Requiere tmdb_id o imdb_id del item.
final kinocheckTrailerProvider =
    FutureProvider.family<String?, BaseItemDto>((ref, item) async {
  final dio = Dio()..options.headers = _kinoHeaders;
  try {
    final tmdbId = item.providerIds?['Tmdb'];
    final imdbId = item.providerIds?['Imdb'];
    if (tmdbId != null && tmdbId.isNotEmpty) {
      final res = await dio.get(
        'https://api.kinocheck.de/movies',
        queryParameters: {'tmdb_id': tmdbId},
      );
      final trailer = _kinocheckYoutubeId(res.data);
      if (trailer != null) return trailer;
    }
    if (imdbId != null && imdbId.isNotEmpty) {
      final res = await dio.get(
        'https://api.kinocheck.de/movies',
        queryParameters: {'imdb_id': imdbId},
      );
      return _kinocheckYoutubeId(res.data);
    }
    return null;
  } catch (_) {
    return null;
  }
});

const _kinoHeaders = <String, String>{
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
};

String? _kinocheckYoutubeId(dynamic data) {
  // Respuesta como lista de trailers directamente.
  if (data is List) return _firstTrailerId(data);
  if (data is! Map<String, dynamic>) return null;
  // Trailer principal.
  final trailer = data['trailer'];
  if (trailer is Map<String, dynamic>) {
    final id = trailer['youtube_id'];
    if (id is String && id.isNotEmpty) return id;
  }
  // Videos relacionados que sean trailers.
  final videos = data['videos'];
  if (videos is List) return _firstTrailerId(videos);
  return null;
}

String? _firstTrailerId(List list) {
  for (final v in list) {
    if (v is Map<String, dynamic>) {
      final categories = v['categories'];
      final isTrailer = categories is List &&
          categories.any((c) => '$c'.toLowerCase().contains('trailer'));
      // Si no declara categorías, se asume que es un trailer.
      if (isTrailer || categories is! List) {
        final id = v['youtube_video_id'] ?? v['youtube_id'];
        if (id is String && id.isNotEmpty) return id;
      }
    }
  }
  return null;
}

/// Resuelve una URL directa de vídeo (mp4) del trailer de YouTube para poder
/// reproducirlo con video_player (sin webview ni iframe).
Future<String?> _resolveYoutubeStream(String youtubeId) async {
  try {
    final yt = YoutubeExplode();
    final manifest = await yt.videos.streamsClient.getManifest(youtubeId);
    final muxed = manifest.muxed;
    if (muxed.isNotEmpty) return muxed.first.url.toString();
    return null;
  } catch (_) {
    return null;
  }
}

bool _isYouTubeUrl(String url) {
  final u = url.toLowerCase();
  return u.contains('youtube.com') ||
      u.contains('youtu.be') ||
      u.contains('/embed/');
}

String? _youtubeIdFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.host.contains('youtu.be')) {
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    return seg.isEmpty ? null : seg;
  }
  final v = uri.queryParameters['v'];
  if (v != null && v.isNotEmpty) return v;
  final segs = uri.pathSegments;
  if (segs.isNotEmpty && segs.first == 'embed' && segs.length > 1) {
    return segs[1];
  }
  return null;
}

/// Obtiene una URL de vídeo reproducible del trailer de un item.
/// Prioriza los trailers remotos de Jellyfin (Power Toys); si el trailer es de
/// YouTube se extrae la URL directa. Como respaldo usa KinoCheck.
final trailerStreamProvider =
    FutureProvider.family<String?, BaseItemDto>((ref, item) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);

  // 1) Trailers remotos de Jellyfin (del item o de su detalle).
  String? remote = item.remoteTrailers
      ?.where((t) => (t.url ?? '').isNotEmpty)
      .firstOrNull
      ?.url;
  if ((remote ?? '').isEmpty &&
      client != null &&
      userId != null &&
      (item.id ?? '').isNotEmpty) {
    try {
      final detail = await client
          .getUserLibraryApi()
          .getItem(itemId: item.id!, userId: userId);
      remote = detail.data?.remoteTrailers
          ?.where((t) => (t.url ?? '').isNotEmpty)
          .firstOrNull
          ?.url;
    } catch (_) {}
  }
  if (remote != null && remote.isNotEmpty) {
    // URL directa (p. ej. vídeo servido por Jellyfin).
    if (!_isYouTubeUrl(remote)) return remote;
    final youtubeId = _youtubeIdFromUrl(remote);
    if (youtubeId != null) {
      final direct = await _resolveYoutubeStream(youtubeId);
      if (direct != null) return direct;
    }
  }

  // 2) Respaldo: KinoCheck (tmdb/imdb).
  final youtubeId = await ref.read(kinocheckTrailerProvider(item).future);
  if (youtubeId != null) {
    final direct = await _resolveYoutubeStream(youtubeId);
    if (direct != null) return direct;
  }
  return null;
});
