import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../../core/i18n/locale_provider.dart';
import '../../../core/i18n/locale_regions.dart';
import '../../../core/skin/layout_section.dart';
import '../../library/application/library_providers.dart';
import '../domain/seerr_models.dart';
import 'seerr_controller.dart';

/// Id sintético de un título de Seerr (para mapearlo a `BaseItemDto`).
String seerrMediaId(SeerrMedia m) => 'seerr:${m.mediaType.value}:${m.tmdbId}';

/// Mapea un título de Seerr a `BaseItemDto` para reutilizar las tarjetas/filas
/// de la app (la imagen se resuelve aparte con una URL de TMDB).
BaseItemDto seerrMediaToBaseItem(SeerrMedia m) => BaseItemDto(
  id: seerrMediaId(m),
  name: m.title,
  type: m.mediaType == SeerrMediaType.movie
      ? BaseItemKind.movie
      : BaseItemKind.series,
  productionYear: m.year,
  overview: m.overview,
  genres: m.genres,
  officialRating: m.officialRating,
  runTimeTicks: m.runtimeMinutes == null
      ? null
      : m.runtimeMinutes! * 600000000,
  communityRating: m.voteAverage,
  people: [
    for (final credit in m.credits)
      BaseItemPerson(
        name: credit.name,
        role: credit.role,
        type: switch (credit.type.toLowerCase()) {
          'director' => PersonKind.director,
          'producer' => PersonKind.producer,
          'creator' => PersonKind.creator,
          _ => PersonKind.actor,
        },
      ),
  ],
  studios: [for (final name in m.studios) NameGuidPair(name: name)],
  // Sin media real: la ficha de la app lo trata como no reproducible.
  locationType: LocationType.virtual,
);

/// Lista de descubrimiento de Seerr por categoría (tendencias, populares,
/// próximos…).
final seerrDiscoverProvider =
    FutureProvider.family<List<SeerrMedia>, SeerrDiscoverCategory>((
      ref,
      category,
    ) async {
      final api = ref.watch(seerrApiProvider);
      if (api == null) return const [];
      try {
        return await api.discover(category);
      } catch (_) {
        return const [];
      }
    });

/// Búsqueda de títulos (películas y series).
final seerrSearchProvider = FutureProvider.family<List<SeerrMedia>, String>((
  ref,
  query,
) async {
  final api = ref.watch(seerrApiProvider);
  final q = query.trim();
  if (api == null || q.isEmpty) return const [];
  try {
    return await api.search(q);
  } catch (_) {
    return const [];
  }
});

/// Referencia a un título Seerr.
typedef SeerrDetailRef = ({SeerrMediaType mediaType, int tmdbId});

typedef SeerrCardRef = ({
  SeerrMediaType mediaType,
  int tmdbId,
  String title,
});

class SeerrCardMetadata {
  const SeerrCardMetadata({
    required this.providers,
    required this.libraryStatus,
  });

  final List<SeerrWatchProvider> providers;
  final SeerrLibraryStatus libraryStatus;
}

/// Ficha de un título.
final seerrDetailProvider = FutureProvider.family<SeerrMedia, SeerrDetailRef>((
  ref,
  r,
) async {
  final api = ref.watch(seerrApiProvider);
  if (api == null) throw StateError('seerr-not-configured');
  final locale = ref.watch(localeProvider).value ?? const Locale('es');
  final region = regionForLocale(locale);
  return api.detail(r.mediaType, r.tmdbId, region: region);
});

/// Referencia para comprobar si un título de TMDB ya está en Jellyfin.
typedef JellyfinTmdbLookup = ({BaseItemKind kind, int tmdbId, String title});

/// Estado de un título de Seerr respecto a la biblioteca Jellyfin.
enum SeerrLibraryStatus {
  /// No está en la biblioteca.
  none,

  /// Está solo como stub/placeholder (`.disc` de Radarr/Sonarr): aún sin media
  /// real → "Próximamente en tu biblioteca".
  placeholder,

  /// Tiene archivos multimedia reales → "En tu biblioteca".
  available,
}

/// Estado del título (por `TmdbId`) en la biblioteca Jellyfin: ausente,
/// placeholder (`.disc`) o con media real.
final seerrLibraryStatusProvider =
    FutureProvider.family<SeerrLibraryStatus, JellyfinTmdbLookup>((
      ref,
      args,
    ) async {
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      if (client == null || userId == null || args.title.trim().isEmpty) {
        return SeerrLibraryStatus.none;
      }
      try {
        final res = await client.getItemsApi().getItems(
          userId: userId,
          recursive: true,
          includeItemTypes: [args.kind],
          searchTerm: args.title.trim(),
          limit: 10,
          fields: const [
            ItemFields.providerIds,
            ItemFields.mediaSources,
            ItemFields.path,
          ],
          enableImages: false,
          enableUserData: false,
          enableTotalRecordCount: false,
        );
        final items = res.data?.items ?? const <BaseItemDto>[];
        final tmdb = '${args.tmdbId}';
        var foundPlaceholder = false;
        for (final it in items) {
          final ids = it.providerIds;
          if (ids == null) continue;
          var match = false;
          for (final e in ids.entries) {
            if (e.key.toLowerCase() == 'tmdb' && e.value == tmdb) {
              match = true;
              break;
            }
          }
          if (!match) continue;
          // Un título con media real prevalece sobre un stub del mismo título.
          if (isPlaceholderItem(it)) {
            foundPlaceholder = true;
            continue;
          }
          return SeerrLibraryStatus.available;
        }
        return foundPlaceholder
            ? SeerrLibraryStatus.placeholder
            : SeerrLibraryStatus.none;
      } catch (_) {
        return SeerrLibraryStatus.none;
      }
    });

/// Datos necesarios para los logos de una tarjeta de Descubrir/Buscar.
/// Los listados de Seerr no incluyen proveedores, por lo que se consulta la
/// ficha una vez por título y se combina con el estado de Jellyfin.
final seerrCardMetadataProvider =
    FutureProvider.family<SeerrCardMetadata, SeerrCardRef>((ref, args) async {
      final detail = await ref.watch(
        seerrDetailProvider(
          (mediaType: args.mediaType, tmdbId: args.tmdbId),
        ).future,
      );
      final status = await ref.watch(
        seerrLibraryStatusProvider(
          (
            kind: args.mediaType == SeerrMediaType.movie
                ? BaseItemKind.movie
                : BaseItemKind.series,
            tmdbId: args.tmdbId,
            title: args.title,
          ),
        ).future,
      );
      return SeerrCardMetadata(
        providers: detail.watchProviders,
        libraryStatus: status,
      );
    });

/// Peticiones del usuario.
final seerrRequestsProvider = FutureProvider<List<SeerrRequest>>((ref) async {
  final api = ref.watch(seerrApiProvider);
  if (api == null) return const [];
  try {
    return await api.requests();
  } catch (_) {
    return const [];
  }
});
