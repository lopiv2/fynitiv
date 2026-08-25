import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../auth/application/auth_controller.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../core/skin/home_scroll.dart';
import '../../../core/skin/music_player_skin.dart';

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
    fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
    enableImageTypes: [ImageType.primary, ImageType.backdrop, ImageType.thumb],
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
    fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
    enableImageTypes: [ImageType.primary, ImageType.thumb],
  );
  return res.data?.items ?? [];
});

/// Novedades para el carrusel de banners del home (estilo Disney+).
/// Máximo 10 items y con imágenes de fondo (backdrop) habilitadas.
final latestBannerItemsProvider = FutureProvider<List<BaseItemDto>>((
  ref,
) async {
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
    enableImageTypes: [ImageType.primary, ImageType.backdrop, ImageType.logo],
  );
  return res.data?.items ?? [];
});

/// Items de una vista/biblioteca concreta.
final libraryItemsProvider = FutureProvider.family<List<BaseItemDto>, String>((
  ref,
  viewId,
) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    parentId: viewId,
    recursive: true,
    sortBy: [ItemSortBy.sortName],
    limit: 20,
    fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
    enableImageTypes: [ImageType.primary, ImageType.thumb],
  );
  return res.data?.items ?? [];
});

/// VOD: películas y series a la carta (On Demand).
final vodItemsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: [BaseItemKind.movie, BaseItemKind.series],
    sortBy: [ItemSortBy.dateCreated],
    sortOrder: [SortOrder.descending],
    limit: 60,
    fields: [ItemFields.primaryImageAspectRatio],
    enableImageTypes: [ImageType.primary],
  );
  return res.data?.items ?? [];
});

/// Contenidos similares al item actual, para la fila de relacionados del
/// detalle Prime.
final similarItemsProvider =
    FutureProvider.family<List<BaseItemDto>, BaseItemDto>((ref, item) async {
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      final itemId = item.id ?? '';
      if (client == null || userId == null || itemId.isEmpty) return const [];
      try {
        final res = await client.getItemsApi().getItems(
          userId: userId,
          recursive: true,
          limit: 10,
          excludeItemIds: [itemId],
          genres: item.genres,
          includeItemTypes: item.type == BaseItemKind.movie
              ? [BaseItemKind.movie]
              : item.type == BaseItemKind.series
              ? [BaseItemKind.series]
              : null,
          fields: [
            ItemFields.overview,
            ItemFields.providerIds,
            ItemFields.primaryImageAspectRatio,
          ],
          enableImageTypes: [
            ImageType.primary,
            ImageType.thumb,
            ImageType.backdrop,
          ],
        );
        return (res.data?.items ?? const []).take(10).toList();
      } catch (_) {
        return const [];
      }
    });

/// Detalle completo de un item, incluidos reparto, estudio y pistas.
final itemDetailProvider = FutureProvider.family<BaseItemDto?, String>((
  ref,
  itemId,
) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null || itemId.isEmpty) return null;
  try {
    final res = await client.getUserLibraryApi().getItem(
      itemId: itemId,
      userId: userId,
    );
    return res.data;
  } catch (_) {
    return null;
  }
});

/// Novedades de VOD para el carrusel de banners (solo películas y series).
final vodLatestBannerProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: [BaseItemKind.movie, BaseItemKind.series],
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
    enableImageTypes: [ImageType.primary, ImageType.backdrop, ImageType.logo],
  );
  return res.data?.items ?? [];
});

/// "Continuar viendo" de VOD (solo películas y series).
final vodResumeProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getResumeItems(
    userId: userId,
    limit: 20,
    includeItemTypes: [BaseItemKind.movie, BaseItemKind.series],
    fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
    enableImageTypes: [ImageType.primary, ImageType.backdrop, ImageType.thumb],
  );
  return res.data?.items ?? [];
});

/// Novedades de VOD (fila "Novedades" cuando no hay banner).
final vodLatestProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: [BaseItemKind.movie, BaseItemKind.series],
    sortBy: [ItemSortBy.dateCreated],
    sortOrder: [SortOrder.descending],
    limit: 20,
    fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
    enableImageTypes: [ImageType.primary, ImageType.thumb],
  );
  return res.data?.items ?? [];
});

/// Vistas de la biblioteca de películas y series (para las filas de VOD).
final vodLibraryViewsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final views = await ref.watch(userViewsProvider.future);
  return views
      .where(
        (v) =>
            v.collectionType == CollectionType.movies ||
            v.collectionType == CollectionType.tvshows,
      )
      .toList();
});

/// Página de todas las películas del servidor, para la pantalla de "Ver más"
/// (grid con desplazamiento infinito). Cada página trae [kAllMoviesPageSize]
/// items empezando en [pageIndex] * página.
const int kAllMoviesPageSize = 50;

final allMoviesPageProvider = FutureProvider.family<List<BaseItemDto>, int>((
  ref,
  pageIndex,
) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: [BaseItemKind.movie],
    startIndex: pageIndex * kAllMoviesPageSize,
    limit: kAllMoviesPageSize,
    sortBy: [ItemSortBy.sortName],
    sortOrder: [SortOrder.ascending],
    fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
    enableImageTypes: [ImageType.primary, ImageType.thumb],
  );
  return res.data?.items ?? [];
});

/// Items de una fila de contenido configurada por el skin (filtrada por
/// géneros y tipos). Se usa para los scrolls extra definidos en cada preset.
final homeScrollItemsProvider =
    FutureProvider.family<List<BaseItemDto>, HomeScroll>((ref, scroll) async {
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      if (client == null || userId == null) return const [];
      final res = await client.getItemsApi().getItems(
        userId: userId,
        recursive: true,
        includeItemTypes: scroll.types,
        // Jellyfin espera los géneros separados por "|" en un único valor.
        genres: [scroll.genres.join('|')],
        sortBy: [ItemSortBy.dateCreated],
        sortOrder: [SortOrder.descending],
        limit: scroll.limit,
        fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
        enableImageTypes: [ImageType.primary, ImageType.thumb],
      );
      return res.data?.items ?? [];
    });

/// Álbumes de música de todas las bibliotecas.
final musicAlbumsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: [BaseItemKind.musicAlbum],
    sortBy: [ItemSortBy.sortName],
    sortOrder: [SortOrder.ascending],
    limit: 60,
    fields: [ItemFields.primaryImageAspectRatio],
    enableImageTypes: [ImageType.primary],
  );
  return res.data?.items ?? [];
});

/// Canciones (audio) de todas las bibliotecas.
final musicTracksProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: [BaseItemKind.audio],
    sortBy: [ItemSortBy.sortName],
    sortOrder: [SortOrder.ascending],
    limit: 100,
    fields: [ItemFields.primaryImageAspectRatio],
    enableImageTypes: [ImageType.primary],
  );
  return res.data?.items ?? [];
});

/// Más álbumes del mismo artista (para la vista detalle estilo Jellyfin).
final artistAlbumsProvider =
    FutureProvider.family<List<BaseItemDto>, BaseItemDto>((ref, album) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final albumId = album.id ?? '';
  final artist = (album.albumArtist?.trim().isNotEmpty == true
          ? album.albumArtist!.trim()
          : (album.artists?.firstOrNull?.trim() ?? ''))
      .trim();
  final artistId = album.albumArtists?.firstOrNull?.id;
  if (artist.isEmpty && (artistId == null || artistId.isEmpty)) return const [];
  try {
    final res = await client.getItemsApi().getItems(
      userId: userId,
      recursive: true,
      includeItemTypes: [BaseItemKind.musicAlbum],
      artists: artist.isNotEmpty ? [artist] : null,
      albumArtistIds: artistId != null && artistId.isNotEmpty ? [artistId] : null,
      excludeItemIds: albumId.isNotEmpty ? [albumId] : null,
      limit: 10,
      sortBy: [ItemSortBy.productionYear],
      sortOrder: [SortOrder.descending],
      fields: [ItemFields.primaryImageAspectRatio],
      enableImageTypes: [ImageType.primary],
    );
    var items = res.data?.items ?? const <BaseItemDto>[];
    // Fallback por si el filtro por artista no devolvió nada: búsqueda por término.
    if (items.isEmpty && artist.isNotEmpty) {
      final fallback = await client.getItemsApi().getItems(
        userId: userId,
        recursive: true,
        includeItemTypes: [BaseItemKind.musicAlbum],
        searchTerm: artist,
        excludeItemIds: albumId.isNotEmpty ? [albumId] : null,
        limit: 10,
        fields: [ItemFields.primaryImageAspectRatio],
        enableImageTypes: [ImageType.primary],
      );
      items = fallback.data?.items ?? const <BaseItemDto>[];
    }
    return items;
  } catch (_) {
    return const [];
  }
});

/// Trailer (id de YouTube) de un item usando la API pública de KinoCheck.
/// Requiere tmdb_id o imdb_id del item.
final kinocheckTrailerProvider = FutureProvider.family<String?, BaseItemDto>((
  ref,
  item,
) async {
  final dio = Dio()..options.headers = _kinoHeaders;
  final language = ref.watch(localeProvider).value?.languageCode ?? 'es';
  try {
    final providerIds = item.providerIds ?? const <String, String>{};
    String? providerId(String name) {
      for (final entry in providerIds.entries) {
        if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
      }
      return null;
    }

    final tmdbId = providerId('Tmdb');
    final imdbId = providerId('Imdb');
    debugPrint(
      '[KinoCheck] item=${item.id} tmdb=$tmdbId imdb=$imdbId language=$language',
    );
    Future<String?> requestTrailer(String parameter, String value) async {
      Future<String?> request(String requestedLanguage) async {
        final res = await dio.get(
          'https://api.kinocheck.de/movies',
          queryParameters: {parameter: value, 'language': requestedLanguage},
        );
        final trailerId = _kinocheckYoutubeId(
          res.data,
          preferredLanguage: requestedLanguage,
        );
        debugPrint(
          '[KinoCheck] $parameter=$value language=$requestedLanguage '
          'status=${res.statusCode} trailer=$trailerId',
        );
        return trailerId;
      }

      for (final requestedLanguage in <String>{language, 'en', 'de'}) {
        final trailer = await request(requestedLanguage);
        if (trailer != null) return trailer;
      }
      return null;
    }

    if (tmdbId != null && tmdbId.isNotEmpty) {
      final trailer = await requestTrailer('tmdb_id', tmdbId);
      if (trailer != null) return trailer;
    }
    if (imdbId != null && imdbId.isNotEmpty) {
      return await requestTrailer('imdb_id', imdbId);
    }
    return null;
  } catch (error) {
    debugPrint('[KinoCheck] request failed for item=${item.id}: $error');
    return null;
  }
});

const _kinoHeaders = <String, String>{
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
};

String? _kinocheckYoutubeId(dynamic data, {String? preferredLanguage}) {
  // Respuesta como lista de trailers directamente.
  if (data is List) {
    return _firstTrailerId(data, preferredLanguage: preferredLanguage);
  }
  if (data is! Map<String, dynamic>) return null;
  final videos = data['videos'];
  if (videos is List) {
    final localized = _firstTrailerId(
      videos,
      preferredLanguage: preferredLanguage,
      onlyPreferredLanguage: true,
    );
    if (localized != null) return localized;
  }
  // Trailer principal.
  final trailer = data['trailer'];
  if (trailer is Map<String, dynamic>) {
    final id = trailer['youtube_video_id'] ?? trailer['youtube_id'];
    final language = '${trailer['language'] ?? ''}'.toLowerCase();
    if (id is String &&
        id.isNotEmpty &&
        (preferredLanguage == null ||
            language.isEmpty ||
            language == preferredLanguage.toLowerCase())) {
      return id;
    }
  }
  // Videos relacionados que sean trailers.
  if (videos is List) {
    return _firstTrailerId(videos, preferredLanguage: preferredLanguage);
  }
  return null;
}

String? _firstTrailerId(
  List list, {
  String? preferredLanguage,
  bool onlyPreferredLanguage = false,
}) {
  String? findId(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    final id = value['youtube_video_id'] ?? value['youtube_id'];
    return id is String && id.isNotEmpty ? id : null;
  }

  // KinoCheck normally marks the selected videos with the Trailer category.
  for (final v in list) {
    if (v is Map<String, dynamic>) {
      final categories = v['categories'];
      final isTrailer =
          categories is List &&
          categories.any((c) => '$c'.toLowerCase() == 'trailer');
      final language = '${v['language'] ?? ''}'.toLowerCase();
      final isPreferred =
          preferredLanguage == null ||
          language == preferredLanguage.toLowerCase();
      if (isTrailer && isPreferred) return findId(v);
    }
  }
  // Compatibilidad con respuestas antiguas que no incluyen categorías.
  for (final v in list) {
    final categories = v is Map<String, dynamic> ? v['categories'] : null;
    final language = v is Map<String, dynamic>
        ? '${v['language'] ?? ''}'.toLowerCase()
        : '';
    final isPreferred =
        preferredLanguage == null ||
        language == preferredLanguage.toLowerCase();
    if (categories is! List && isPreferred) {
      final id = findId(v);
      if (id != null) return id;
    }
  }
  if (onlyPreferredLanguage) return null;
  // Último recurso: cualquier trailer disponible en la respuesta.
  for (final v in list) {
    if (v is Map<String, dynamic>) {
      final categories = v['categories'];
      final isTrailer =
          categories is List &&
          categories.any((c) => '$c'.toLowerCase() == 'trailer');
      if (isTrailer) return findId(v);
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
  } catch (error) {
    debugPrint('[KinoCheck] YouTube stream failed for id=$youtubeId: $error');
    return null;
  }
}

/// Items de una fila del music player configurada por el skin de música.
final musicScrollItemsProvider =
    FutureProvider.family<List<BaseItemDto>, MusicScroll>((ref, scroll) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  // Map string types to BaseItemKind where possible.
  final kinds = scroll.includeItemTypes
      .map((e) => BaseItemKind.values.asNameMap()[e])
      .whereType<BaseItemKind>()
      .toList();
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: kinds.isEmpty ? null : kinds,
    genres: scroll.genres.isEmpty ? null : [scroll.genres.join('|')],
    sortBy: [ItemSortBy.dateCreated],
    sortOrder: [SortOrder.descending],
    limit: scroll.limit,
    fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
    enableImageTypes: [ImageType.primary, ImageType.thumb],
  );
  return res.data?.items ?? [];
});

/// Spotify: canciones en tendencia (audio recientes / más reproducidas).
final spotifyTrendingSongsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  try {
    final res = await client.getItemsApi().getItems(
      userId: userId,
      recursive: true,
      includeItemTypes: [BaseItemKind.audio],
      sortBy: [ItemSortBy.dateCreated],
      sortOrder: [SortOrder.descending],
      limit: 20,
      fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview, ItemFields.genres],
      enableImageTypes: [ImageType.primary, ImageType.thumb],
    );
    return res.data?.items ?? [];
  } catch (_) {
    return const [];
  }
});

/// Spotify: artistas populares (MusicArtist) - trendy local server-side.
/// Orden: PlayCount desc → DatePlayed desc. Sin Random, solo server-side via ArtistsApi.
final spotifyPopularArtistsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];

  Future<List<BaseItemDto>> fetchBySort(List<ItemSortBy> sortBy) async {
    final res = await client.getArtistsApi().getAlbumArtists(
          userId: userId,
          sortBy: sortBy,
          sortOrder: [SortOrder.descending],
          limit: 20,
          fields: [ItemFields.primaryImageAspectRatio],
          enableUserData: true,
          enableImageTypes: [ImageType.primary, ImageType.thumb],
        );
    return res.data?.items ?? const <BaseItemDto>[];
  }

  try {
    // 1) Más reproducidos (PlayCount)
    var items = await fetchBySort([ItemSortBy.playCount]);
    // Filtra artistas sin playCount si todos son 0 → prueba DatePlayed
    final hasPlays = items.any((a) => (a.userData?.playCount ?? 0) > 0);
    if (items.isEmpty || !hasPlays) {
      final byDatePlayed = await fetchBySort([ItemSortBy.datePlayed]);
      if (byDatePlayed.isNotEmpty) items = byDatePlayed;
    }
    if (items.isNotEmpty) return items;

    // Fallback server-side agregación local: suma PlayCount por artista desde audio
    final tracksRes = await client.getItemsApi().getItems(
          userId: userId,
          recursive: true,
          includeItemTypes: [BaseItemKind.audio],
          limit: 200,
          fields: [ItemFields.primaryImageAspectRatio],
          enableUserData: true,
          enableImageTypes: [ImageType.primary],
        );
    final tracks = tracksRes.data?.items ?? const <BaseItemDto>[];
    if (tracks.isNotEmpty) {
      final playByArtist = <String, int>{};
      final sampleByArtist = <String, BaseItemDto>{};
      for (final t in tracks) {
        final name = t.artists?.firstOrNull ?? t.albumArtists?.firstOrNull?.name ?? '';
        if (name.isEmpty) continue;
        final pc = t.userData?.playCount ?? 0;
        playByArtist[name] = (playByArtist[name] ?? 0) + pc;
        sampleByArtist.putIfAbsent(name, () => t);
      }
      if (playByArtist.isNotEmpty) {
        final sorted = playByArtist.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        // Si todo 0, ordena por aparición (mantiene trendy local sin random)
        return sorted.take(20).map((e) {
          final sample = sampleByArtist[e.key];
          // Intenta resolver id de artista si existe en la lista previa de ArtistsApi
          return BaseItemDto(
            id: sample?.albumArtists?.firstOrNull?.id ?? sample?.id,
            name: e.key,
            type: BaseItemKind.musicArtist,
            userData: UserItemDataDto(playCount: e.value),
          );
        }).toList();
      }
    }
    // Último fallback: artistas únicos en orden de aparición (no A-Z)
    final tracksFallback = await ref.watch(musicTracksProvider.future);
    final seen = <String>{};
    final artists = <BaseItemDto>[];
    for (final t in tracksFallback) {
      final name = t.artists?.firstOrNull ?? t.albumArtists?.firstOrNull?.name ?? '';
      if (name.isEmpty || seen.contains(name)) continue;
      seen.add(name);
      artists.add(BaseItemDto(name: name, type: BaseItemKind.musicArtist));
      if (artists.length >= 12) break;
    }
    return artists;
  } catch (_) {
    return const [];
  }
});

/// Jellyfin: mis playlists (tipo Playlist) del usuario.
/// Son listas de reproducción (música), no bibliotecas de películas.
/// Filtra por MediaType.audio y verifica que realmente sean de audio.
final jellyfinPlaylistsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  try {
    final res = await client.getItemsApi().getItems(
          userId: userId,
          recursive: true,
          includeItemTypes: [BaseItemKind.playlist],
          mediaTypes: [MediaType.audio],
          sortBy: [ItemSortBy.dateCreated],
          sortOrder: [SortOrder.descending],
          limit: 20,
          fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
          enableImageTypes: [ImageType.primary, ImageType.thumb],
          enableUserData: true,
        );
    var items = res.data?.items ?? const <BaseItemDto>[];
    // Si el filtro por MediaType.audio no devuelve nada (algunos servidores no lo indexan),
    // fallback sin mediaTypes y filtra en cliente por mediaType == audio si existe.
    if (items.isEmpty) {
      final fallback = await client.getItemsApi().getItems(
            userId: userId,
            recursive: true,
            includeItemTypes: [BaseItemKind.playlist],
            sortBy: [ItemSortBy.dateCreated],
            sortOrder: [SortOrder.descending],
            limit: 20,
            fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
            enableImageTypes: [ImageType.primary, ImageType.thumb],
            enableUserData: true,
          );
      final all = fallback.data?.items ?? const <BaseItemDto>[];
      // Si el servidor devuelve playlists sin mediaType, no filtramos y mostramos todas,
      // pero priorizamos las que sean de audio si se puede detectar.
      final audioOnly = all.where((e) => e.mediaType == MediaType.audio).toList();
      items = audioOnly.isNotEmpty ? audioOnly : all;
    }
    return items;
  } catch (_) {
    return const [];
  }
});

/// Jellyfin: elementos recién añadidos (música) - últimos álbumes creados.
final jellyfinRecentlyAddedMusicProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  try {
    final res = await client.getItemsApi().getItems(
          userId: userId,
          recursive: true,
          includeItemTypes: [BaseItemKind.musicAlbum, BaseItemKind.audio],
          sortBy: [ItemSortBy.dateCreated],
          sortOrder: [SortOrder.descending],
          limit: 20,
          fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview, ItemFields.dateCreated],
          enableImageTypes: [ImageType.primary, ImageType.thumb],
          enableUserData: true,
        );
    return res.data?.items ?? const [];
  } catch (_) {
    return const [];
  }
});

/// Obtiene una URL de vídeo reproducible del trailer de un item desde KinoCheck.
/// Así se evita reproducir accidentalmente el video principal desde
/// RemoteTrailers cuando el servidor devuelve una URL incorrecta.
final trailerStreamProvider = FutureProvider.family<String?, BaseItemDto>((
  ref,
  item,
) async {
  final youtubeId = await ref.read(kinocheckTrailerProvider(item).future);
  if (youtubeId != null) {
    final direct = await _resolveYoutubeStream(youtubeId);
    if (direct != null) return direct;
  }
  return null;
});
