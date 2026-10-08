import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../../core/skin/home_scroll.dart';

/// Devuelve una película o serie aleatoria cuyos géneros encajen con [genres]
/// (filtro OR). `null` si no hay resultados o faltan datos.
Future<BaseItemDto?> fetchRandomMoodItem({
  required JellyfinDart client,
  required String userId,
  required List<JellyGenre> genres,
}) async {
  if (genres.isEmpty) return null;
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: const [BaseItemKind.movie, BaseItemKind.series],
    // Jellyfin espera los géneros separados por "|" en un único valor (OR).
    genres: [genres.map((g) => g.value).join('|')],
    sortBy: const [ItemSortBy.random],
    limit: 1,
    fields: const [
      ItemFields.primaryImageAspectRatio,
      ItemFields.overview,
      ItemFields.genres,
    ],
    enableImageTypes: const [
      ImageType.primary,
      ImageType.backdrop,
      ImageType.logo,
    ],
  );
  final items = res.data?.items ?? const <BaseItemDto>[];
  if (items.isEmpty) return null;
  return items.first;
}
