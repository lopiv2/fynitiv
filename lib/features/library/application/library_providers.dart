import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

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
        enableImageTypes: [ImageType.primary],
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
