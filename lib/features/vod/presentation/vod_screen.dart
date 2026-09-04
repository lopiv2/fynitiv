import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/navigation/platform_mode.dart';
import '../../../core/skin/home_scroll.dart';
import '../../../core/skin/layout_section.dart';
import '../../../core/skin/skin.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/widgets/content_row.dart';
import '../../library/presentation/widgets/featured_slider.dart';

/// VOD (Video On Demand): dashboard de películas y series a la carta, con el
/// mismo diseño que el home (banner + filas) usando los valores del skin.
class VodScreen extends ConsumerWidget {
  const VodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final resume = ref.watch(vodResumeProvider);
    final latest = ref.watch(vodLatestProvider);
    final latestBanner = ref.watch(vodLatestBannerProvider);
    final views = ref.watch(vodLibraryViewsProvider);
    final skin = ref.watch(skinControllerProvider).value;
    final platformMode = ref.watch(platformModeProvider).value;
    final showBanner = skin?.showNewReleasesBanner ?? false;
    final useBackdrop =
        (skin?.cardImageType ?? CardImageType.poster) == CardImageType.backdrop;
    final bannerAttached = showBanner && (skin?.bannerAttachedTop ?? false);
    final hoverReveal =
        (skin?.bannerHoverReveal ?? false) &&
        platformMode == PlatformMode.desktop;
    final cardScale = skin?.homeCardScale ?? 1.0;
    final cardWidth = (skin?.homeCardWidth ?? 150) * cardScale;
    final rowHeight = (skin?.homeRowHeight ?? 270) * cardScale;

    final initialLoading =
        (views.isLoading && views.value == null) ||
        (resume.isLoading && resume.value == null) ||
        (latest.isLoading && latest.value == null) ||
        (latestBanner.isLoading && latestBanner.value == null);

    final List<bool> visibleBackdrops = [];
    bool isBackForContinue([HomeScroll? cfg]) {
      final src = cfg?.imageSource;
      if (src == RowImageSource.primary) return false;
      if (src != null) return true;
      return useBackdrop;
    }

    if ((skin?.showContinueRow ?? true) && (resume.value ?? []).isNotEmpty) {
      visibleBackdrops.add(isBackForContinue());
    }
    if (!showBanner &&
        (skin?.showNewReleasesRow ?? true) &&
        (latest.value ?? []).isNotEmpty) {
      visibleBackdrops.add(useBackdrop);
    }
    for (final view in views.value ?? const <BaseItemDto>[]) {
      final items =
          ref.watch(libraryItemsProvider(view.id ?? '')).value ?? const [];
      if (items.isEmpty) continue;
      visibleBackdrops.add(useBackdrop);
    }
    for (final scroll in skin?.homeScrolls ?? const <HomeScroll>[]) {
      final items =
          ref.watch(homeScrollItemsProvider(scroll)).value ?? const [];
      if (items.isEmpty) continue;
      final isBack = scroll.cardType == HomeScrollCardType.backdrop
          ? true
          : scroll.cardType == HomeScrollCardType.poster
          ? false
          : useBackdrop;
      visibleBackdrops.add(isBack);
    }
    int rowCursor = 0;
    bool isNextPosterFor(bool cur) {
      if (rowCursor >= visibleBackdrops.length) return false;
      final nextIdx = rowCursor + 1;
      return cur &&
          nextIdx < visibleBackdrops.length &&
          !visibleBackdrops[nextIdx];
    }

    Widget buildContinueRow2([HomeScroll? cfg]) {
      final isBack = isBackForContinue(cfg);
      final isNextPoster = isNextPosterFor(isBack);
      final hasNext = rowCursor < visibleBackdrops.length - 1;
      final w = ContentRow(
        title: l10n.continueWatching,
        items: resume.value ?? const [],
        serverUrl: serverUrl,
        height: rowHeight,
        cardWidth: cardWidth,
        itemSpacing: skin?.itemSpacing,
        useBackdrop: isBack,
        cardLogo: skin?.cardLogo,
        showBottomVignette: cfg?.bottomVignette ?? false,
        showMetaOverlay: cfg?.metaOverlay ?? false,
        imageSource: cfg?.imageSource,
        showNewBadge: cfg?.showNewBadge ?? false,
        showStackLogo: cfg?.showLogo ?? false,
        logoPosition: cfg?.logoPosition ?? RowLogoPosition.top,
        hideTitle: cfg?.hideTitle ?? false,
        hideYear: cfg?.hideYear ?? false,
        isNextPoster: isNextPoster,
        hasNext: hasNext,
        onItemTap: (item) => context.push('/player/${item.id}', extra: item),
        onItemImageTap: (item) =>
            context.push('/home/details/${item.id}', extra: item),
      );
      rowCursor++;
      return w;
    }

    Widget buildNewReleasesRow() {
      final isBack = useBackdrop;
      final isNextPoster = isNextPosterFor(isBack);
      final w = ContentRow(
        title: l10n.newReleases,
        items: latest.value ?? const [],
        serverUrl: serverUrl,
        height: rowHeight,
        cardWidth: cardWidth,
        itemSpacing: skin?.itemSpacing,
        useBackdrop: isBack,
        cardLogo: skin?.cardLogo,
        isNextPoster: isNextPoster,
        onItemTap: (item) => context.push('/player/${item.id}', extra: item),
        onItemImageTap: (item) =>
            context.push('/home/details/${item.id}', extra: item),
      );
      rowCursor++;
      return w;
    }

    final hasCustomVodLayout = (skin?.vodLayout.isNotEmpty ?? false);
    Widget buildFeaturedSliderVod() => FeaturedSlider(
      title: l10n.newReleases,
      items: latestBanner.value ?? const [],
      serverUrl: serverUrl,
      showTitle: skin?.bannerShowTitle ?? true,
      showAgeRating: skin?.bannerShowAgeRating ?? false,
      contentScale: skin?.bannerContentScale ?? 1.0,
      showBorder: skin?.bannerBorder ?? false,
      borderColor: skin?.bannerBorderColor ?? Colors.white,
      borderWidth: skin?.bannerBorderWidth ?? 1.5,
      hoverBorderWidth: skin?.bannerBorderHoverWidth ?? 2.5,
      showArrows: skin?.bannerShowArrows ?? false,
      showIncludedBadge: skin?.bannerShowIncludedBadge ?? false,
      showJellyfinLogo: skin?.bannerShowJellyfinLogo ?? false,
      hoverReveal: hoverReveal,
      showActions: skin?.bannerShowActions ?? false,
      showTrailer: skin?.showTrailerInSlider ?? false,
      transition: skin?.bannerTransition ?? SliderTransition.slide,
      arrowsOnHover: skin?.bannerArrowsOnHover ?? false,
      heightFactor: skin?.bannerHeightFactor ?? 0.38,
      maxHeight: skin?.bannerMaxHeight ?? 440,
      dotAlignment: skin?.bannerDotAlignment ?? SliderDotAlignment.right,
      dotsOutside: skin?.bannerDotsOutside ?? false,
      showNewBadge: skin?.bannerShowNewBadge ?? false,
      inlineMeta: skin?.bannerInlineMeta ?? false,
      logoWidthFactor:
          skin?.bannerLogoWidthFactor ?? FeaturedSlider.kDefaultLogoWidthFactor,
      logoMaxHeight:
          skin?.bannerLogoMaxHeight ?? FeaturedSlider.kDefaultLogoMaxHeight,
      horizontalPadding: skin?.bannerHorizontalPadding ?? 0,
      showShadow: skin?.bannerShadow ?? false,
      hoverScale: skin?.bannerHoverScale ?? 1.02,
      showVignette: skin?.bannerVignette ?? true,
    );

    List<Widget> buildLegacyVodChildren() {
      rowCursor = 0;
      return [
        if (showBanner && (latestBanner.value?.isNotEmpty ?? false))
          buildFeaturedSliderVod(),
        if ((skin?.showContinueRow ?? true) && (resume.value ?? []).isNotEmpty)
          buildContinueRow2(),
        if (!showBanner &&
            (skin?.showNewReleasesRow ?? true) &&
            (latest.value ?? []).isNotEmpty)
          buildNewReleasesRow(),
        for (final view in views.value ?? const <BaseItemDto>[])
          Builder(
            builder: (context) {
              final items =
                  ref.watch(libraryItemsProvider(view.id ?? '')).value ??
                  const [];
              if (items.isEmpty) return const SizedBox.shrink();
              final isBack = useBackdrop;
              final isNextPoster = isNextPosterFor(isBack);
              final hasNext = rowCursor < visibleBackdrops.length - 1;
              final w = ContentRow(
                title: view.name ?? '',
                items: items,
                serverUrl: serverUrl,
                height: rowHeight,
                cardWidth: cardWidth,
                itemSpacing: skin?.itemSpacing,
                useBackdrop: isBack,
                cardLogo: skin?.cardLogo,
                isNextPoster: isNextPoster,
                hasNext: hasNext,
                onSeeMore: () => context.push('/library/${view.id}'),
                onItemTap: (item) =>
                    context.push('/player/${item.id}', extra: item),
                onItemImageTap: (item) =>
                    context.push('/home/details/${item.id}', extra: item),
              );
              rowCursor++;
              return w;
            },
          ),
        for (final scroll in skin?.homeScrolls ?? const <HomeScroll>[])
          Builder(
            builder: (context) {
              final items =
                  ref.watch(homeScrollItemsProvider(scroll)).value ?? const [];
              if (items.isEmpty) return const SizedBox.shrink();
              final isBack = scroll.cardType == HomeScrollCardType.backdrop
                  ? true
                  : scroll.cardType == HomeScrollCardType.poster
                  ? false
                  : useBackdrop;
              final isNextPoster = isNextPosterFor(isBack);
              final hasNext = rowCursor < visibleBackdrops.length - 1;
              final w = ContentRow(
                title: _scrollTitle(l10n, scroll.titleKey),
                items: items,
                serverUrl: serverUrl,
                height: rowHeight,
                cardWidth: cardWidth,
                itemSpacing: skin?.itemSpacing,
                useBackdrop: isBack,
                cardLogo: skin?.cardLogo,
                showBottomVignette: scroll.bottomVignette,
                imageSource: scroll.imageSource,
                hideTitle: scroll.hideTitle,
                hideYear: scroll.hideYear,
                bottomVignetteHeight: scroll.bottomVignetteHeight,
                bottomVignetteOpacity: scroll.bottomVignetteOpacity,
                isNextPoster: isNextPoster,
                hasNext: hasNext,
                onSeeMore: () {
                  final allViews = views.value ?? const <BaseItemDto>[];
                  String targetViewId = '';
                  for (final kind in scroll.types) {
                    final mapped = _collectionTypeForKind(kind);
                    final match = allViews
                        .where((v) => v.collectionType == mapped)
                        .firstOrNull;
                    if (match?.id != null) {
                      targetViewId = match!.id!;
                      break;
                    }
                  }
                  targetViewId = targetViewId.isEmpty
                      ? (allViews
                                .where(
                                  (v) =>
                                      v.collectionType == CollectionType.movies,
                                )
                                .firstOrNull
                                ?.id ??
                            allViews.firstOrNull?.id ??
                            '')
                      : targetViewId;
                  if (targetViewId.isEmpty) {
                    context.push('/movies');
                    return;
                  }
                  context.push('/library/$targetViewId', extra: scroll);
                },
                onItemTap: (item) =>
                    context.push('/player/${item.id}', extra: item),
                onItemImageTap: (item) =>
                    context.push('/home/details/${item.id}', extra: item),
              );
              rowCursor++;
              return w;
            },
          ),
        const SizedBox(height: 24),
      ];
    }

    List<Widget> buildCustomVodChildren() {
      // Calcular visibleBackdrops según vodLayout ordenado (similar a Home)
      final List<bool> customBackdrops = [];
      for (final section in skin!.vodLayout) {
        switch (section.type) {
          case VodSectionType.continueWatching:
            if ((resume.value ?? []).isEmpty) break;
            customBackdrops.add(isBackForContinue(section.scroll));
            break;
          case VodSectionType.newReleases:
            if ((latest.value ?? []).isEmpty) break;
            customBackdrops.add(useBackdrop);
            break;
          case VodSectionType.library:
            for (final view in views.value ?? const <BaseItemDto>[]) {
              final items =
                  ref.watch(libraryItemsProvider(view.id ?? '')).value ??
                  const [];
              if (items.isEmpty) continue;
              customBackdrops.add(useBackdrop);
            }
            break;
          case VodSectionType.custom:
            final s = section.scroll!;
            final items =
                ref.watch(homeScrollItemsProvider(s)).value ?? const [];
            if (items.isEmpty) break;
            final isBack = s.cardType == HomeScrollCardType.backdrop
                ? true
                : s.cardType == HomeScrollCardType.poster
                ? false
                : useBackdrop;
            customBackdrops.add(isBack);
            break;
          case VodSectionType.featuredSlider:
            break;
        }
      }
      visibleBackdrops
        ..clear()
        ..addAll(customBackdrops);
      rowCursor = 0;
      final List<Widget> out = [];
      for (final section in skin.vodLayout) {
        switch (section.type) {
          case VodSectionType.featuredSlider:
            if (showBanner && (latestBanner.value?.isNotEmpty ?? false)) {
              out.add(buildFeaturedSliderVod());
            }
            break;
          case VodSectionType.continueWatching:
            if ((resume.value ?? []).isEmpty) break;
            out.add(buildContinueRow2(section.scroll));
            break;
          case VodSectionType.newReleases:
            if ((latest.value ?? []).isEmpty) break;
            out.add(buildNewReleasesRow());
            break;
          case VodSectionType.library:
            for (final view in views.value ?? const <BaseItemDto>[]) {
              out.add(
                Builder(
                  builder: (context) {
                    final items =
                        ref.watch(libraryItemsProvider(view.id ?? '')).value ??
                        const [];
                    if (items.isEmpty) return const SizedBox.shrink();
                    final isBack = useBackdrop;
                    final isNextPoster = isNextPosterFor(isBack);
                    final hasNext = rowCursor < visibleBackdrops.length - 1;
                    final w = ContentRow(
                      title: view.name ?? '',
                      items: items,
                      serverUrl: serverUrl,
                      height: rowHeight,
                      cardWidth: cardWidth,
                      itemSpacing: skin.itemSpacing,
                      useBackdrop: isBack,
                      cardLogo: skin.cardLogo,
                      isNextPoster: isNextPoster,
                      hasNext: hasNext,
                      onSeeMore: () => context.push('/library/${view.id}'),
                      onItemTap: (item) =>
                          context.push('/player/${item.id}', extra: item),
                      onItemImageTap: (item) =>
                          context.push('/home/details/${item.id}', extra: item),
                    );
                    rowCursor++;
                    return w;
                  },
                ),
              );
            }
            break;
          case VodSectionType.custom:
            final s = section.scroll!;
            out.add(
              Builder(
                builder: (context) {
                  final items =
                      ref.watch(homeScrollItemsProvider(s)).value ?? const [];
                  if (items.isEmpty) return const SizedBox.shrink();
                  final isBack = s.cardType == HomeScrollCardType.backdrop
                      ? true
                      : s.cardType == HomeScrollCardType.poster
                      ? false
                      : useBackdrop;
                  final isNextPoster = isNextPosterFor(isBack);
                  final hasNext = rowCursor < visibleBackdrops.length - 1;
                  final w = ContentRow(
                    title: _scrollTitle(l10n, s.titleKey),
                    items: items,
                    serverUrl: serverUrl,
                    height: rowHeight,
                    cardWidth: cardWidth,
                    itemSpacing: skin.itemSpacing,
                    useBackdrop: isBack,
                    cardLogo: skin.cardLogo,
                    showBottomVignette: s.bottomVignette,
                    bottomVignetteHeight: s.bottomVignetteHeight,
                    bottomVignetteOpacity: s.bottomVignetteOpacity,
                    imageSource: s.imageSource,
                    hideTitle: s.hideTitle,
                    hideYear: s.hideYear,
                    isNextPoster: isNextPoster,
                    hasNext: hasNext,
                    onSeeMore: () {
                      final allViews = views.value ?? const <BaseItemDto>[];
                      String targetViewId = '';
                      for (final kind in s.types) {
                        final mapped = _collectionTypeForKind(kind);
                        final match = allViews
                            .where((v) => v.collectionType == mapped)
                            .firstOrNull;
                        if (match?.id != null) {
                          targetViewId = match!.id!;
                          break;
                        }
                      }
                      targetViewId = targetViewId.isEmpty
                          ? (allViews
                                    .where(
                                      (v) =>
                                          v.collectionType ==
                                          CollectionType.movies,
                                    )
                                    .firstOrNull
                                    ?.id ??
                                allViews.firstOrNull?.id ??
                                '')
                          : targetViewId;
                      if (targetViewId.isEmpty) {
                        context.push('/movies');
                        return;
                      }
                      context.push('/library/$targetViewId', extra: s);
                    },
                    onItemTap: (item) =>
                        context.push('/player/${item.id}', extra: item),
                    onItemImageTap: (item) =>
                        context.push('/home/details/${item.id}', extra: item),
                  );
                  rowCursor++;
                  return w;
                },
              ),
            );
            break;
        }
      }
      out.add(const SizedBox(height: 24));
      return out;
    }

    return Scaffold(
      body: DashboardBackground(
        child: initialLoading
            ? const Center(child: AppLoader())
            : ListView(
                padding: EdgeInsets.only(
                  top: bannerAttached ? 0 : 54,
                  bottom: 24,
                ),
                children: hasCustomVodLayout
                    ? buildCustomVodChildren()
                    : buildLegacyVodChildren(),
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

  static CollectionType? _collectionTypeForKind(BaseItemKind kind) {
    switch (kind) {
      case BaseItemKind.movie:
        return CollectionType.movies;
      case BaseItemKind.series:
        return CollectionType.tvshows;
      default:
        return null;
    }
  }
}
