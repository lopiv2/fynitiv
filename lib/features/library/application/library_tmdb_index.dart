import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import 'library_providers.dart';

const _kIndexCache = Duration(minutes: 20);

extension _IndexCache on Ref {
  void cacheFor(Duration d) {
    final link = keepAlive();
    Timer(d, link.close);
  }
}

/// Tipo de contenido para la clave TMDB (cine y TV son espacios distintos).
enum TmdbMediaType { movie, series }

typedef TmdbKey = ({TmdbMediaType type, int tmdbId});

/// Índice `(tipo, tmdbId) → item de Jellyfin` de películas y series, con una
/// sola consulta cacheada. Incluye placeholders (`.disc` de Radarr/Sonarr)
/// para poder distinguir "en biblioteca" de "procesando".
final libraryTmdbIndexProvider =
    FutureProvider<Map<TmdbKey, BaseItemDto>>((ref) async {
      ref.cacheFor(_kIndexCache);
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      if (client == null || userId == null) return const {};
      final res = await client.getItemsApi().getItems(
        userId: userId,
        recursive: true,
        includeItemTypes: const [BaseItemKind.movie, BaseItemKind.series],
        fields: const [
          ItemFields.providerIds,
          ItemFields.mediaSources,
          ItemFields.path,
        ],
        enableImages: false,
        enableUserData: false,
        enableTotalRecordCount: false,
      );
      final out = <TmdbKey, BaseItemDto>{};
      for (final item in res.data?.items ?? const <BaseItemDto>[]) {
        final type = switch (item.type) {
          BaseItemKind.movie => TmdbMediaType.movie,
          BaseItemKind.series => TmdbMediaType.series,
          _ => null,
        };
        if (type == null) continue;
        final ids = item.providerIds;
        if (ids == null || ids.isEmpty) continue;
        int? tmdbId;
        for (final entry in ids.entries) {
          if (entry.key.toLowerCase() == 'tmdb') {
            tmdbId = int.tryParse(entry.value);
            break;
          }
        }
        if (tmdbId == null) continue;
        final key = (type: type, tmdbId: tmdbId);
        final existing = out[key];
        // Un título con media real prevalece sobre un stub del mismo id.
        if (existing == null ||
            (isPlaceholderItem(existing) && !isPlaceholderItem(item))) {
          out[key] = item;
        }
      }
      return out;
    });
