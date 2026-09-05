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
    final nextUp = ref.watch(vodNextUpProvider);
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
        (nextUp.isLoading && nextUp.value == null) ||
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
    if ((nextUp.value ?? []).isNotEmpty) {
      visibleBackdrops.add(useBackdrop);
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

    // Tap según el scroll: detalle o reproducción directa (default).
    void Function(BaseItemDto) tapFor(HomeScroll? cfg) {
      if (cfg?.tapAction == HomeScrollTapAction.details) {
        return (item) =>
            context.push('/home/details/${item.id}', extra: item);
      }
      return (item) => context.push('/player/${item.id}', extra: item);
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
        metaAlignment: cfg?.metaAlignment ?? RowMetaAlign.left,
        logoSize: cfg?.logoSize,
        hideTitle: cfg?.hideTitle ?? false,
        hideYear: cfg?.hideYear ?? false,
        showHoverOverlay: cfg?.showHoverOverlay ?? true,
        cardBorderRadius: cfg?.cardBorderRadius,
        hoverScale: cfg?.hoverScale,
        isNextPoster: isNextPoster,
        hasNext: hasNext,
        onItemTap: tapFor(cfg),
        onItemImageTap: (item) =>
            context.push('/home/details/${item.id}', extra: item),
      );
      rowCursor++;
      return w;
    }

    Widget buildUpNextRow2([HomeScroll? cfg]) {
      final isBack = cfg?.cardType == HomeScrollCardType.backdrop
          ? true
          : cfg?.cardType == HomeScrollCardType.poster
              ? false
              : isBackForContinue(cfg);
      final isNextPoster = isNextPosterFor(isBack);
      final hasNext = rowCursor < visibleBackdrops.length - 1;
      final w = ContentRow(
        title: l10n.upNext,
        items: nextUp.value ?? const [],
        serverUrl: serverUrl,
        height: rowHeight,
        cardWidth: cardWidth,
        itemSpacing: skin?.itemSpacing,
        useBackdrop: isBack,
        cardLogo: skin?.cardLogo,
        showBottomVignette: cfg?.bottomVignette ?? false,
        bottomVignetteHeight: cfg?.bottomVignetteHeight ?? 56,
        bottomVignetteOpacity: cfg?.bottomVignetteOpacity ?? 0.72,
        showMetaOverlay: cfg?.metaOverlay ?? false,
        imageSource: cfg?.imageSource,
        showNewBadge: cfg?.showNewBadge ?? false,
        showStackLogo: cfg?.showLogo ?? false,
        logoPosition: cfg?.logoPosition ?? RowLogoPosition.top,
        metaAlignment: cfg?.metaAlignment ?? RowMetaAlign.left,
        logoSize: cfg?.logoSize,
        hideTitle: cfg?.hideTitle ?? false,
        hideYear: cfg?.hideYear ?? false,
        showHoverOverlay: cfg?.showHoverOverlay ?? true,
        cardBorderRadius: cfg?.cardBorderRadius,
        hoverScale: cfg?.hoverScale,
        isNextPoster: isNextPoster,
        hasNext: hasNext,
        onItemTap: tapFor(cfg),
        onItemImageTap: (item) =>
            context.push('/home/details/${item.id}', extra: item),
      );
      rowCursor++;
      return w;
    }

    Widget buildNewReleasesRow([HomeScroll? cfg]) {
      final isBack = cfg?.cardType == HomeScrollCardType.backdrop
          ? true
          : cfg?.cardType == HomeScrollCardType.poster
              ? false
              : isBackForContinue(cfg);
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
        showBottomVignette: cfg?.bottomVignette ?? false,
        bottomVignetteHeight: cfg?.bottomVignetteHeight ?? 56,
        bottomVignetteOpacity: cfg?.bottomVignetteOpacity ?? 0.72,
        showMetaOverlay: cfg?.metaOverlay ?? false,
        imageSource: cfg?.imageSource,
        showNewBadge: cfg?.showNewBadge ?? false,
        showStackLogo: cfg?.showLogo ?? false,
        logoPosition: cfg?.logoPosition ?? RowLogoPosition.top,
        metaAlignment: cfg?.metaAlignment ?? RowMetaAlign.left,
        logoSize: cfg?.logoSize,
        hideTitle: cfg?.hideTitle ?? false,
        hideYear: cfg?.hideYear ?? false,
        showHoverOverlay: cfg?.showHoverOverlay ?? true,
        cardBorderRadius: cfg?.cardBorderRadius,
        hoverScale: cfg?.hoverScale,
        isNextPoster: isNextPoster,
        onItemTap: tapFor(cfg),
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
      vignetteMode: skin?.bannerVignetteMode ?? SliderVignetteMode.around,
      vignetteOpacity: skin?.bannerVignetteOpacity ?? 1.0,
      vignetteSize: skin?.bannerVignetteSize ?? 160,
    );

    List<Widget> buildLegacyVodChildren() {
      rowCursor = 0;
      return [
        if (showBanner && (latestBanner.value?.isNotEmpty ?? false))
          buildFeaturedSliderVod(),
        if ((skin?.showContinueRow ?? true) && (resume.value ?? []).isNotEmpty)
          buildContinueRow2(),
        if ((nextUp.value ?? []).isNotEmpty) buildUpNextRow2(),
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
              final isSeriesView =
                  view.collectionType == CollectionType.tvshows;
              void goSeriesDetail(BaseItemDto item) {
                final target = seriesDetailTarget(item);
                context.push('/home/details/${target.id}', extra: target);
              }

              final w = ContentRow(
                title: view.name ?? '',
                items: items,
                serverUrl: serverUrl,
                height: rowHeight,
                cardWidth: cardWidth,
                itemSpacing: skin?.itemSpacing,
                useBackdrop: isBack,
                cardLogo: skin?.cardLogo,
                useSeriesPoster: isSeriesView,
                isNextPoster: isNextPoster,
                hasNext: hasNext,
                onSeeMore: () => context.push('/library/${view.id}'),
                onItemTap: isSeriesView
                    ? goSeriesDetail
                    : (item) =>
                          context.push('/player/${item.id}', extra: item),
                onItemImageTap: isSeriesView
                    ? goSeriesDetail
                    : (item) =>
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
                showMetaOverlay: scroll.metaOverlay,
                imageSource: scroll.imageSource,
                showNewBadge: scroll.showNewBadge,
                showStackLogo: scroll.showLogo,
                logoPosition: scroll.logoPosition,
                metaAlignment: scroll.metaAlignment,
                logoSize: scroll.logoSize,
                hideTitle: scroll.hideTitle,
                hideYear: scroll.hideYear,
                showHoverOverlay: scroll.showHoverOverlay,
                cardBorderRadius: scroll.cardBorderRadius,
                hoverScale: scroll.hoverScale,
                bottomVignetteHeight: scroll.bottomVignetteHeight,
                bottomVignetteOpacity: scroll.bottomVignetteOpacity,
                isNextPoster: isNextPoster,
                hasNext: hasNext,
                onSeeMore: scroll.showSeeMore
                    ? () {
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
                        context.push('/library/$targetViewId', extra: scroll);
                      }
                    : null,
                onItemTap: tapFor(scroll),
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
      // Vistas ya emitidas por una entrada library anterior (si dos entradas
      // solapan colecciones, gana la primera para no duplicar filas).
      final consumedViews = <String>{};
      for (final section in skin!.vodLayout) {
        switch (section.type) {
          case VodSectionType.continueWatching:
            if ((resume.value ?? []).isEmpty) break;
            customBackdrops.add(isBackForContinue(section.scroll));
            break;
          case VodSectionType.nextUp:
            if ((nextUp.value ?? []).isEmpty) break;
            customBackdrops.add(useBackdrop);
            break;
          case VodSectionType.newReleases:
            if ((latest.value ?? []).isEmpty) break;
            customBackdrops.add(useBackdrop);
            break;
          case VodSectionType.library:
            final librarySort = section.scroll?.sort;
            for (final view in views.value ?? const <BaseItemDto>[]) {
              if (!section.matchesView(view.collectionType)) continue;
              final viewId = view.id ?? '';
              if (viewId.isEmpty || !consumedViews.add(viewId)) continue;
              final items = librarySort == null
                  ? ref.watch(libraryItemsProvider(viewId)).value ?? const []
                  : ref.watch(libraryRowItemsProvider((viewId, librarySort))).value ??
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
      final builtViews = <String>{};
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
          case VodSectionType.nextUp:
            if ((nextUp.value ?? []).isEmpty) break;
            out.add(buildUpNextRow2(section.scroll));
            break;
          case VodSectionType.newReleases:
            if ((latest.value ?? []).isEmpty) break;
            out.add(buildNewReleasesRow(section.scroll));
            break;
          case VodSectionType.library:
            final libraryScroll = section.scroll;
            final useLibraryBackdrop = libraryScroll?.cardType ==
                    HomeScrollCardType.backdrop
                ? true
                : libraryScroll?.cardType == HomeScrollCardType.poster
                    ? false
                    : useBackdrop;
            for (final view in views.value ?? const <BaseItemDto>[]) {
              if (!section.matchesView(view.collectionType)) continue;
              final viewId = view.id ?? '';
              if (viewId.isEmpty || !builtViews.add(viewId)) continue;
              out.add(
                Builder(
                  builder: (context) {
                    final librarySort = section.scroll?.sort;
                    final items = librarySort == null
                        ? ref.watch(libraryItemsProvider(viewId)).value ??
                              const []
                        : ref
                                  .watch(
                                    libraryRowItemsProvider(
                                      (viewId, librarySort),
                                    ),
                                  )
                                  .value ??
                              const [];
                    if (items.isEmpty) return const SizedBox.shrink();
                    final isBack = useLibraryBackdrop;
                    final isNextPoster = isNextPosterFor(isBack);
                    final hasNext = rowCursor < visibleBackdrops.length - 1;
                    final isSeriesView =
                        view.collectionType == CollectionType.tvshows;
                    void goSeriesDetail(BaseItemDto item) {
                      final target = seriesDetailTarget(item);
                      context.push(
                        '/home/details/${target.id}',
                        extra: target,
                      );
                    }

                    final w = ContentRow(
                      title: view.name ?? '',
                      items: items,
                      serverUrl: serverUrl,
                      height: rowHeight,
                      cardWidth: cardWidth,
                      itemSpacing: skin.itemSpacing,
                      useBackdrop: isBack,
                      cardLogo: skin.cardLogo,
                      useSeriesPoster: isSeriesView,
                      showBottomVignette:
                          libraryScroll?.bottomVignette ?? false,
                      bottomVignetteHeight:
                          libraryScroll?.bottomVignetteHeight ?? 56,
                      bottomVignetteOpacity:
                          libraryScroll?.bottomVignetteOpacity ?? 0.72,
                      showMetaOverlay: libraryScroll?.metaOverlay ?? false,
                      imageSource: libraryScroll?.imageSource,
                      showNewBadge: libraryScroll?.showNewBadge ?? false,
                      showStackLogo: libraryScroll?.showLogo ?? false,
                      logoPosition:
                          libraryScroll?.logoPosition ?? RowLogoPosition.top,
                      metaAlignment:
                          libraryScroll?.metaAlignment ?? RowMetaAlign.left,
                      logoSize: libraryScroll?.logoSize,
                      hideTitle: libraryScroll?.hideTitle ?? false,
                      hideYear: libraryScroll?.hideYear ?? false,
                      showHoverOverlay:
                          libraryScroll?.showHoverOverlay ?? true,
                      cardBorderRadius: libraryScroll?.cardBorderRadius,
                      hoverScale: libraryScroll?.hoverScale,
                      isNextPoster: isNextPoster,
                      hasNext: hasNext,
                      onSeeMore: (libraryScroll?.showSeeMore ?? true)
                          ? () => context.push('/library/${view.id}')
                          : null,
                      onItemTap: isSeriesView
                          ? goSeriesDetail
                          : tapFor(libraryScroll),
                      onItemImageTap: isSeriesView
                          ? goSeriesDetail
                          : (item) => context.push(
                              '/home/details/${item.id}',
                              extra: item,
                            ),
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
                    showMetaOverlay: s.metaOverlay,
                    imageSource: s.imageSource,
                    showNewBadge: s.showNewBadge,
                    showStackLogo: s.showLogo,
                    logoPosition: s.logoPosition,
                    metaAlignment: s.metaAlignment,
                    logoSize: s.logoSize,
                    hideTitle: s.hideTitle,
                    hideYear: s.hideYear,
                    showHoverOverlay: s.showHoverOverlay,
                    cardBorderRadius: s.cardBorderRadius,
                    hoverScale: s.hoverScale,
                    isNextPoster: isNextPoster,
                    hasNext: hasNext,
                    onSeeMore: s.showSeeMore
                        ? () {
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
                          }
                        : null,
                    onItemTap: tapFor(s),
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

  /// Resuelve el título de una fila de contenido ([HomeScrollTitle]).
  static String _scrollTitle(AppLocalizations l10n, HomeScrollTitle key) =>
      HomeScrollTitle.resolve(l10n, key);

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
