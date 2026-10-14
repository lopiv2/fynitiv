import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../../core/skin/home_scroll.dart';
import '../domain/seasonal_suggestion.dart';
import 'library_providers.dart';

/// Títulos de la biblioteca que encajan con la temática del calendario.
///
/// Combina dos búsquedas: por término (nombre/descripción, coincidencia real
/// con la fecha, ej. "Christmas") y por género (garantiza contenido aunque no
/// haya títulos con el nombre de la fecha). El orden lo decide [HomeScrollSort].
final seasonalSuggestionItemsProvider =
    FutureProvider.family<List<BaseItemDto>, (SeasonalEvent, HomeScrollSort)>((
      ref,
      args,
    ) async {
      final event = args.$1;
      final sort = args.$2;
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      if (client == null || userId == null) return const [];

      final (sortBy, sortOrder) = homeScrollSortParams(sort);

      Future<List<BaseItemDto>> fetch({
        String? searchTerm,
        List<String>? genres,
      }) async {
        try {
          final response = await client.getItemsApi().getItems(
            userId: userId,
            recursive: true,
            includeItemTypes: const [BaseItemKind.movie, BaseItemKind.series],
            searchTerm: searchTerm,
            genres: genres,
            sortBy: sortBy,
            sortOrder: sortOrder,
            limit: 24,
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
            enableUserData: true,
          );
          return response.data?.items ?? const <BaseItemDto>[];
        } catch (_) {
          return const <BaseItemDto>[];
        }
      }

      final seasonGenres = seasonalEventGenres(event);
      final genreValues = seasonGenres.join('|');

      final termResults = await Future.wait(
        seasonalEventSearchTerms(event).map((term) => fetch(searchTerm: term)),
      );
      final genreResults = await fetch(genres: [genreValues]);

      // Solo coincidencias por nombre cuyo género encaje con la temática (evita
      // que un título de otro género, p. ej. Acción, entre en Halloween). Los
      // títulos sin género declarado se conservan.
      final seasonGenresLower = seasonGenres
          .map((g) => g.toLowerCase())
          .toSet();
      bool inSeasonGenre(BaseItemDto item) {
        final genres = item.genres;
        if (genres == null || genres.isEmpty) return true;
        return genres.any((g) => seasonGenresLower.contains(g.toLowerCase()));
      }

      final byTerm = <BaseItemDto>[
        for (final list in termResults) ...list,
      ].where(inSeasonGenre).toList();

      final uniqueItems = <String, BaseItemDto>{};
      void collect(Iterable<BaseItemDto> items) {
        for (final item in items) {
          final id = item.id;
          if (id != null && id.isNotEmpty) {
            uniqueItems.putIfAbsent(id, () => item);
          }
        }
      }

      // Primero las coincidencias por término, luego el relleno por género.
      collect(byTerm);
      collect(genreResults);

      final items = uniqueItems.values.toList();
      final unwatched = items
          .where((item) => item.userData?.played != true)
          .toList();
      final pool = unwatched.isNotEmpty ? unwatched : items;
      // Variedad solo cuando el orden es aleatorio; con un orden concreto se
      // respeta el que devuelve la API.
      if (sort == HomeScrollSort.random) pool.shuffle(Random());
      return pool;
    });
