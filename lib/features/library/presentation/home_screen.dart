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
    final nextUp = ref.watch(nextUpEpisodesProvider);
    final latest = ref.watch(latestItemsProvider);
    final latestBanner = ref.watch(latestBannerItemsProvider);
    final views = ref.watch(userViewsProvider);
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
    // "A continuación" solo debe mostrar siguientes capítulos de series sin
    // progreso (no resumables). Filtra episodios a medio ver / películas.
    final nextUpFiltered = (nextUp.value ?? const <BaseItemDto>[]).where((e) {
      if (e.type != BaseItemKind.episode) return false;
      final pct = e.userData?.playedPercentage ?? 0;
      final ticks = e.userData?.playbackPositionTicks ?? 0;
      return pct <= 0 && ticks <= 0;
    }).toList();

    // Carga inicial: mientras los datos principales no tienen contenido y se
    // están resolviendo, se muestra un loader.
    final initialLoading =
        (views.isLoading && views.value == null) ||
        (resume.isLoading && resume.value == null) ||
        (nextUp.isLoading && nextUp.value == null) ||
        (latest.isLoading && latest.value == null) ||
        (latestBanner.isLoading && latestBanner.value == null);

    // --- RowSpacing doble backdrop->poster ---
    final List<bool> visibleBackdrops = [];
    bool isBackdropForContinue([HomeScroll? cfg]) {
      final src = cfg?.imageSource;
      if (src == RowImageSource.primary) return false;
      if (src != null) return true;
      return useBackdrop;
    }

    if ((skin?.showContinueRow ?? true) && (resume.value ?? []).isNotEmpty) {
      visibleBackdrops.add(isBackdropForContinue());
    }
    if (nextUpFiltered.isNotEmpty) visibleBackdrops.add(useBackdrop);
    for (final type in const [
      CollectionType.music,
      CollectionType.movies,
      CollectionType.tvshows,
      CollectionType.books,
    ]) {
      for (final view in (views.value ?? const <BaseItemDto>[]).where(
        (v) => v.collectionType == type,
      )) {
        final items =
            ref.watch(recentLibraryItemsProvider(view.id ?? '')).value ??
            const [];
        if (items.isEmpty) continue;
        visibleBackdrops.add(useBackdrop);
      }
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
    bool isNextPosterFor(bool currentIsBackdrop) {
      if (rowCursor >= visibleBackdrops.length) return false;
      final nextIdx = rowCursor + 1;
      final res =
          currentIsBackdrop &&
          nextIdx < visibleBackdrops.length &&
          !visibleBackdrops[nextIdx];
      return res;
    }

    // Tap según el scroll: detalle o reproducción directa (default).
    void Function(BaseItemDto) tapFor(HomeScroll? cfg) {
      if (cfg?.tapAction == HomeScrollTapAction.details) {
        return (item) =>
            context.push('/home/details/${item.id}', extra: item);
      }
      return (item) => context.push('/player/${item.id}', extra: item);
    }

    Widget buildContinueRow([HomeScroll? cfg]) {
      final isBack = isBackdropForContinue(cfg);
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

    Widget buildUpNextRow([HomeScroll? cfg]) {
      final isBack = cfg?.cardType == HomeScrollCardType.backdrop
          ? true
          : cfg?.cardType == HomeScrollCardType.poster
              ? false
              : isBackdropForContinue(cfg);
      final isNextPoster = isNextPosterFor(isBack);
      final hasNext = rowCursor < visibleBackdrops.length - 1;
      final w = ContentRow(
        title: l10n.upNext,
        items: nextUpFiltered,
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

    final hasCustomLayout = (skin?.homeLayout.isNotEmpty ?? false);

    // Helper para construir FeaturedSlider reutilizable
    Widget buildFeaturedSlider() => FeaturedSlider(
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

    // --- Construcción ordenable ---
    // Si homeLayout está definido, se respeta exactamente el orden del array de arriba a abajo.
    // Cada entrada puede ser built-in (featuredSlider, continueWatching, nextUp, recent, newReleases)
    // o custom(HomeScroll) con poster/backdrop y viñeta configurables. Esto permite
    // máxima personalización por skin sin asumir que ciertos scrolls siempre aparecen.
    // Si está vacío, fallback al orden legado para compatibilidad.
    List<Widget> buildLegacyChildren() {
      // Reset cursor para el cálculo de rowSpacing doble backdrop→poster
      rowCursor = 0;
      return [
        if (showBanner && (latestBanner.value?.isNotEmpty ?? false))
          buildFeaturedSlider(),
        if ((skin?.showContinueRow ?? true) && (resume.value ?? []).isNotEmpty)
          buildContinueRow(),
        if (nextUpFiltered.isNotEmpty) buildUpNextRow(),
        for (final type in const [
          CollectionType.music,
          CollectionType.movies,
          CollectionType.tvshows,
          CollectionType.books,
        ])
          for (final view in (views.value ?? const <BaseItemDto>[]).where(
            (v) => v.collectionType == type,
          ))
            Builder(
              builder: (context) {
                final items =
                    ref
                        .watch(recentLibraryItemsProvider(view.id ?? ''))
                        .value ??
                    const [];
                if (items.isEmpty) return const SizedBox.shrink();
                final isBack = useBackdrop;
                final isNextPoster = isNextPosterFor(isBack);
                final hasNext = rowCursor < visibleBackdrops.length - 1;
                // Filas de Series: póster de la serie y tap al detalle de la
                // serie (los capítulos se ven en Continuar viendo).
                final isSeriesView =
                    view.collectionType == CollectionType.tvshows;
                void goSeriesDetail(BaseItemDto item) {
                  final target = seriesDetailTarget(item);
                  context.push('/home/details/${target.id}', extra: target);
                }

                final w = ContentRow(
                  title: l10n.recentIn(view.name ?? ''),
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
                  onSeeMore: () =>
                      context.push('/library/${view.id}', extra: view.name),
                  onItemTap: isSeriesView
                      ? goSeriesDetail
                      : (item) =>
                            context.push('/player/${item.id}', extra: item),
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
                hasNext: rowCursor < visibleBackdrops.length - 1,
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

    List<Widget> buildCustomChildren() {
      // Recalcular visibleBackdrops según el orden custom para rowSpacing
      final List<bool> customBackdrops = [];
      // Vistas ya emitidas por una entrada recent anterior (si dos entradas
      // solapan colecciones, gana la primera para no duplicar filas).
      final consumedViews = <String>{};
      for (final section in skin!.homeLayout) {
        switch (section.type) {
          case HomeSectionType.continueWatching:
            if ((resume.value ?? []).isEmpty) break;
            customBackdrops.add(isBackdropForContinue(section.scroll));
            break;
          case HomeSectionType.nextUp:
            if (nextUpFiltered.isEmpty) break;
            customBackdrops.add(useBackdrop);
            break;
          case HomeSectionType.recent:
            final recentSort = section.scroll?.sort;
            for (final view in views.value ?? const <BaseItemDto>[]) {
              if (![
                CollectionType.music,
                CollectionType.movies,
                CollectionType.tvshows,
                CollectionType.books,
              ].any((t) => view.collectionType == t)) {
                continue;
              }
              if (!section.matchesView(view.collectionType)) continue;
              final viewId = view.id ?? '';
              if (viewId.isEmpty || !consumedViews.add(viewId)) continue;
              final items = recentSort == null
                  ? ref.watch(recentLibraryItemsProvider(viewId)).value ??
                        const []
                  : ref.watch(recentRowItemsProvider((viewId, recentSort))).value ??
                        const [];
              if (items.isEmpty) continue;
              customBackdrops.add(useBackdrop);
            }
            break;
          case HomeSectionType.newReleases:
            if ((latest.value ?? []).isEmpty) break;
            customBackdrops.add(useBackdrop);
            break;
          case HomeSectionType.custom:
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
          case HomeSectionType.featuredSlider:
            break;
        }
      }
      // Reemplazar global para isNextPosterFor
      visibleBackdrops
        ..clear()
        ..addAll(customBackdrops);
      rowCursor = 0;
      final List<Widget> out = [];
      final builtViews = <String>{};
      for (final section in skin.homeLayout) {
        switch (section.type) {
          case HomeSectionType.featuredSlider:
            if (showBanner && (latestBanner.value?.isNotEmpty ?? false)) {
              out.add(buildFeaturedSlider());
            }
            break;
          case HomeSectionType.continueWatching:
            if ((resume.value ?? []).isEmpty) break;
            out.add(buildContinueRow(section.scroll));
            break;
          case HomeSectionType.nextUp:
            if (nextUpFiltered.isEmpty) break;
            out.add(buildUpNextRow(section.scroll));
            break;
          case HomeSectionType.recent:
            final recentScroll = section.scroll;
            final useRecentBackdrop = recentScroll?.cardType ==
                    HomeScrollCardType.backdrop
                ? true
                : recentScroll?.cardType == HomeScrollCardType.poster
                    ? false
                    : useBackdrop;
            for (final type in const [
              CollectionType.music,
              CollectionType.movies,
              CollectionType.tvshows,
              CollectionType.books,
            ]) {
              for (final view in (views.value ?? const <BaseItemDto>[]).where(
                (v) => v.collectionType == type,
              )) {
                if (!section.matchesView(view.collectionType)) continue;
                final viewId = view.id ?? '';
                if (viewId.isEmpty || !builtViews.add(viewId)) continue;
                out.add(
                  Builder(
                    builder: (context) {
                      final recentSort = section.scroll?.sort;
                      final items = recentSort == null
                          ? ref.watch(recentLibraryItemsProvider(viewId)).value ??
                                const []
                          : ref
                                    .watch(
                                      recentRowItemsProvider(
                                        (viewId, recentSort),
                                      ),
                                    )
                                    .value ??
                                const [];
                      if (items.isEmpty) return const SizedBox.shrink();
                      final isBack = useRecentBackdrop;
                      final isNextPoster = isNextPosterFor(isBack);
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
                        title: l10n.recentIn(view.name ?? ''),
                        items: items,
                        serverUrl: serverUrl,
                        height: rowHeight,
                        cardWidth: cardWidth,
                        itemSpacing: skin.itemSpacing,
                        useBackdrop: isBack,
                        cardLogo: skin.cardLogo,
                        useSeriesPoster: isSeriesView,
                        showBottomVignette:
                            recentScroll?.bottomVignette ?? false,
                        bottomVignetteHeight:
                            recentScroll?.bottomVignetteHeight ?? 56,
                        bottomVignetteOpacity:
                            recentScroll?.bottomVignetteOpacity ?? 0.72,
                        showMetaOverlay: recentScroll?.metaOverlay ?? false,
                        imageSource: recentScroll?.imageSource,
                        showNewBadge: recentScroll?.showNewBadge ?? false,
                        showStackLogo: recentScroll?.showLogo ?? false,
                        logoPosition:
                            recentScroll?.logoPosition ?? RowLogoPosition.top,
                        metaAlignment:
                            recentScroll?.metaAlignment ?? RowMetaAlign.left,
                        logoSize: recentScroll?.logoSize,
                        hideTitle: recentScroll?.hideTitle ?? false,
                        hideYear: recentScroll?.hideYear ?? false,
                        showHoverOverlay:
                            recentScroll?.showHoverOverlay ?? true,
                        cardBorderRadius: recentScroll?.cardBorderRadius,
                        hoverScale: recentScroll?.hoverScale,
                        isNextPoster: isNextPoster,
                        hasNext: rowCursor < visibleBackdrops.length - 1,
                        onSeeMore: (recentScroll?.showSeeMore ?? true)
                            ? () => context.push(
                                  '/library/${view.id}',
                                  extra: view.name,
                                )
                            : null,
                        onItemTap: isSeriesView
                            ? goSeriesDetail
                            : tapFor(section.scroll),
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
            }
            break;
          case HomeSectionType.newReleases:
            if ((latest.value ?? []).isEmpty) break;
            final newReleasesScroll = section.scroll;
            final useNewReleasesBackdrop =
                newReleasesScroll?.cardType == HomeScrollCardType.backdrop
                    ? true
                    : newReleasesScroll?.cardType == HomeScrollCardType.poster
                        ? false
                        : isBackdropForContinue(newReleasesScroll);
            out.add(
              Builder(
                builder: (context) {
                  final items = latest.value ?? const [];
                  if (items.isEmpty) return const SizedBox.shrink();
                  final isBack = useNewReleasesBackdrop;
                  final isNextPoster = isNextPosterFor(isBack);
                  final w = ContentRow(
                    title: l10n.newReleases,
                    items: items,
                    serverUrl: serverUrl,
                    height: rowHeight,
                    cardWidth: cardWidth,
                    itemSpacing: skin.itemSpacing,
                    useBackdrop: isBack,
                    cardLogo: skin.cardLogo,
                    showBottomVignette:
                        newReleasesScroll?.bottomVignette ?? false,
                    bottomVignetteHeight:
                        newReleasesScroll?.bottomVignetteHeight ?? 56,
                    bottomVignetteOpacity:
                        newReleasesScroll?.bottomVignetteOpacity ?? 0.72,
                    showMetaOverlay: newReleasesScroll?.metaOverlay ?? false,
                    imageSource: newReleasesScroll?.imageSource,
                    showNewBadge: newReleasesScroll?.showNewBadge ?? false,
                    showStackLogo: newReleasesScroll?.showLogo ?? false,
                    logoPosition:
                        newReleasesScroll?.logoPosition ?? RowLogoPosition.top,
                    metaAlignment:
                        newReleasesScroll?.metaAlignment ?? RowMetaAlign.left,
                    logoSize: newReleasesScroll?.logoSize,
                    hideTitle: newReleasesScroll?.hideTitle ?? false,
                    hideYear: newReleasesScroll?.hideYear ?? false,
                    showHoverOverlay:
                        newReleasesScroll?.showHoverOverlay ?? true,
                    cardBorderRadius: newReleasesScroll?.cardBorderRadius,
                    hoverScale: newReleasesScroll?.hoverScale,
                    isNextPoster: isNextPoster,
                    hasNext: rowCursor < visibleBackdrops.length - 1,
                    onItemTap: tapFor(newReleasesScroll),
                    onItemImageTap: (item) =>
                        context.push('/home/details/${item.id}', extra: item),
                  );
                  rowCursor++;
                  return w;
                },
              ),
            );
            break;
          case HomeSectionType.custom:
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
                    hasNext: rowCursor < visibleBackdrops.length - 1,
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
            : FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: ListView(
                  padding: EdgeInsets.only(
                    top: bannerAttached ? 0 : 54,
                    bottom: 24,
                  ),
                  children: hasCustomLayout
                      ? buildCustomChildren()
                      : buildLegacyChildren(),
                ),
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
