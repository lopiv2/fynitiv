import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../auth/application/auth_controller.dart';
import '../../../core/i18n/locale_provider.dart';
import '../../../core/skin/home_scroll.dart';
import '../../../core/skin/music_player_skin.dart';

/// Mantiene el provider vivo 5 min tras la última escucha para que al
/// volver a la pantalla no se refetchee la API ni se recarguen imágenes.
extension _CacheExtension on Ref {
  void cacheFor(Duration d) {
    final link = keepAlive();
    Timer(d, link.close);
  }
}

const _kLibraryCache = Duration(minutes: 5);

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

String _transliterateSimple(String s) {
  const map = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'å': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };
  var out = s;
  map.forEach((k, v) {
    out = out.replaceAll(k, v);
    out = out.replaceAll(k.toUpperCase(), v);
  });
  return out;
}

String _normalizeArtist(String s) {
  var n = _transliterateSimple(s.toLowerCase()).trim();
  // Quita prefijo "the " para comparar "The Beatles" <-> "Beatles"
  if (n.startsWith('the ')) n = n.substring(4);
  // Normaliza separadores comunes de featuring
  n = n.replaceAll(RegExp(r'\s+feat\.?\s+'), ',');
  n = n.replaceAll(RegExp(r'\s+ft\.?\s+'), ',');
  n = n.replaceAll(RegExp(r'\s+x\s+'), ',');
  n = n.replaceAll(RegExp(r'\s+&\s+'), ',');
  return n;
}

List<String> _artistTokens(String s) {
  return s
      .split(RegExp(r'[;,/]'))
      .expand((p) => p.split(RegExp(r'\s+')))
      .map((t) => t.trim())
      .where((t) => t.length >= 3)
      .toList();
}

bool _artistMatches(BaseItemDto e, String lowerName) {
  final targetNorm = _normalizeArtist(lowerName);
  final targetTokens = _artistTokens(targetNorm);
  bool matches(String? s) {
    if (s == null || s.isEmpty) return false;
    final norm = _normalizeArtist(s);
    // 1) Contención directa en ambas direcciones
    if (norm.contains(targetNorm) || targetNorm.contains(norm)) return true;
    // 2) Cualquier parte separada por , ; / contiene
    for (final part in norm.split(RegExp(r'[;,/]'))) {
      final p = part.trim();
      if (p.isEmpty) continue;
      if (p.contains(targetNorm) || targetNorm.contains(p)) return true;
    }
    // 3) Solapamiento de tokens significativos (>=3 letras)
    final sTokens = _artistTokens(norm);
    for (final t in targetTokens) {
      if (sTokens.contains(t)) return true;
    }
    for (final t in sTokens) {
      if (targetTokens.contains(t)) return true;
    }
    return false;
  }

  return (e.artists?.any(matches) ?? false) ||
      matches(e.albumArtist) ||
      (e.albumArtists?.any((aa) => matches(aa.name)) ?? false);
}

/// Lista de vistas (bibliotecas) del usuario: Películas, Series, etc.
final userViewsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  ref.cacheFor(_kLibraryCache);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getUserViewsApi().getUserViews(userId: userId);
  return res.data?.items ?? [];
});

/// Items "Continuar viendo".
final resumeItemsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  ref.cacheFor(_kLibraryCache);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getResumeItems(
    userId: userId,
    limit: 20,
    fields: [
      ItemFields.primaryImageAspectRatio,
      ItemFields.overview,
      ItemFields.genres,
    ],
    enableImageTypes: [
      ImageType.primary,
      ImageType.backdrop,
      ImageType.thumb,
      ImageType.logo,
    ],
  );
  return res.data?.items ?? [];
});

/// Siguiente episodio para series (Shows/NextUp) – fila bajo Continuar viendo, solo series.
final nextUpEpisodesProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  ref.cacheFor(_kLibraryCache);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  try {
    final res = await client.getTvShowsApi().getNextUp(
      userId: userId,
      limit: 20,
      fields: [
        ItemFields.primaryImageAspectRatio,
        ItemFields.overview,
        ItemFields.people,
        ItemFields.providerIds,
        ItemFields.genres,
      ],
      enableImageTypes: [
        ImageType.primary,
        ImageType.thumb,
        ImageType.backdrop,
        ImageType.logo,
      ],
      enableUserData: true,
      enableResumable: false,
      enableRewatching: false,
    );
    final items = res.data?.items ?? [];
    // Solo siguientes capítulos de series sin progreso (no resumables)
    // – excluye episodios/películas a medio ver que ya están en "Continuar viendo".
    return items.where((e) {
      if (e.type != BaseItemKind.episode) return false;
      final pct = e.userData?.playedPercentage ?? 0;
      final ticks = e.userData?.playbackPositionTicks ?? 0;
      return pct <= 0 && ticks <= 0;
    }).toList();
  } catch (_) {
    return const [];
  }
});

/// Items recientes (Novedades).
final latestItemsProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  ref.cacheFor(_kLibraryCache);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    sortBy: [ItemSortBy.dateCreated],
    sortOrder: [SortOrder.descending],
    limit: 20,
    fields: [
      ItemFields.primaryImageAspectRatio,
      ItemFields.overview,
      ItemFields.people,
      ItemFields.genres,
    ],
    enableImageTypes: [ImageType.primary, ImageType.thumb, ImageType.logo],
  );
  return res.data?.items ?? [];
});

/// Novedades para el carrusel de banners del home (estilo Disney+).
/// Máximo 10 items y con imágenes de fondo (backdrop) habilitadas.
final latestBannerItemsProvider = FutureProvider<List<BaseItemDto>>((
  ref,
) async {
  ref.cacheFor(_kLibraryCache);
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
      ItemFields.people,
    ],
    enableImageTypes: [ImageType.primary, ImageType.backdrop, ImageType.logo],
  );
  return res.data?.items ?? [];
});

/// Mapeo compartido de [HomeScrollSort] a orden de la API de Jellyfin.
/// Devuelve (sortBy, sortOrder) con SortName secundario para orden estable.
(List<ItemSortBy>, List<SortOrder>) homeScrollSortParams(HomeScrollSort sort) {
  final primary = switch (sort) {
    HomeScrollSort.alphabetical => ItemSortBy.sortName,
    HomeScrollSort.recent => ItemSortBy.premiereDate,
    HomeScrollSort.rating => ItemSortBy.communityRating,
    HomeScrollSort.added => ItemSortBy.dateCreated,
    HomeScrollSort.random => ItemSortBy.random,
  };
  final primaryOrder = switch (sort) {
    HomeScrollSort.alphabetical => SortOrder.ascending,
    HomeScrollSort.recent => SortOrder.descending,
    HomeScrollSort.rating => SortOrder.descending,
    HomeScrollSort.added => SortOrder.descending,
    HomeScrollSort.random => SortOrder.ascending,
  };
  if (primary == ItemSortBy.sortName) {
    return ([ItemSortBy.sortName], [SortOrder.ascending]);
  }
  return ([primary, ItemSortBy.sortName], [primaryOrder, SortOrder.ascending]);
}

/// Resuelve el item de la SERIE para navegar a su detalle desde filas de
/// biblioteca de Series: episodios y temporadas redirigen a la serie (los
/// capítulos se eligen en el detalle o en Continuar viendo). Si ya es una
/// serie (o no trae seriesId), devuelve el propio item.
BaseItemDto seriesDetailTarget(BaseItemDto item) {
  if (item.type == BaseItemKind.series) return item;
  final seriesId = item.seriesId;
  if (seriesId == null || seriesId.isEmpty) return item;
  return BaseItemDto(
    id: seriesId,
    name: item.seriesName,
    type: BaseItemKind.series,
  );
}

/// Colapsa una serie a un solo elemento en filas (scrolls).
/// Las bibliotecas de Series devuelven mezclados episodios, temporadas y la
/// propia serie (ej. "Linternas" como S1:E3, "Temporada 1" y "Linternas").
/// Conserva solo el primer elemento de cada grupo (el más relevante según el
/// orden pedido) para que salgan varias series y no varias tarjetas de la
/// misma. Películas, música, etc. pasan intactos.
/// Agrupa por seriesId/id y por título normalizado a la vez, para que un
/// episodio (seriesId) colapse con su serie y temporada aunque vengan con
/// campos distintos.
List<BaseItemDto> collapseSeriesDuplicates(List<BaseItemDto> items) {
  var hasSerial = false;
  for (final e in items) {
    if (e.type == BaseItemKind.episode ||
        e.type == BaseItemKind.season ||
        e.type == BaseItemKind.series) {
      hasSerial = true;
      break;
    }
  }
  if (!hasSerial) return items;
  final seen = <String>{};
  final out = <BaseItemDto>[];
  for (final e in items) {
    final keys = _seriesGroupKeys(e);
    if (keys.isEmpty) {
      out.add(e);
      continue;
    }
    if (keys.any(seen.contains)) continue;
    seen.addAll(keys);
    out.add(e);
  }
  return out;
}

/// Claves de agrupación de un item con su serie (vacío si no es
/// episodio/temporada/serie o no trae ningún identificador).
Set<String> _seriesGroupKeys(BaseItemDto e) {
  final keys = <String>{};
  switch (e.type) {
    case BaseItemKind.episode:
    case BaseItemKind.season:
      final id = (e.seriesId ?? '').trim();
      if (id.isNotEmpty) keys.add('id:$id');
      final title = (e.seriesName ?? '').trim().toLowerCase();
      if (title.isNotEmpty) keys.add('t:$title');
    case BaseItemKind.series:
      final id = (e.id ?? '').trim();
      if (id.isNotEmpty) keys.add('id:$id');
      final title = (e.name ?? '').trim().toLowerCase();
      if (title.isNotEmpty) keys.add('t:$title');
    default:
      break;
  }
  return keys;
}

/// Items de una vista/biblioteca concreta.
final libraryItemsProvider = FutureProvider.family<List<BaseItemDto>, String>((
  ref,
  viewId,
) async {
  ref.cacheFor(_kLibraryCache);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    parentId: viewId,
    recursive: true,
    sortBy: [ItemSortBy.sortName],
    limit: 20,
    fields: [
      ItemFields.primaryImageAspectRatio,
      ItemFields.overview,
      ItemFields.people,
      ItemFields.genres,
    ],
    enableImageTypes: [
      ImageType.primary,
      ImageType.thumb,
      ImageType.backdrop,
      ImageType.logo,
    ],
  );
  return collapseSeriesDuplicates(res.data?.items ?? []);
});

/// Items de una biblioteca con orden configurable por [HomeScrollSort].
/// Clave: (viewId, sort). Usado por las filas `library`/`recent` con scroll
/// para que el enum `sort` funcione también fuera de los `custom`.
final libraryRowItemsProvider =
    FutureProvider.family<List<BaseItemDto>, (String, HomeScrollSort)>((
      ref,
      args,
    ) async {
      if (args.$2 != HomeScrollSort.random) ref.cacheFor(_kLibraryCache);
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      final viewId = args.$1;
      if (client == null || userId == null) return const [];
      final (sortBy, sortOrder) = homeScrollSortParams(args.$2);
      final res = await client.getItemsApi().getItems(
        userId: userId,
        parentId: viewId,
        recursive: true,
        sortBy: sortBy,
        sortOrder: sortOrder,
        limit: 20,
        fields: [
          ItemFields.primaryImageAspectRatio,
          ItemFields.overview,
          ItemFields.people,
          ItemFields.genres,
        ],
        enableImageTypes: [
          ImageType.primary,
          ImageType.thumb,
          ImageType.backdrop,
          ImageType.logo,
        ],
      );
      return collapseSeriesDuplicates(res.data?.items ?? []);
    });

/// Items recientes de una biblioteca concreta (para "Reciente en ...").
/// Ordenados por fecha de creación descendente, solo si la biblioteca existe.
final recentLibraryItemsProvider =
    FutureProvider.family<List<BaseItemDto>, String>((ref, viewId) async {
      ref.cacheFor(_kLibraryCache);
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      if (client == null || userId == null || viewId.isEmpty) return const [];
      final res = await client.getItemsApi().getItems(
        userId: userId,
        parentId: viewId,
        recursive: true,
        sortBy: [ItemSortBy.dateCreated],
        sortOrder: [SortOrder.descending],
        limit: 20,
        fields: [
          ItemFields.primaryImageAspectRatio,
          ItemFields.overview,
          ItemFields.people,
          ItemFields.dateCreated,
          ItemFields.genres,
        ],
        enableImageTypes: [
      ImageType.primary,
      ImageType.thumb,
      ImageType.backdrop,
      ImageType.logo,
    ],
      );
      // Una tarjeta por serie: solo el capítulo más reciente de cada título.
      return collapseSeriesDuplicates(res.data?.items ?? []);
    });

/// Items recientes de una biblioteca con orden configurable por scroll.
/// Igual que [recentLibraryItemsProvider] pero respeta [HomeScrollSort].
/// Clave: (viewId, sort).
final recentRowItemsProvider =
    FutureProvider.family<List<BaseItemDto>, (String, HomeScrollSort)>((
      ref,
      args,
    ) async {
      if (args.$2 != HomeScrollSort.random) ref.cacheFor(_kLibraryCache);
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      final viewId = args.$1;
      if (client == null || userId == null || viewId.isEmpty) return const [];
      final (sortBy, sortOrder) = homeScrollSortParams(args.$2);
      final res = await client.getItemsApi().getItems(
        userId: userId,
        parentId: viewId,
        recursive: true,
        sortBy: sortBy,
        sortOrder: sortOrder,
        limit: 20,
        fields: [
          ItemFields.primaryImageAspectRatio,
          ItemFields.overview,
          ItemFields.people,
          ItemFields.dateCreated,
          ItemFields.genres,
        ],
        enableImageTypes: [
      ImageType.primary,
      ImageType.thumb,
      ImageType.backdrop,
      ImageType.logo,
    ],
      );
      return collapseSeriesDuplicates(res.data?.items ?? []);
    });

/// Temporadas de una serie, ordenadas por nombre.
final seriesSeasonsProvider =
    FutureProvider.family<List<BaseItemDto>, String>((ref, seriesId) async {
  ref.cacheFor(_kLibraryCache);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null || seriesId.isEmpty) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    parentId: seriesId,
    recursive: true,
    includeItemTypes: [BaseItemKind.season],
    sortBy: [ItemSortBy.sortName],
    sortOrder: [SortOrder.ascending],
    fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
    enableImageTypes: [
      ImageType.primary,
      ImageType.thumb,
      ImageType.backdrop,
      ImageType.logo,
    ],
  );
  return res.data?.items ?? [];
});

/// Todos los episodios de una serie ordenados por temporada/episodio.
/// Se usa en el detalle de serie (pestaña Episodios y botón VER).
final seriesEpisodesProvider =
    FutureProvider.family<List<BaseItemDto>, String>((ref, seriesId) async {
  ref.cacheFor(_kLibraryCache);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null || seriesId.isEmpty) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    parentId: seriesId,
    recursive: true,
    includeItemTypes: [BaseItemKind.episode],
    sortBy: [ItemSortBy.parentIndexNumber, ItemSortBy.indexNumber],
    sortOrder: [SortOrder.ascending, SortOrder.ascending],
    fields: [ItemFields.primaryImageAspectRatio, ItemFields.overview],
    enableImageTypes: [
      ImageType.primary,
      ImageType.thumb,
      ImageType.backdrop,
      ImageType.logo,
    ],
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
            ImageType.logo,
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

/// "Continuar viendo" de VOD (películas y episodios: lo retomable de una
/// serie es el episodio a medias, nunca el item `series`).
final vodResumeProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getResumeItems(
    userId: userId,
    limit: 20,
    includeItemTypes: [BaseItemKind.movie, BaseItemKind.episode],
    fields: [
      ItemFields.primaryImageAspectRatio,
      ItemFields.overview,
      ItemFields.genres,
    ],
    enableImageTypes: [
      ImageType.primary,
      ImageType.backdrop,
      ImageType.thumb,
      ImageType.logo,
    ],
  );
  return res.data?.items ?? [];
});

/// Siguiente episodio de cada serie en VOD (fila "A continuación").
/// Solo episodios sin progreso (los a medias viven en Continuar viendo).
final vodNextUpProvider = FutureProvider<List<BaseItemDto>>((ref) async {
  ref.cacheFor(_kLibraryCache);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  try {
    final res = await client.getTvShowsApi().getNextUp(
      userId: userId,
      limit: 20,
      fields: [
        ItemFields.primaryImageAspectRatio,
        ItemFields.overview,
        ItemFields.people,
        ItemFields.providerIds,
        ItemFields.genres,
      ],
      enableImageTypes: [
        ImageType.primary,
        ImageType.thumb,
        ImageType.backdrop,
        ImageType.logo,
      ],
      enableUserData: true,
      enableResumable: false,
      enableRewatching: false,
    );
    return (res.data?.items ?? []).where((e) {
      if (e.type != BaseItemKind.episode) return false;
      final pct = e.userData?.playedPercentage ?? 0;
      final ticks = e.userData?.playbackPositionTicks ?? 0;
      return pct <= 0 && ticks <= 0;
    }).toList();
  } catch (_) {
    return const [];
  }
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
    fields: [
      ItemFields.primaryImageAspectRatio,
      ItemFields.overview,
      ItemFields.genres,
    ],
    enableImageTypes: [ImageType.primary, ImageType.thumb, ImageType.logo],
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

/// Tamaño de página para AllMovies (paginación con flechas) - 100 según spec.
const int kAllMoviesPageSize = 100;
const int kLibraryPageSize = 100;

/// Args para paginación filtrada genérica de biblioteca (viewId + categoría + orden).
/// Usado por el [LibraryViewScreen] universal para Películas y Series.
/// Soporta filtro de género simple o múltiple ( HomeScroll con varios géneros
/// separados por '|' ).
class LibraryFilteredArgs {
  const LibraryFilteredArgs({
    required this.viewId,
    required this.pageIndex,
    this.sortAscending = true,
    this.genre,
    this.genresPipe,
    this.includeItemTypes,
    this.sortBy = ItemSortBy.sortName,
  });
  final String viewId;
  final int pageIndex;
  final bool sortAscending;
  final String? genre;
  final String? genresPipe;
  final List<BaseItemKind>? includeItemTypes;
  final ItemSortBy sortBy;
  String? get effectiveGenre {
    if (genresPipe != null && genresPipe!.isNotEmpty) return genresPipe;
    return genre;
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryFilteredArgs &&
      other.viewId == viewId &&
      other.pageIndex == pageIndex &&
      other.sortAscending == sortAscending &&
      other.genre == genre &&
      other.genresPipe == genresPipe &&
      other.sortBy == sortBy &&
      listEquals(other.includeItemTypes, includeItemTypes);
  @override
  int get hashCode => Object.hash(
    viewId,
    pageIndex,
    sortAscending,
    genre,
    genresPipe,
    sortBy,
    includeItemTypes == null ? null : Object.hashAll(includeItemTypes!),
  );
}

/// Página filtrada genérica (por biblioteca + género + orden + paginación).
final libraryFilteredPageProvider =
    FutureProvider.family<List<BaseItemDto>, LibraryFilteredArgs>((
  ref,
  args,
) async {
  ref.cacheFor(_kLibraryCache);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final effectiveGenre = args.effectiveGenre;
  final res = await client.getItemsApi().getItems(
    userId: userId,
    parentId: args.viewId.isEmpty ? null : args.viewId,
    recursive: true,
    includeItemTypes: args.includeItemTypes,
    genres: effectiveGenre != null && effectiveGenre.isNotEmpty
        ? [effectiveGenre]
        : null,
    startIndex: args.pageIndex * kLibraryPageSize,
    limit: kLibraryPageSize,
    sortBy: [args.sortBy],
    sortOrder: [args.sortAscending ? SortOrder.ascending : SortOrder.descending],
    fields: [
      ItemFields.primaryImageAspectRatio,
      ItemFields.overview,
      ItemFields.genres,
    ],
    enableImageTypes: [
      ImageType.primary,
      ImageType.thumb,
      ImageType.backdrop,
      ImageType.logo,
    ],
    enableTotalRecordCount: true,
  );
  return res.data?.items ?? [];
});

/// Total genérico para [LibraryFilteredArgs] (para paginación).
final libraryFilteredCountProvider =
    FutureProvider.family<int, LibraryFilteredArgs>((ref, args) async {
  ref.cacheFor(_kLibraryCache);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return 0;
  final effectiveGenre = args.effectiveGenre;
  final res = await client.getItemsApi().getItems(
    userId: userId,
    parentId: args.viewId.isEmpty ? null : args.viewId,
    recursive: true,
    includeItemTypes: args.includeItemTypes,
    genres: effectiveGenre != null && effectiveGenre.isNotEmpty
        ? [effectiveGenre]
        : null,
    limit: 1,
    startIndex: 0,
    sortBy: [args.sortBy],
    fields: const [],
    enableTotalRecordCount: true,
    enableImages: false,
    enableUserData: false,
  );
  return res.data?.totalRecordCount ?? 0;
});

/// Args para paginación filtrada de películas (categoría + orden).
/// Mantiene compatibilidad con AllMoviesScreen legacy, delega al genérico.
class AllMoviesFilteredArgs {
  const AllMoviesFilteredArgs({
    required this.pageIndex,
    this.sortAscending = true,
    this.genre,
  });
  final int pageIndex;
  final bool sortAscending;
  final String? genre;
  @override
  bool operator ==(Object other) =>
      other is AllMoviesFilteredArgs &&
      other.pageIndex == pageIndex &&
      other.sortAscending == sortAscending &&
      other.genre == genre;
  @override
  int get hashCode => Object.hash(pageIndex, sortAscending, genre);
}

/// Página filtrada de películas con sort y categoría (legacy).
final allMoviesFilteredPageProvider =
    FutureProvider.family<List<BaseItemDto>, AllMoviesFilteredArgs>((
  ref,
  args,
) async {
  return ref.watch(
    libraryFilteredPageProvider(
      LibraryFilteredArgs(
        viewId: '',
        pageIndex: args.pageIndex,
        sortAscending: args.sortAscending,
        genre: args.genre,
        includeItemTypes: [BaseItemKind.movie],
      ),
    ).future,
  );
});

/// Total de películas (para calcular páginas 1/34). Usa misma lógica de filtro.
final allMoviesTotalCountProvider =
    FutureProvider.family<int, String?>((ref, genre) async {
  return ref.watch(
    libraryFilteredCountProvider(
      LibraryFilteredArgs(
        viewId: '',
        pageIndex: 0,
        genre: genre,
        includeItemTypes: [BaseItemKind.movie],
      ),
    ).future,
  );
});

/// Contador real de items por biblioteca (cache global, solo 1 llamada por viewId).
/// Usa enableTotalRecordCount y limit 0 para no traer items, solo el conteo.
final libraryItemCountProvider = FutureProvider.family<int, String>((ref, viewId) async {
  if (viewId.isEmpty) return 0;
  // Cache global indefinida hasta que el usuario haga pull-to-refresh o reinicie.
  ref.keepAlive();
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return 0;
  try {
    // Para LiveTV la cuenta de canales viene del LiveTV, pero el conteo genérico
    // via parentId también funciona para la mayoría; si falla se intenta liveTv.
    final res = await client.getItemsApi().getItems(
      userId: userId,
      parentId: viewId,
      recursive: true,
      limit: 0,
      enableTotalRecordCount: true,
      enableImages: false,
      enableUserData: false,
      fields: const [],
    );
    final count = res.data?.totalRecordCount ?? 0;
    return count;
  } catch (_) {
    return 0;
  }
});

/// Horas totales de grabaciones DVR para una vista (si es DVR).
final libraryDvrHoursProvider = FutureProvider.family<int, String>((ref, viewId) async {
  if (viewId.isEmpty) return 0;
  ref.keepAlive();
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return 0;
  try {
    final res = await client.getItemsApi().getItems(
      userId: userId,
      parentId: viewId,
      recursive: true,
      limit: 100,
      enableImages: false,
      enableUserData: false,
    );
    final items = res.data?.items ?? const [];
    final totalTicks = items.fold<int>(0, (p, e) => p + (e.runTimeTicks ?? 0));
    final hours = totalTicks ~/ 36000000000; // 1h = 3600s = 3600*1e7 ticks
    return hours;
  } catch (_) {
    return 0;
  }
});

/// Página de todas las películas del servidor, para compatibilidad (grid infinito legacy).
/// Ahora delega al paginado filtrado sin filtro y ascendente.
final allMoviesPageProvider = FutureProvider.family<List<BaseItemDto>, int>((
  ref,
  pageIndex,
) async {
  return ref.watch(allMoviesFilteredPageProvider(
    AllMoviesFilteredArgs(pageIndex: pageIndex, sortAscending: true),
  ).future);
});

/// Convierte un rango opcional [from]..[to] en la lista de años que pide la
/// API. Sin límites devuelve `null` (sin filtro); con un solo límite se
/// extiende hasta el año actual o desde 1900; si viene invertido se corrige.
List<int>? _yearRange(int? from, int? to) {
  if (from == null && to == null) return null;
  var start = from ?? 1900;
  var end = to ?? DateTime.now().year;
  if (start > end) {
    final tmp = start;
    start = end;
    end = tmp;
  }
  return [for (var y = start; y <= end; y++) y];
}

/// Items de una fila de contenido configurada por el skin (filtrada por
/// géneros y tipos). Se usa para los scrolls extra definidos en cada preset.
/// El orden lo decide [HomeScroll.sort] por scroll.
final homeScrollItemsProvider =
    FutureProvider.family<List<BaseItemDto>, HomeScroll>((ref, scroll) async {
      // Random no se cachea: cada visita reordena el scroll.
      if (scroll.sort != HomeScrollSort.random) ref.cacheFor(_kLibraryCache);
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      if (client == null || userId == null) return const [];
      final (sortBy, sortOrder) = homeScrollSortParams(scroll.sort);
      // Sin géneros => sin filtro (antes se enviaba [""] y Jellyfin devolvía 0).
      final genresFilter = scroll.genres.isEmpty
          ? null
          : [
              scroll.genres.map((g) => g.value).join('|'),
            ];
      // Rango de años (ej. nostalgia con yearTo). Solo scrolls custom.
      final yearsFilter = _yearRange(scroll.yearFrom, scroll.yearTo);
      final res = await client.getItemsApi().getItems(
        userId: userId,
        recursive: true,
        includeItemTypes: scroll.types.isEmpty ? null : scroll.types,
        // Jellyfin espera los géneros separados por "|" en un único valor.
        genres: genresFilter,
        years: yearsFilter,
        sortBy: sortBy,
        sortOrder: sortOrder,
        limit: scroll.limit,
        fields: [
          ItemFields.primaryImageAspectRatio,
          ItemFields.overview,
          ItemFields.people,
          ItemFields.genres,
        ],
        enableImageTypes: [
      ImageType.primary,
      ImageType.thumb,
      ImageType.backdrop,
      ImageType.logo,
    ],
      );
      final items = collapseSeriesDuplicates(res.data?.items ?? []);
      if (items.isEmpty) {
        debugPrint(
          '[HomeScroll] sin resultados: titleKey=${scroll.titleKey.name} '
          'genres=${scroll.genres.map((g) => g.value).join('|')} '
          'types=${scroll.types.map((t) => t.name).join(',')} '
          'years=${scroll.yearFrom ?? '-'}-${scroll.yearTo ?? '-'} '
          'sort=${scroll.sort.name}',
        );
      }
      return items;
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
final artistAlbumsProvider = FutureProvider.family<List<BaseItemDto>, BaseItemDto>((
  ref,
  album,
) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final albumId = album.id ?? '';
  final artist =
      (album.albumArtist?.trim().isNotEmpty == true
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
      albumArtistIds: artistId != null && artistId.isNotEmpty
          ? [artistId]
          : null,
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

/// Pistas de Jellyfin para un artista concreto por ID (lookup indexado, más rápido).
///
/// Usa `artistIds`/`albumArtistIds`/`contributingArtistIds` que son índices
/// en la DB de Jellyfin, evitando la búsqueda de texto completa.
final artistTracksByArtistIdProvider =
    FutureProvider.family<List<BaseItemDto>, String>((ref, artistId) async {
      final link = ref.keepAlive();
      Timer(const Duration(minutes: 5), link.close);

      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      if (client == null || userId == null || artistId.trim().isEmpty) {
        return const [];
      }
      final id = artistId.trim();
      try {
        final res = await client.getItemsApi().getItems(
          userId: userId,
          recursive: true,
          includeItemTypes: [BaseItemKind.audio],
          artistIds: [id],
          albumArtistIds: [id],
          contributingArtistIds: [id],
          limit: 20,
          fields: [ItemFields.primaryImageAspectRatio],
          enableImageTypes: [ImageType.primary],
          enableUserData: true,
          enableImages: true,
          enableTotalRecordCount: false,
        );
        var items = res.data?.items ?? const <BaseItemDto>[];
        // Fallback: si el servidor no indexa alguno de los ids, probar solo albumArtistIds
        if (items.isEmpty) {
          final fallback = await client.getItemsApi().getItems(
            userId: userId,
            recursive: true,
            includeItemTypes: [BaseItemKind.audio],
            albumArtistIds: [id],
            limit: 20,
            fields: [ItemFields.primaryImageAspectRatio],
            enableImageTypes: [ImageType.primary],
            enableUserData: true,
            enableImages: true,
            enableTotalRecordCount: false,
          );
          items = fallback.data?.items ?? const <BaseItemDto>[];
        }
        return items;
      } catch (_) {
        return const [];
      }
    });

/// Pistas de Jellyfin para un artista concreto (solo audio reproducible).
///
/// Optimizado para carga rápida: 1 sola petición (searchTerm) con `limit:20`,
/// fields mínimos y `enableTotalRecordCount:false` para evitar COUNT(*) en DB.
/// Cachea 5 minutos vía keepAlive para evitar refetch al volver atrás.
final artistTracksProvider = FutureProvider.family<List<BaseItemDto>, String>((
  ref,
  artistName,
) async {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);

  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null || artistName.trim().isEmpty) {
    return const [];
  }
  final name = artistName.trim();
  try {
    // Intento principal: búsqueda de texto (más tolerante que `artists:[name]` exacto)
    // Usa una única petición rápida en lugar de 2 secuenciales.
    final res = await client.getItemsApi().getItems(
      userId: userId,
      recursive: true,
      includeItemTypes: [BaseItemKind.audio],
      searchTerm: name,
      limit: 20,
      fields: [ItemFields.primaryImageAspectRatio],
      enableImageTypes: [ImageType.primary],
      enableUserData: true,
      enableImages: true,
      enableTotalRecordCount: false,
    );
    var items = res.data?.items ?? const <BaseItemDto>[];
    if (items.isEmpty) return const [];

    // Filtro ligero con matching tolerante (transliteración + bidireccional + tokens).
    final lowerName = _normalizeArtist(name);
    final filtered = items.where((e) => _artistMatches(e, lowerName)).toList();
    if (filtered.isNotEmpty) return filtered;
    // Si el filtro estricto deja todo vacío (ej. "The Beatles" vs "Beatles"),
    // intenta con búsqueda exacta por artistas antes de devolver todo.
    if (items.isNotEmpty) return items;
    // Fallback adicional: probar filtro por artists:[name] si searchTerm no devolvió nada útil
    try {
      final fallback = await client.getItemsApi().getItems(
        userId: userId,
        recursive: true,
        includeItemTypes: [BaseItemKind.audio],
        artists: [name],
        limit: 20,
        fields: [ItemFields.primaryImageAspectRatio],
        enableImageTypes: [ImageType.primary],
        enableUserData: true,
        enableImages: true,
        enableTotalRecordCount: false,
      );
      final fbItems = fallback.data?.items ?? const <BaseItemDto>[];
      if (fbItems.isNotEmpty) {
        final fbFiltered = fbItems.where((e) => _artistMatches(e, lowerName)).toList();
        return fbFiltered.isNotEmpty ? fbFiltered : fbItems;
      }
    } catch (_) {}
    return items;
  } catch (_) {
    return const [];
  }
});

const int kArtistTracksPageSize = 50;

class ArtistTracksByIdPageArgs {
  const ArtistTracksByIdPageArgs({required this.artistId, required this.page});
  final String artistId;
  final int page;
  @override
  bool operator ==(Object other) =>
      other is ArtistTracksByIdPageArgs &&
      other.artistId == artistId &&
      other.page == page;
  @override
  int get hashCode => Object.hash(artistId, page);
}

class ArtistTracksByNamePageArgs {
  const ArtistTracksByNamePageArgs({
    required this.artistName,
    required this.page,
  });
  final String artistName;
  final int page;
  @override
  bool operator ==(Object other) =>
      other is ArtistTracksByNamePageArgs &&
      other.artistName == artistName &&
      other.page == page;
  @override
  int get hashCode => Object.hash(artistName, page);
}

/// Paginado por ID: todas las pistas Jellyfin de un artista con soporte infinite scroll.
final artistTracksByArtistIdPagedProvider =
    FutureProvider.family<List<BaseItemDto>, ArtistTracksByIdPageArgs>((
      ref,
      args,
    ) async {
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      if (client == null || userId == null || args.artistId.trim().isEmpty) {
        return const [];
      }
      final id = args.artistId.trim();
      try {
        final res = await client.getItemsApi().getItems(
          userId: userId,
          recursive: true,
          includeItemTypes: [BaseItemKind.audio],
          artistIds: [id],
          albumArtistIds: [id],
          contributingArtistIds: [id],
          startIndex: args.page * kArtistTracksPageSize,
          limit: kArtistTracksPageSize,
          fields: [ItemFields.primaryImageAspectRatio],
          enableImageTypes: [ImageType.primary],
          enableUserData: true,
          enableImages: true,
          enableTotalRecordCount: false,
        );
        var items = res.data?.items ?? const <BaseItemDto>[];
        if (items.isEmpty && args.page == 0) {
          final fallback = await client.getItemsApi().getItems(
            userId: userId,
            recursive: true,
            includeItemTypes: [BaseItemKind.audio],
            albumArtistIds: [id],
            startIndex: 0,
            limit: kArtistTracksPageSize,
            fields: [ItemFields.primaryImageAspectRatio],
            enableImageTypes: [ImageType.primary],
            enableUserData: true,
            enableImages: true,
            enableTotalRecordCount: false,
          );
          items = fallback.data?.items ?? const <BaseItemDto>[];
        }
        return items;
      } catch (_) {
        return const [];
      }
    });

/// Paginado por nombre: todas las pistas Jellyfin de un artista con soporte infinite scroll.
/// Soporta Lidarr con "Shakira;Rauw Alejandro" en un solo string separado por ; , /
final artistTracksPagedProvider =
    FutureProvider.family<List<BaseItemDto>, ArtistTracksByNamePageArgs>((
      ref,
      args,
    ) async {
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      if (client == null || userId == null || args.artistName.trim().isEmpty) {
        return const [];
      }
      final name = args.artistName.trim();
      final lowerName = _normalizeArtist(name);
      try {
        final res = await client.getItemsApi().getItems(
          userId: userId,
          recursive: true,
          includeItemTypes: [BaseItemKind.audio],
          searchTerm: name,
          startIndex: args.page * kArtistTracksPageSize,
          limit: kArtistTracksPageSize,
          fields: [ItemFields.primaryImageAspectRatio],
          enableImageTypes: [ImageType.primary],
          enableUserData: true,
          enableImages: true,
          enableTotalRecordCount: false,
        );
        var items = res.data?.items ?? const <BaseItemDto>[];
        if (items.isEmpty) return const [];
        final filtered = items
            .where((e) => _artistMatches(e, lowerName))
            .toList();
        return filtered.isNotEmpty ? filtered : items;
      } catch (_) {
        return const [];
      }
    });

/// Índice completo Jellyfin para dedup (todas las pistas del artista, hasta 600).
/// Usado solo para decidir si un top Deezer ya existe en Jellyfin, sin depender de paginación UI.
final artistJellyIndexByIdProvider =
    FutureProvider.family<List<BaseItemDto>, String>((ref, artistId) async {
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      if (client == null || userId == null || artistId.trim().isEmpty) {
        return const [];
      }
      final id = artistId.trim();
      final all = <BaseItemDto>[];
      int start = 0;
      const pageSize = 200;
      for (int iter = 0; iter < 4; iter++) {
        try {
          final res = await client.getItemsApi().getItems(
            userId: userId,
            recursive: true,
            includeItemTypes: [BaseItemKind.audio],
            artistIds: [id],
            albumArtistIds: [id],
            contributingArtistIds: [id],
            startIndex: start,
            limit: pageSize,
            fields: [ItemFields.primaryImageAspectRatio],
            enableImageTypes: [ImageType.primary],
            enableUserData: true,
            enableImages: true,
            enableTotalRecordCount: false,
          );
          var items = res.data?.items ?? const <BaseItemDto>[];
          if (items.isEmpty && start == 0) {
            final fb = await client.getItemsApi().getItems(
              userId: userId,
              recursive: true,
              includeItemTypes: [BaseItemKind.audio],
              albumArtistIds: [id],
              startIndex: 0,
              limit: pageSize,
              fields: [ItemFields.primaryImageAspectRatio],
              enableImageTypes: [ImageType.primary],
              enableUserData: true,
              enableImages: true,
              enableTotalRecordCount: false,
            );
            items = fb.data?.items ?? const <BaseItemDto>[];
          }
          all.addAll(items);
          if (items.length < pageSize) break;
          start += pageSize;
        } catch (_) {
          break;
        }
      }
      return all;
    });

final artistJellyIndexByNameProvider = FutureProvider.family<List<BaseItemDto>, String>((
  ref,
  artistName,
) async {
  final link = ref.keepAlive();
  Timer(const Duration(minutes: 5), link.close);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null || artistName.trim().isEmpty) {
    return const [];
  }
  final name = artistName.trim();
  final all = <BaseItemDto>[];
  final lowerName = _normalizeArtist(name);
  final normName = _transliterateSimple(name);
  // Helper para fetchear por artistId y acumular sin return temprano
  Future<void> fetchByArtistId(String q) async {
    try {
      final res = await client.getArtistsApi().getArtistByName(name: q, userId: userId).timeout(const Duration(seconds: 8));
      final artist = res.data;
      if (artist?.id != null && artist!.id!.isNotEmpty) {
        final trRes = await client
            .getItemsApi()
            .getItems(
              userId: userId,
              recursive: true,
              includeItemTypes: [BaseItemKind.audio],
              artistIds: [artist.id!],
              albumArtistIds: [artist.id!],
              limit: 80,
              fields: const [],
              enableImages: false,
              enableUserData: false,
              enableTotalRecordCount: false,
            )
            .timeout(const Duration(seconds: 8));
        for (final t in (trRes.data?.items ?? const <BaseItemDto>[])) {
          if (!all.any((a) => a.id == t.id)) all.add(t);
        }
      }
    } catch (_) {}
  }

  // 1) Intento por artistId con nombre original y normalizado (The Weeknd -> weeknd)
  await fetchByArtistId(name);
  if (normName != name) await fetchByArtistId(normName);
  final weekndOnly = lowerName != name.toLowerCase() ? lowerName : null;
  if (weekndOnly != null && weekndOnly != normName) await fetchByArtistId(weekndOnly);

  // 2) Búsqueda por searchTerm con original y normalizado
  Future<void> fetchBySearch(String q) async {
    try {
      final res = await client
          .getItemsApi()
          .getItems(
            userId: userId,
            recursive: true,
            includeItemTypes: [BaseItemKind.audio],
            searchTerm: q,
            limit: 80,
            fields: const [],
            enableImages: false,
            enableUserData: false,
            enableTotalRecordCount: false,
          )
          .timeout(const Duration(seconds: 8));
      var items = res.data?.items ?? const <BaseItemDto>[];
      final filtered = items.where((e) => _artistMatches(e, lowerName)).toList();
      final toAdd = filtered.isNotEmpty ? filtered : (all.isEmpty ? items : const <BaseItemDto>[]);
      for (final p in toAdd) {
        if (!all.any((a) => a.id == p.id)) all.add(p);
      }
    } catch (_) {}
  }

  await fetchBySearch(name);
  if (normName != name) await fetchBySearch(normName);
  if (weekndOnly != null && weekndOnly != normName && weekndOnly != name) await fetchBySearch(weekndOnly);
  if (all.isNotEmpty) {
    // No return temprano, sigue acumulando con artists exacto para asegurar cobertura
  }
  try {
    final res = await client
        .getItemsApi()
        .getItems(userId: userId, recursive: true, includeItemTypes: [BaseItemKind.audio], artists: [name], limit: 50, fields: const [], enableImages: false, enableUserData: false, enableTotalRecordCount: false)
        .timeout(const Duration(seconds: 8));
    for (final p in (res.data?.items ?? const <BaseItemDto>[])) {
      if (!all.any((a) => a.id == p.id)) all.add(p);
    }
    if (normName != name) {
      final res2 = await client
          .getItemsApi()
          .getItems(userId: userId, recursive: true, includeItemTypes: [BaseItemKind.audio], artists: [normName], limit: 50, fields: const [], enableImages: false, enableUserData: false, enableTotalRecordCount: false)
          .timeout(const Duration(seconds: 8));
      for (final p in (res2.data?.items ?? const <BaseItemDto>[])) {
        if (!all.any((a) => a.id == p.id)) all.add(p);
      }
    }
  } catch (_) {}
  return all;
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
final spotifyTrendingSongsProvider = FutureProvider<List<BaseItemDto>>((
  ref,
) async {
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
      fields: [
        ItemFields.primaryImageAspectRatio,
        ItemFields.overview,
        ItemFields.genres,
      ],
      enableImageTypes: [ImageType.primary, ImageType.thumb],
    );
    return res.data?.items ?? [];
  } catch (_) {
    return const [];
  }
});

/// Spotify: artistas populares (MusicArtist) - trendy local server-side.
/// Orden: PlayCount desc → DatePlayed desc. Sin Random, solo server-side via ArtistsApi.
final spotifyPopularArtistsProvider = FutureProvider<List<BaseItemDto>>((
  ref,
) async {
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
        final name =
            t.artists?.firstOrNull ?? t.albumArtists?.firstOrNull?.name ?? '';
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
      final name =
          t.artists?.firstOrNull ?? t.albumArtists?.firstOrNull?.name ?? '';
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
final jellyfinPlaylistsProvider = FutureProvider<List<BaseItemDto>>((
  ref,
) async {
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
      final audioOnly = all
          .where((e) => e.mediaType == MediaType.audio)
          .toList();
      items = audioOnly.isNotEmpty ? audioOnly : all;
    }
    return items;
  } catch (_) {
    return const [];
  }
});

/// Jellyfin: elementos recién añadidos (música) - últimos álbumes creados.
final jellyfinRecentlyAddedMusicProvider = FutureProvider<List<BaseItemDto>>((
  ref,
) async {
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
      fields: [
        ItemFields.primaryImageAspectRatio,
        ItemFields.overview,
        ItemFields.dateCreated,
      ],
      enableImageTypes: [ImageType.primary, ImageType.thumb],
      enableUserData: true,
    );
    return res.data?.items ?? const [];
  } catch (_) {
    return const [];
  }
});

/// Jellyfin: pistas de una playlist (estilo Jellyfin Classic para playlist).
final playlistTracksProvider = FutureProvider.family<List<BaseItemDto>, String>(
  (ref, playlistId) async {
    final client = ref.watch(jellyfinClientProvider);
    final userId = ref.watch(currentUserIdProvider);
    if (client == null || userId == null || playlistId.isEmpty) return const [];
    try {
      final res = await client.getPlaylistsApi().getPlaylistItems(
        playlistId: playlistId,
        userId: userId,
        fields: [
          ItemFields.primaryImageAspectRatio,
          ItemFields.overview,
          ItemFields.genres,
        ],
        enableImages: true,
        enableUserData: true,
        limit: 200,
      );
      return res.data?.items ?? const [];
    } catch (_) {
      // Fallback via ItemsApi parentId
      try {
        final fallback = await client.getItemsApi().getItems(
          userId: userId,
          parentId: playlistId,
          recursive: true,
          limit: 200,
          fields: [
            ItemFields.primaryImageAspectRatio,
            ItemFields.overview,
            ItemFields.genres,
          ],
          enableImageTypes: [ImageType.primary, ImageType.thumb],
        );
        return fallback.data?.items ?? const [];
      } catch (_) {
        return const [];
      }
    }
  },
);

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
