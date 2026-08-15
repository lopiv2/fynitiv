import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/navigation/platform_mode.dart';
import '../../../core/skin/home_scroll.dart';
import '../../../core/skin/skin.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../application/library_providers.dart';
import 'widgets/content_row.dart';
import 'widgets/featured_slider.dart';

/// Dashboard de la app: filas de contenido tipo Prime/Disney.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final resume = ref.watch(resumeItemsProvider);
    final latest = ref.watch(latestItemsProvider);
    final latestBanner = ref.watch(latestBannerItemsProvider);
    final views = ref.watch(userViewsProvider);
    final skin = ref.watch(skinControllerProvider).value;
    final platformMode = ref.watch(platformModeProvider).value;
    final showBanner = skin?.showNewReleasesBanner ?? false;
    final useBackdrop =
        (skin?.cardImageType ?? CardImageType.poster) == CardImageType.backdrop;
    final bannerAttached =
        showBanner && (skin?.bannerAttachedTop ?? false);
    final hoverReveal =
        (skin?.bannerHoverReveal ?? false) && platformMode == PlatformMode.desktop;

    // Carga inicial: mientras los datos principales no tienen contenido y se
    // están resolviendo, se muestra un loader.
    final initialLoading =
        (views.isLoading && views.value == null) ||
        (resume.isLoading && resume.value == null) ||
        (latest.isLoading && latest.value == null) ||
        (latestBanner.isLoading && latestBanner.value == null);

    return Scaffold(
      body: DashboardBackground(
        child: initialLoading
            ? const Center(child: AppLoader())
            : ListView(
          padding: EdgeInsets.only(
            top: bannerAttached ? 0 : 54,
            bottom: 24,
          ),
          children: [
            if (showBanner && (latestBanner.value?.isNotEmpty ?? false))
              FeaturedSlider(
                title: l10n.newReleases,
                items: latestBanner.value ?? const [],
                serverUrl: serverUrl,
                showTitle: skin?.bannerShowTitle ?? true,
                showAgeRating: skin?.bannerShowAgeRating ?? false,
                contentScale: skin?.bannerContentScale ?? 1.0,
                showBorder: skin?.bannerBorder ?? false,
                showArrows: skin?.bannerShowArrows ?? false,
                showIncludedBadge: skin?.bannerShowIncludedBadge ?? false,
                showJellyfinLogo: skin?.bannerShowJellyfinLogo ?? false,
                hoverReveal: hoverReveal,
                showActions: skin?.bannerShowActions ?? false,
                showTrailer: skin?.showTrailerInSlider ?? false,
                transition:
                    skin?.bannerTransition ?? SliderTransition.slide,
                arrowsOnHover: skin?.bannerArrowsOnHover ?? false,
                heightFactor: skin?.bannerHeightFactor ?? 0.38,
                maxHeight: skin?.bannerMaxHeight ?? 440,
                dotAlignment:
                    skin?.bannerDotAlignment ?? SliderDotAlignment.right,
                logoWidthFactor:
                    skin?.bannerLogoWidthFactor ?? FeaturedSlider.kDefaultLogoWidthFactor,
              ),
            if (skin?.showContinueRow ?? true)
              ContentRow(
                title: l10n.continueWatching,
                items: resume.value ?? const [],
                serverUrl: serverUrl,
                height: skin?.homeRowHeight ?? 270,
                cardWidth: skin?.homeCardWidth ?? 150,
                useBackdrop: useBackdrop,
                cardLogo: skin?.cardLogo,
                onItemTap: (item) => context.push(
                  '/player/${item.id}',
                  extra: item,
                ),
              ),
            if (!showBanner && (skin?.showNewReleasesRow ?? true))
              ContentRow(
                title: l10n.newReleases,
                items: latest.value ?? const [],
                serverUrl: serverUrl,
                height: skin?.homeRowHeight ?? 270,
                cardWidth: skin?.homeCardWidth ?? 150,
                useBackdrop: useBackdrop,
                cardLogo: skin?.cardLogo,
                onItemTap: (item) => context.push(
                  '/player/${item.id}',
                  extra: item,
                ),
              ),
            for (final view in (views.value ?? const <BaseItemDto>[]).take(4))
              ContentRow(
                title: view.name ?? '',
                items:
                    ref.watch(libraryItemsProvider(view.id ?? '')).value ??
                    const [],
                serverUrl: serverUrl,
                height: skin?.homeRowHeight ?? 270,
                cardWidth: skin?.homeCardWidth ?? 150,
                useBackdrop: useBackdrop,
                cardLogo: skin?.cardLogo,
                onItemTap: (item) => context.push(
                  '/player/${item.id}',
                  extra: item,
                ),
              ),
            // Scrolls extra configurados por el skin (con filtros de géneros).
            for (final scroll in skin?.homeScrolls ?? const <HomeScroll>[])
              ContentRow(
                title: _scrollTitle(l10n, scroll.titleKey),
                items:
                    ref.watch(homeScrollItemsProvider(scroll)).value ?? const [],
                serverUrl: serverUrl,
                height: skin?.homeRowHeight ?? 270,
                cardWidth: skin?.homeCardWidth ?? 150,
                useBackdrop: useBackdrop,
                cardLogo: skin?.cardLogo,
                onSeeMore: () => context.push('/movies'),
                onItemTap: (item) => context.push(
                  '/player/${item.id}',
                  extra: item,
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Resuelve el título de una fila de contenido a partir de su clave de
  /// localización. Si la clave no es conocida, se muestra tal cual.
  static String _scrollTitle(AppLocalizations l10n, String key) {
    switch (key) {
      case 'actionMovies':
        return l10n.actionMovies;
      case 'familyMovies':
        return l10n.familyMovies;
      default:
        return key;
    }
  }
}
