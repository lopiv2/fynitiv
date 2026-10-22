import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/skin/home_scroll.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/seerr_providers.dart';
import '../../domain/seerr_models.dart';
import 'seerr_content_row.dart';

/// Fila de descubrimiento de Seerr: delega en [SeerrContentRow] (mismo look,
/// hover, foco y tamaños del skin que el resto de scrolls). Los items de TMDB
/// se mapean a `BaseItemDto` y su imagen se resuelve con una URL de TMDB.
class SeerrMediaRow extends ConsumerWidget {
  const SeerrMediaRow({
    super.key,
    required this.category,
    this.scroll,
  });

  final SeerrDiscoverCategory category;

  /// Config opcional de la sección (`LayoutSection.seerrDiscover`), para
  /// personalizar el aspecto (p. ej. póster/backdrop) por skin.
  final HomeScroll? scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(seerrDiscoverProvider(category));
    final skin = ref.watch(skinControllerProvider).value;
    final cfg = scroll;
    final useBackdrop = cfg?.cardType == HomeScrollCardType.backdrop
        ? true
        : cfg?.cardType == HomeScrollCardType.poster
        ? false
        : seerrUseBackdrop(skin);
    final title = _title(l10n, category);

    return items.when(
      data: (values) {
        if (values.isEmpty) return const SizedBox.shrink();
        final byId = <String, SeerrMedia>{
          for (final v in values) seerrMediaId(v): v,
        };
        final metadata = <String, SeerrCardMetadata>{};
        for (final value in values) {
          final state = ref.watch(
            seerrCardMetadataProvider(
              (
                mediaType: value.mediaType,
                tmdbId: value.tmdbId,
                title: value.title,
              ),
            ),
          );
          final data = state.value;
          if (data != null) metadata[seerrMediaId(value)] = data;
        }
        final urls = <String, String?>{
          for (final v in values)
            seerrMediaId(v): useBackdrop ? v.backdropUrl() : v.posterUrl(),
        };
        return SeerrContentRow(
          title: title,
          items: values.map(seerrMediaToBaseItem).toList(),
          useBackdrop: useBackdrop,
          hoverActionLabel: l10n.seerrRequest,
          onItemTap: (it) => _open(context, byId[it.id]),
          imageUrlFor: (it) => urls[it.id],
          cardLogoFor: (it) {
            final data = metadata[it.id];
            final hasProviderLogo = data?.providers.any(
                  (provider) => provider.logoUrl() != null,
                ) ??
                false;
            return hasProviderLogo ||
                    data?.libraryStatus != SeerrLibraryStatus.available
                ? null
                : skin?.cardLogo ?? 'assets/images/jellyfin.png';
          },
          cornerLogosFor: (it) => [
            for (final logo in (metadata[it.id]?.providers ?? const [])
                .map((provider) => provider.logoUrl())
                .whereType<String>())
              logo,
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(top: kBetweenSectionsGap, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 100, child: Center(child: AppLoader())),
          ],
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  static String _title(AppLocalizations l10n, SeerrDiscoverCategory c) {
    switch (c) {
      case SeerrDiscoverCategory.trending:
        return l10n.seerrTrending;
      case SeerrDiscoverCategory.popularMovies:
        return l10n.seerrPopularMovies;
      case SeerrDiscoverCategory.upcomingMovies:
        return l10n.seerrUpcomingMovies;
      case SeerrDiscoverCategory.popularTv:
        return l10n.seerrPopularTv;
      case SeerrDiscoverCategory.upcomingTv:
        return l10n.seerrUpcomingTv;
    }
  }

  void _open(BuildContext context, SeerrMedia? m) {
    if (m == null) return;
    context.push('/seerr/${m.mediaType.value}/${m.tmdbId}');
  }
}
