import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/navigation/play_routing.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/library_providers.dart';
import '../../library/application/library_tmdb_index.dart';
import '../application/seerr_providers.dart';
import '../application/seerr_studios_providers.dart';
import '../domain/seerr_models.dart';
import 'widgets/seerr_poster_grid.dart';

/// Catálogo de un estudio desde Seerr: películas del estudio; al pulsar una
/// se abre su ficha de Seerr para pedirla.
class SeerrStudioScreen extends ConsumerWidget {
  const SeerrStudioScreen({super.key, required this.studioId, this.name});

  final int studioId;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final catalogAsync = ref.watch(seerrStudioCatalogProvider(studioId));
    final catalog = catalogAsync.value;
    final items = catalog?.items ?? const <SeerrMedia>[];
    final title = (name ?? catalog?.studio.name ?? '').trim();
    final index = ref.watch(libraryTmdbIndexProvider).value;

    List<SeerrPosterGridEntry> buildEntries() {
      final out = <SeerrPosterGridEntry>[];
      for (final media in items) {
        final type = media.mediaType == SeerrMediaType.movie
            ? TmdbMediaType.movie
            : TmdbMediaType.series;
        final real = index?[(type: type, tmdbId: media.tmdbId)];
        final available = real != null && !isPlaceholderItem(real);
        out.add(
          SeerrPosterGridEntry(
            item: seerrMediaToBaseItem(media),
            imageUrl: media.posterUrl(),
            hoverActionLabel: l10n.details,
            onTap: available
                ? () => pushDetailForType(context, real)
                : () => context.push(
                    '/seerr/${media.mediaType.value}/${media.tmdbId}',
                  ),
          ),
        );
      }
      return out;
    }

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: libraryPageTopPadding(context, skin)),
            LibraryPageHeader(
              title: title.isEmpty ? l10n.studios : title,
              subtitle: items.isEmpty
                  ? null
                  : l10n.libraryCountTitles(items.length),
            ),
            Expanded(
              child: catalogAsync.isLoading && items.isEmpty
                  ? const Center(child: AppLoader())
                  : items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.noResults,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => ref.invalidate(
                              seerrStudioCatalogProvider(studioId),
                            ),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                    )
                  : SeerrPosterGrid(entries: buildEntries()),
            ),
          ],
        ),
      ),
    );
  }
}
