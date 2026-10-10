import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../../core/skin/home_scroll.dart';
import '../domain/mood_suggestion.dart';
import 'image_url.dart';
import 'library_providers.dart';

class MoodRefreshController extends Notifier<int> {
  @override
  int build() => DateTime.now().microsecondsSinceEpoch;

  void refresh() {
    state = DateTime.now().microsecondsSinceEpoch;
  }
}

/// Semilla para renovar frases e imágenes al volver a entrar en Inicio.
final moodRefreshProvider = NotifierProvider<MoodRefreshController, int>(
  MoodRefreshController.new,
);

/// Backdrop aleatorio por mood. Si el título no tiene backdrop se utiliza su
/// mejor imagen alternativa, manteniendo la tarjeta decorativa disponible.
final moodBackdropsProvider = FutureProvider<Map<MoodKey, String?>>((
  ref,
) async {
  ref.watch(moodRefreshProvider);
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  final serverUrl = ref.watch(authServerUrlProvider);
  if (client == null || userId == null || serverUrl == null) {
    return const {};
  }

  final entries = await Future.wait(
    kMoodSuggestions.map((mood) async {
      try {
        final item = await fetchRandomMoodItem(
          client: client,
          userId: userId,
          genres: mood.genres,
          preferBackdrop: true,
        );
        final imageUrl = item == null
            ? null
            : bestLandscapeImageUrl(serverUrl, item);
        return MapEntry(mood.key, imageUrl);
      } catch (_) {
        return MapEntry<MoodKey, String?>(mood.key, null);
      }
    }),
  );
  return Map.fromEntries(entries);
}, isAutoDispose: true);

/// Devuelve una película o serie aleatoria cuyos géneros encajen con [genres]
/// (filtro OR). `null` si no hay resultados o faltan datos.
Future<BaseItemDto?> fetchRandomMoodItem({
  required JellyfinDart client,
  required String userId,
  required List<JellyGenre> genres,
  bool preferBackdrop = false,
}) async {
  if (genres.isEmpty) return null;
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: const [BaseItemKind.movie, BaseItemKind.series],
    // Jellyfin espera los géneros separados por "|" en un único valor (OR).
    genres: [genres.map((g) => g.value).join('|')],
    sortBy: const [ItemSortBy.random],
    limit: preferBackdrop ? 10 : 1,
    fields: const [
      ItemFields.primaryImageAspectRatio,
      ItemFields.overview,
      ItemFields.genres,
    ],
    enableImageTypes: const [
      ImageType.primary,
      ImageType.backdrop,
      ImageType.thumb,
      ImageType.logo,
    ],
  );
  final items = res.data?.items ?? const <BaseItemDto>[];
  if (items.isEmpty) return null;
  if (preferBackdrop) {
    for (final item in items) {
      if (item.backdropImageTags?.isNotEmpty ?? false) return item;
    }
  }
  return items.first;
}
