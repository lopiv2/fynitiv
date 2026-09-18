import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../library/application/library_providers.dart'
    show currentUserIdProvider, jellyfinClientProvider;

/// Resultados de búsqueda como [BaseItemDto] completos (no [SearchHint]),
/// para poder pintarlos directamente en [BackdropCard] con sus imágenes,
/// títulos y subtítulos por tipo (audio, vídeo, artista, persona...).
///
/// Usa el método `getItems` de `jellyfin_dart` con `searchTerm`, que
/// devuelve DTOs completos con imágenes, a diferencia de `getSearchHints`.
final searchHintsProvider = FutureProvider.family<List<BaseItemDto>, String>(
  (ref, term) async {
    final query = term.trim();
    if (query.isEmpty) return const [];
    final client = ref.watch(jellyfinClientProvider);
    final userId = ref.watch(currentUserIdProvider);
    if (client == null || userId == null) return const [];
    final res = await client.getItemsApi().getItems(
          userId: userId,
          searchTerm: query,
          recursive: true,
          limit: 50,
          fields: [
            ItemFields.overview,
            ItemFields.genres,
            ItemFields.people,
            ItemFields.dateCreated,
            ItemFields.studios,
            ItemFields.primaryImageAspectRatio,
          ],
          enableImageTypes: [
            ImageType.primary,
            ImageType.backdrop,
            ImageType.thumb,
            ImageType.logo,
          ],
          enableUserData: true,
          enableImages: true,
        );
    final items = res.data?.items ?? [];
    // Debug temporal: qué tipos devuelve Jellyfin para este término, para
    // decidir a qué pantalla redirigir cada uno (player / detalle / música).
    if (items.isNotEmpty) {
      final byType = <String, int>{};
      for (final it in items) {
        final key = it.type?.name ?? 'null';
        byType[key] = (byType[key] ?? 0) + 1;
      }
      debugPrint(
        '[Search] "$query" -> ${items.length}: '
        '${byType.entries.map((e) => '${e.key}x${e.value}').join(', ')}',
      );
      for (final it in items.take(15)) {
        debugPrint('[Search]   - ${it.type?.name} "${it.name}" id=${it.id}');
      }
    } else {
      debugPrint('[Search] "$query" -> 0 resultados');
    }
    return items;
  },
);
