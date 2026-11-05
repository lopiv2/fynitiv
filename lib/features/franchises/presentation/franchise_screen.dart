import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/navigation/play_routing.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/image_url.dart';
import '../../library/application/library_providers.dart';
import '../../seerr/application/seerr_providers.dart';
import '../../seerr/domain/seerr_models.dart';
import '../../seerr/presentation/widgets/seerr_poster_grid.dart';
import '../application/franchise_providers.dart';

/// Pantalla de una franquicia curada: sus títulos en el orden del catálogo,
/// con las películas que tienes y las que faltan (pedibles desde Seerr).
class FranchiseScreen extends ConsumerWidget {
  const FranchiseScreen({super.key, required this.franchiseId});

  final String franchiseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final serverUrl = ref.watch(authServerUrlProvider);
    final language = Localizations.localeOf(context).languageCode;
    final catalog = ref.watch(franchiseCatalogProvider).value;
    final franchise = catalog?.byId(franchiseId);
    final entriesAsync = ref.watch(franchiseEntriesProvider(franchiseId));
    final entries = entriesAsync.value ?? const <FranchiseEntry>[];
    final owned = entries.where((e) => e.isOwned).length;

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: libraryPageTopPadding(context, skin)),
            LibraryPageHeader(
              title: franchise?.nameFor(language) ?? l10n.franchises,
              subtitle: entries.isEmpty
                  ? null
                  : l10n.franchiseProgress(owned, entries.length),
            ),
            Expanded(
              child: entriesAsync.isLoading && entries.isEmpty
                  ? const Center(child: AppLoader())
                  : entries.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noResults,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : SeerrPosterGrid(
                      entries: [
                        for (final entry in entries)
                          _gridEntry(
                            context,
                            l10n,
                            serverUrl,
                            language,
                            entry,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  SeerrPosterGridEntry _gridEntry(
    BuildContext context,
    AppLocalizations l10n,
    String? serverUrl,
    String language,
    FranchiseEntry entry,
  ) {
    final owned = entry.owned;
    if (owned != null) {
      return SeerrPosterGridEntry(
        item: owned,
        imageUrl: serverUrl == null ? null : itemImageUrl(serverUrl, owned),
        hoverActionLabel: l10n.details,
        onTap: () => pushDetailForType(context, owned),
      );
    }

    final external = entry.external;
    final media =
        external ??
        SeerrMedia(
          tmdbId: entry.item.tmdbId,
          mediaType: entry.item.type,
          title: entry.item.titleFor(language),
          date: entry.item.year?.toString(),
        );
    return SeerrPosterGridEntry(
      item: seerrMediaToBaseItem(media),
      imageUrl: media.posterUrl(),
      hoverActionLabel: l10n.seerrRequest,
      cornerBadge: _MissingBadge(label: l10n.notInLibrary),
      onTap: () =>
          context.push('/seerr/${media.mediaType.value}/${media.tmdbId}'),
    );
  }
}

/// Badge de esquina para los títulos que aún no están en Jellyfin.
class _MissingBadge extends StatelessWidget {
  const _MissingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
