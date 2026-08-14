import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/navigation/platform_mode.dart';
import '../../../core/skin/skin.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
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

    return Scaffold(
      body: DashboardBackground(
        child: ListView(
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
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
