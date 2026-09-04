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

    Widget buildUpNextRow() {
      final isBack = useBackdrop;
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
        isNextPoster: isNextPoster,
        hasNext: hasNext,
        onItemTap: (item) => context.push('/player/${item.id}', extra: item),
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
                final w = ContentRow(
                  title: l10n.recentIn(view.name ?? ''),
                  items: items,
                  serverUrl: serverUrl,
                  height: rowHeight,
                  cardWidth: cardWidth,
                  itemSpacing: skin?.itemSpacing,
                  useBackdrop: isBack,
                  cardLogo: skin?.cardLogo,
                  isNextPoster: isNextPoster,
                  hasNext: hasNext,
                  onSeeMore: () =>
                      context.push('/library/${view.id}', extra: view.name),
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
                hasNext: rowCursor < visibleBackdrops.length - 1,
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

    List<Widget> buildCustomChildren() {
      // Recalcular visibleBackdrops según el orden custom para rowSpacing
      final List<bool> customBackdrops = [];
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
            for (final view in views.value ?? const <BaseItemDto>[]) {
              if (![
                CollectionType.music,
                CollectionType.movies,
                CollectionType.tvshows,
                CollectionType.books,
              ].any((t) => view.collectionType == t)) {
                continue;
              }
              final items =
                  ref.watch(recentLibraryItemsProvider(view.id ?? '')).value ??
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
            out.add(buildUpNextRow());
            break;
          case HomeSectionType.recent:
            for (final type in const [
              CollectionType.music,
              CollectionType.movies,
              CollectionType.tvshows,
              CollectionType.books,
            ]) {
              for (final view in (views.value ?? const <BaseItemDto>[]).where(
                (v) => v.collectionType == type,
              )) {
                out.add(
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
                      final w = ContentRow(
                        title: l10n.recentIn(view.name ?? ''),
                        items: items,
                        serverUrl: serverUrl,
                        height: rowHeight,
                        cardWidth: cardWidth,
                        itemSpacing: skin.itemSpacing,
                        useBackdrop: isBack,
                        cardLogo: skin.cardLogo,
                        isNextPoster: isNextPoster,
                        hasNext: rowCursor < visibleBackdrops.length - 1,
                        onSeeMore: () => context.push(
                          '/library/${view.id}',
                          extra: view.name,
                        ),
                        onItemTap: (item) =>
                            context.push('/player/${item.id}', extra: item),
                        onItemImageTap: (item) => context.push(
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
            out.add(
              Builder(
                builder: (context) {
                  final items = latest.value ?? const [];
                  if (items.isEmpty) return const SizedBox.shrink();
                  final isBack = useBackdrop;
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
                    isNextPoster: isNextPoster,
                    hasNext: rowCursor < visibleBackdrops.length - 1,
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
                    imageSource: s.imageSource,
                    hideTitle: s.hideTitle,
                    hideYear: s.hideYear,
                    isNextPoster: isNextPoster,
                    hasNext: rowCursor < visibleBackdrops.length - 1,
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
