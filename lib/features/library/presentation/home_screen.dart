
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/navigation/platform_mode.dart';
import '../../../core/navigation/play_routing.dart';
import '../../../core/skin/home_scroll.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/scroll_title.dart';
import '../../../l10n/app_localizations.dart';
import '../../franchises/application/franchise_providers.dart';
import '../../seerr/application/seerr_studios_providers.dart';
import '../../seerr/presentation/widgets/seerr_studio_tile.dart';
import '../application/library_providers.dart';
import 'widgets/content_row.dart';
import 'widgets/featured_slider.dart';
import 'widgets/jellyfin_upcoming_row.dart';
import 'widgets/mood_suggestions_grid.dart';
import 'widgets/seasonal_suggestions_row.dart';

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
    final latestBanner = ref.watch(
      bannerItemsForProvider(scrollTypesKey(null)),
    );
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

    // Carga inicial: solo se bloquea con loader a pantalla completa mientras
    // no hay vistas (sin ellas no se puede construir ninguna fila). El resto
    // de filas (resume/nextUp/banner) pintan en progresivo al resolver.
    final initialLoading = views.isLoading && views.value == null;

    // --- RowSpacing doble backdrop->poster ---
    final List<bool> visibleBackdrops = [];
    bool isBackdropForContinue([HomeScroll? cfg]) {
      // `cardType` manda; `imageSource` solo decide si no se fijó formato.
      if (cfg?.cardType == HomeScrollCardType.backdrop) return true;
      if (cfg?.cardType == HomeScrollCardType.poster) return false;
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
    // Lo no reproducible directo (serie, álbum, libro…) cae a su ficha.
    void Function(BaseItemDto) tapFor(HomeScroll? cfg) {
      if (cfg?.tapAction == HomeScrollTapAction.details) {
        return (item) => pushDetailForType(context, item);
      }
      return (item) {
        if (playTargetFor(item) != DetailPlayTarget.unsupported) {
          pushPlayForDetail(context, item);
          return;
        }
        pushDetailForType(context, item);
      };
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
        imageSource: isBack ? cfg?.imageSource : RowImageSource.primary,
        showNewBadge: cfg?.showNewBadge ?? false,
        showStackLogo: cfg?.showLogo ?? false,
        logoPosition: cfg?.logoPosition ?? RowLogoPosition.top,
        metaAlignment: cfg?.metaAlignment ?? RowMetaAlign.left,
        logoSize: cfg?.logoSize,
        hideTitle: cfg?.hideTitle ?? false,
        hideYear: cfg?.hideYear ?? false,
        hideSubtitle: cfg?.hideSubtitle ?? false,
        showHoverOverlay: cfg?.showHoverOverlay ?? true,
        showPlayIcon: cfg?.showPlayIcon ?? true,
        highlightTitleOnHover: cfg?.highlightTitleOnHover ?? false,
        cardBorderRadius: cfg?.cardBorderRadius,
        hoverScale: cfg?.hoverScale,
        spotlight: cfg?.spotlight ?? false,
        cardScale: cfg?.cardScale ?? 1.0,
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
        hideSubtitle: cfg?.hideSubtitle ?? false,
        showHoverOverlay: cfg?.showHoverOverlay ?? true,
        showPlayIcon: cfg?.showPlayIcon ?? true,
        highlightTitleOnHover: cfg?.highlightTitleOnHover ?? false,
        cardBorderRadius: cfg?.cardBorderRadius,
        hoverScale: cfg?.hoverScale,
        spotlight: cfg?.spotlight ?? false,
        cardScale: cfg?.cardScale ?? 1.0,
        isNextPoster: isNextPoster,
        hasNext: hasNext,
        onItemTap: tapFor(cfg),
        onItemImageTap: (item) =>
            context.push('/home/details/${item.id}', extra: item),
      );
      rowCursor++;
      return w;
    }

    /// ID de la vista "Colecciones" (BoxSets) del servidor, si existe.
    String? boxSetsViewId() {
      for (final view in views.value ?? const <BaseItemDto>[]) {
        final id = view.id ?? '';
        if (view.collectionType == CollectionType.boxsets && id.isNotEmpty) {
          return id;
        }
      }
      return null;
    }

    /// Fila de colecciones (BoxSets): título "Colecciones" (o nombre libre del
    /// scroll) y tap que abre las películas de la colección en el grid.
    Widget buildBoxSetsRow([HomeScroll? cfg]) {
      final sort = cfg?.sort ?? HomeScrollSort.alphabetical;
      final boxAsync = ref.watch(boxSetItemsProvider(sort));
      final items = boxAsync.value ?? const <BaseItemDto>[];
      final isBack = cfg?.cardType == HomeScrollCardType.backdrop
          ? true
          : cfg?.cardType == HomeScrollCardType.poster
          ? false
          : useBackdrop;
      final isNextPoster = isNextPosterFor(isBack);
      final freeTitle = cfg?.customTitle?.trim() ?? '';
      final title = freeTitle.isNotEmpty ? freeTitle : l10n.collections;
      if (items.isEmpty) {
        // Carga inicial: título + loader; sin resultados reales se oculta.
        if (!boxAsync.isLoading) return const SizedBox.shrink();
        rowCursor++;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ScrollTitle(title: title),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: rowHeight,
              child: const Center(child: AppLoader()),
            ),
          ],
        );
      }
      final targetViewId = boxSetsViewId();
      void openCollection(BaseItemDto item) {
        final id = item.id;
        if (id == null || id.isEmpty) return;
        context.push('/library/$id', extra: item.name);
      }
      final w = ContentRow(
        title: title,
        items: items,
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
        hideSubtitle: cfg?.hideSubtitle ?? false,
        showHoverOverlay: cfg?.showHoverOverlay ?? true,
        showPlayIcon: cfg?.showPlayIcon ?? false,
        highlightTitleOnHover: cfg?.highlightTitleOnHover ?? false,
        cardBorderRadius: cfg?.cardBorderRadius,
        hoverScale: cfg?.hoverScale,
        spotlight: cfg?.spotlight ?? false,
        cardScale: cfg?.cardScale ?? 1.0,
        isNextPoster: isNextPoster,
        hasNext: rowCursor < visibleBackdrops.length - 1,
        onSeeMore: (cfg?.showSeeMore ?? true) && targetViewId != null
            ? () => context.push(
                '/library/$targetViewId',
                extra: l10n.collections,
              )
            : null,
        onItemTap: openCollection,
        onItemImageTap: openCollection,
      );
      rowCursor++;
      return w;
    }

    /// Hub "Franquicias": una tarjeta por saga curada; al pulsar se abre su
    /// pantalla con el orden TMDB y los faltantes pedibles desde Seerr.
    Widget buildFranchisesRow([HomeScroll? cfg]) {
      final hubAsync = ref.watch(franchiseHubProvider);
      final hub = hubAsync.value ?? const <FranchiseHubEntry>[];
      final isBack = cfg?.cardType == HomeScrollCardType.backdrop
          ? true
          : cfg?.cardType == HomeScrollCardType.poster
          ? false
          : useBackdrop;
      final isNextPoster = isNextPosterFor(isBack);
      final freeTitle = cfg?.customTitle?.trim() ?? '';
      final title = freeTitle.isNotEmpty ? freeTitle : l10n.franchises;
      if (hub.isEmpty) {
        if (!hubAsync.isLoading) return const SizedBox.shrink();
        rowCursor++;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ScrollTitle(title: title),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: rowHeight,
              child: const Center(child: AppLoader()),
            ),
          ],
        );
      }
      final language = Localizations.localeOf(context).languageCode;
      final byId = <String, FranchiseHubEntry>{
        for (final entry in hub) 'franchise:${entry.franchise.id}': entry,
      };
      final items = [
        for (final entry in hub)
          BaseItemDto(
            id: 'franchise:${entry.franchise.id}',
            name: entry.franchise.nameFor(language),
            type: BaseItemKind.movie,
          ),
      ];
      void openFranchise(BaseItemDto item) {
        final entry = byId[item.id];
        if (entry == null) return;
        context.push('/franchises/${entry.franchise.id}');
      }

      final w = ContentRow(
        title: title,
        items: items,
        serverUrl: serverUrl,
        height: rowHeight,
        cardWidth: cardWidth,
        itemSpacing: skin?.itemSpacing,
        useBackdrop: isBack,
        showBottomVignette: cfg?.bottomVignette ?? false,
        bottomVignetteHeight: cfg?.bottomVignetteHeight ?? 56,
        bottomVignetteOpacity: cfg?.bottomVignetteOpacity ?? 0.72,
        showMetaOverlay: cfg?.metaOverlay ?? false,
        showNewBadge: false,
        // Franquicias: sin logo superpuesto (el usuario crea sus imágenes).
        showStackLogo: false,
        logoPosition: cfg?.logoPosition ?? RowLogoPosition.center,
        metaAlignment: cfg?.metaAlignment ?? RowMetaAlign.left,
        logoSize: cfg?.logoSize ?? 72,
        hideTitle: cfg?.hideTitle ?? false,
        hideYear: cfg?.hideYear ?? false,
        hideSubtitle: cfg?.hideSubtitle ?? false,
        showHoverOverlay: cfg?.showHoverOverlay ?? true,
        showPlayIcon: false,
        highlightTitleOnHover: cfg?.highlightTitleOnHover ?? false,
        cardBorderRadius: cfg?.cardBorderRadius,
        hoverScale: cfg?.hoverScale,
        spotlight: cfg?.spotlight ?? false,
        cardScale: cfg?.cardScale ?? 1.0,
        isNextPoster: isNextPoster,
        hasNext: rowCursor < visibleBackdrops.length - 1,
        excludePlaceholders: false,
        showHoverIncludedBadge: false,
        hoverActionLabel: l10n.details,
        imageUrlFor: (item) => byId[item.id]?.imageUrl,
        onItemTap: openFranchise,
        onItemImageTap: openFranchise,
      );
      rowCursor++;
      return w;
    }

    /// Fila de estudios de Seerr (solo si Seerr está configurado): tarjetas con
    /// logo a sangre o degradado + glassmorphism, usando el scroll estándar.
    Widget buildSeerrStudiosRow([HomeScroll? cfg]) {
      final studiosAsync = ref.watch(seerrStudiosProvider);
      final studios = studiosAsync.value ?? const <SeerrStudioEntry>[];
      final freeTitle = cfg?.customTitle?.trim() ?? '';
      final title = freeTitle.isNotEmpty ? freeTitle : l10n.studios;
      if (studios.isEmpty) {
        if (!studiosAsync.isLoading) return const SizedBox.shrink();
        rowCursor++;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ScrollTitle(title: title),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: rowHeight,
              child: const Center(child: AppLoader()),
            ),
          ],
        );
      }
      final byId = <String, SeerrStudioEntry>{
        for (final entry in studios) 'studio:${entry.companyId}': entry,
      };
      final items = [
        for (final entry in studios)
          BaseItemDto(
            id: 'studio:${entry.companyId}',
            name: entry.name,
            type: BaseItemKind.movie,
          ),
      ];
      void openStudio(BaseItemDto item) {
        final entry = byId[item.id];
        if (entry == null) return;
        context.push('/studios/${entry.companyId}', extra: entry.name);
      }

      final isBack = cfg?.cardType != HomeScrollCardType.poster;
      final isNextPoster = isNextPosterFor(isBack);
      final w = ContentRow(
        title: title,
        items: items,
        serverUrl: serverUrl,
        height: rowHeight,
        cardWidth: cardWidth,
        itemSpacing: skin?.itemSpacing,
        useBackdrop: isBack,
        imageBuilder: (context, item) {
          final entry = byId[item.id];
          if (entry == null) return const SizedBox.shrink();
          return SeerrStudioTile(studio: entry);
        },
        showMetaOverlay: false,
        showNewBadge: false,
        showStackLogo: false,
        hideTitle: cfg?.hideTitle ?? false,
        hideYear: true,
        hideSubtitle: true,
        showHoverOverlay: cfg?.showHoverOverlay ?? true,
        showPlayIcon: false,
        highlightTitleOnHover: cfg?.highlightTitleOnHover ?? false,
        cardBorderRadius: cfg?.cardBorderRadius,
        hoverScale: cfg?.hoverScale,
        spotlight: false,
        cardScale: cfg?.cardScale ?? 1.0,
        isNextPoster: isNextPoster,
        hasNext: rowCursor < visibleBackdrops.length - 1,
        excludePlaceholders: false,
        showHoverIncludedBadge: false,
        hoverActionLabel: l10n.details,
        onItemTap: openStudio,
        onItemImageTap: openStudio,
      );
      rowCursor++;
      return w;
    }

    final hasCustomLayout = (skin?.homeLayout.isNotEmpty ?? false);

    // Helper para construir FeaturedSlider reutilizable.
    // Sin [items] usa el banner por defecto (pelis + series).
    Widget buildFeaturedSlider([List<BaseItemDto>? items]) => FeaturedSlider(
      title: l10n.newReleases,
      items: items ?? latestBanner.value ?? const [],
      serverUrl: serverUrl,
      showTitle: skin?.bannerShowTitle ?? true,
      showAgeRating: skin?.bannerShowAgeRating ?? false,
      contentScale: skin?.bannerContentScale ?? 1.0,
      showBorder: skin?.bannerBorder ?? false,
      borderColor: skin?.bannerBorderColor ?? Colors.white,
      borderWidth: skin?.bannerBorderWidth ?? 1.5,
      hoverBorderWidth: skin?.bannerBorderHoverWidth ?? 2.5,
      showArrows: skin?.bannerShowArrows ?? false,
      showDots: skin?.bannerShowDots ?? true,
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
        const MoodSuggestionsGrid(),
        const SeasonalSuggestionsRow(),
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
          case LayoutSectionType.continueWatching:
            if ((resume.value ?? []).isEmpty) break;
            customBackdrops.add(isBackdropForContinue(section.scroll));
            break;
          case LayoutSectionType.nextUp:
            if (nextUpFiltered.isEmpty) break;
            customBackdrops.add(useBackdrop);
            break;
          case LayoutSectionType.recent:
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
                  : ref
                            .watch(recentRowItemsProvider((viewId, recentSort)))
                            .value ??
                        const [];
              if (items.isEmpty) continue;
              customBackdrops.add(useBackdrop);
            }
            break;
          case LayoutSectionType.newReleases:
            if ((latest.value ?? []).isEmpty) break;
            customBackdrops.add(useBackdrop);
            break;
          case LayoutSectionType.library:
            final librarySort = section.scroll?.sort;
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
              final items = librarySort == null
                  ? ref.watch(libraryItemsProvider(viewId)).value ?? const []
                  : ref
                            .watch(
                              libraryRowItemsProvider((viewId, librarySort)),
                            )
                            .value ??
                        const [];
              if (items.isEmpty) continue;
              customBackdrops.add(useBackdrop);
            }
            break;
          case LayoutSectionType.boxSets:
            final boxSort =
                section.scroll?.sort ?? HomeScrollSort.alphabetical;
            final boxAsync = ref.watch(boxSetItemsProvider(boxSort));
            final boxItems = boxAsync.value ?? const <BaseItemDto>[];
            if (boxItems.isEmpty && !boxAsync.isLoading) break;
            final s = section.scroll;
            final isBack = s?.cardType == HomeScrollCardType.backdrop
                ? true
                : s?.cardType == HomeScrollCardType.poster
                ? false
                : useBackdrop;
            customBackdrops.add(isBack);
            break;
          case LayoutSectionType.franchises:
            final hubAsync = ref.watch(franchiseHubProvider);
            final hub = hubAsync.value ?? const <FranchiseHubEntry>[];
            if (hub.isEmpty && !hubAsync.isLoading) break;
            final s = section.scroll;
            final isBack = s?.cardType == HomeScrollCardType.backdrop
                ? true
                : s?.cardType == HomeScrollCardType.poster
                ? false
                : useBackdrop;
            customBackdrops.add(isBack);
            break;
          case LayoutSectionType.seerrStudios:
            final studiosAsync = ref.watch(seerrStudiosProvider);
            final studios = studiosAsync.value ?? const <SeerrStudioEntry>[];
            if (studios.isEmpty && !studiosAsync.isLoading) break;
            customBackdrops.add(
              section.scroll?.cardType != HomeScrollCardType.poster,
            );
            break;
          case LayoutSectionType.custom:
            final s = section.scroll!;
            final scrollItems = ref.watch(homeScrollItemsProvider(s));
            final items = scrollItems.value ?? const [];
            // En carga cuenta como presente: la fila aparece al instante
            // (título + loader) en vez de esperar a que responda la API.
            if (items.isEmpty && !scrollItems.isLoading) break;
            final isBack = s.cardType == HomeScrollCardType.backdrop
                ? true
                : s.cardType == HomeScrollCardType.poster
                ? false
                : useBackdrop;
            customBackdrops.add(isBack);
            break;
          case LayoutSectionType.featuredSlider:
          case LayoutSectionType.seasonal:
          case LayoutSectionType.upcoming:
          case LayoutSectionType.seerrDiscover:
          case LayoutSectionType.gap:
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
          case LayoutSectionType.featuredSlider:
            final sliderItems =
                ref
                    .watch(
                      bannerItemsForProvider(scrollTypesKey(section.scroll)),
                    )
                    .value ??
                const [];
            if (showBanner && sliderItems.isNotEmpty) {
              out.add(buildFeaturedSlider(sliderItems));
            }
            out.add(const MoodSuggestionsGrid());
            break;
          case LayoutSectionType.seasonal:
            out.add(SeasonalSuggestionsRow(scroll: section.scroll));
            break;
          case LayoutSectionType.upcoming:
            out.add(JellyfinUpcomingRow(scroll: section.scroll));
            break;
          case LayoutSectionType.seerrDiscover:
            // Las secciones de Seerr solo aplican en su propia pantalla.
            break;
          case LayoutSectionType.gap:
            out.add(SizedBox(height: section.gapHeight ?? 24));
            break;
          case LayoutSectionType.continueWatching:
            if ((resume.value ?? []).isEmpty) break;
            out.add(buildContinueRow(section.scroll));
            break;
          case LayoutSectionType.nextUp:
            if (nextUpFiltered.isEmpty) break;
            out.add(buildUpNextRow(section.scroll));
            break;
          case LayoutSectionType.recent:
            final recentScroll = section.scroll;
            final useRecentBackdrop =
                recentScroll?.cardType == HomeScrollCardType.backdrop
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
                          ? ref
                                    .watch(recentLibraryItemsProvider(viewId))
                                    .value ??
                                const []
                          : ref
                                    .watch(
                                      recentRowItemsProvider((
                                        viewId,
                                        recentSort,
                                      )),
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
                        hideSubtitle: recentScroll?.hideSubtitle ?? false,
                        showHoverOverlay:
                            recentScroll?.showHoverOverlay ?? true,
                        showPlayIcon: recentScroll?.showPlayIcon ?? true,
                        highlightTitleOnHover:
                            recentScroll?.highlightTitleOnHover ?? false,
                        cardBorderRadius: recentScroll?.cardBorderRadius,
                        hoverScale: recentScroll?.hoverScale,
                        spotlight: recentScroll?.spotlight ?? false,
                        cardScale: recentScroll?.cardScale ?? 1.0,
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
          case LayoutSectionType.library:
            final libraryScroll = section.scroll;
            final useLibraryBackdrop =
                libraryScroll?.cardType == HomeScrollCardType.backdrop
                ? true
                : libraryScroll?.cardType == HomeScrollCardType.poster
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
                      final librarySort = section.scroll?.sort;
                      final items = librarySort == null
                          ? ref.watch(libraryItemsProvider(viewId)).value ??
                                const []
                          : ref
                                    .watch(
                                      libraryRowItemsProvider((
                                        viewId,
                                        librarySort,
                                      )),
                                    )
                                    .value ??
                                const [];
                      if (items.isEmpty) return const SizedBox.shrink();
                      final isBack = useLibraryBackdrop;
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
                        hideSubtitle: libraryScroll?.hideSubtitle ?? false,
                        showHoverOverlay:
                            libraryScroll?.showHoverOverlay ?? true,
                        showPlayIcon: libraryScroll?.showPlayIcon ?? true,
                        highlightTitleOnHover:
                            libraryScroll?.highlightTitleOnHover ?? false,
                        cardBorderRadius: libraryScroll?.cardBorderRadius,
                        hoverScale: libraryScroll?.hoverScale,
                        spotlight: libraryScroll?.spotlight ?? false,
                        cardScale: libraryScroll?.cardScale ?? 1.0,
                        isNextPoster: isNextPoster,
                        hasNext: rowCursor < visibleBackdrops.length - 1,
                        onSeeMore: (libraryScroll?.showSeeMore ?? true)
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
          case LayoutSectionType.newReleases:
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
                    hideSubtitle: newReleasesScroll?.hideSubtitle ?? false,
                    showHoverOverlay:
                        newReleasesScroll?.showHoverOverlay ?? true,
                    showPlayIcon: newReleasesScroll?.showPlayIcon ?? true,
                    highlightTitleOnHover:
                        newReleasesScroll?.highlightTitleOnHover ?? false,
                    cardBorderRadius: newReleasesScroll?.cardBorderRadius,
                    hoverScale: newReleasesScroll?.hoverScale,
                    spotlight: newReleasesScroll?.spotlight ?? false,
                    cardScale: newReleasesScroll?.cardScale ?? 1.0,
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
          case LayoutSectionType.boxSets:
            out.add(buildBoxSetsRow(section.scroll));
            break;
          case LayoutSectionType.franchises:
            out.add(buildFranchisesRow(section.scroll));
            break;
          case LayoutSectionType.seerrStudios:
            out.add(buildSeerrStudiosRow(section.scroll));
            break;
          case LayoutSectionType.custom:
            final s = section.scroll!;
            out.add(
              Builder(
                builder: (context) {
                  final scrollItems = ref.watch(homeScrollItemsProvider(s));
                  final items = scrollItems.value ?? const [];
                  final isBack = s.cardType == HomeScrollCardType.backdrop
                      ? true
                      : s.cardType == HomeScrollCardType.poster
                      ? false
                      : useBackdrop;
                  final isNextPoster = isNextPosterFor(isBack);
                  if (items.isEmpty) {
                    // Carga inicial: la fila se muestra al instante con su
                    // título traducido y un loader; al llegar la API se pinta
                    // el ContentRow. Sin resultados reales se oculta igual.
                    // Sin elementos enfocables: no altera el foco de TV.
                    if (!scrollItems.isLoading) {
                      return const SizedBox.shrink();
                    }
                    final w = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ScrollTitle(title: _scrollTitle(l10n, s)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: rowHeight,
                          child: const Center(child: AppLoader()),
                        ),
                      ],
                    );
                    rowCursor++;
                    return w;
                  }
                  final w = ContentRow(
                    title: _scrollTitle(l10n, s),
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
                    hideSubtitle: s.hideSubtitle,
                    showHoverOverlay: s.showHoverOverlay,
                    showPlayIcon: s.showPlayIcon,
                    highlightTitleOnHover: s.highlightTitleOnHover,
                    cardBorderRadius: s.cardBorderRadius,
                    hoverScale: s.hoverScale,
                    spotlight: s.spotlight,
                    cardScale: s.cardScale,
                    isNextPoster: isNextPoster,
                    hasNext: rowCursor < visibleBackdrops.length - 1,
                    onSeeMore: s.showSeeMore
                        ? () {
                            final allViews =
                                views.value ?? const <BaseItemDto>[];
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
                  // Mantiene las filas vecinas compuestas para que el scroll
                  // vertical no reconstruya tarjetas al volver atrás.
                  // NOTA: se usa cacheExtent (estable) en vez de
                  // scrollCacheExtent/ScrollCacheExtent, que exige
                  // import 'package:flutter/rendering.dart' y SDK >=3.47.
                  // Así el fichero compila en ambos PCs sin imports frágiles.
                  cacheExtent: 800,
                  padding: EdgeInsets.only(
                    top: bannerAttached ? 0 : (skin?.bannerTopPadding ?? 54),
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

  /// Resuelve el título de una fila de contenido ([HomeScroll]).
  static String _scrollTitle(AppLocalizations l10n, HomeScroll scroll) =>
      HomeScrollTitle.resolve(l10n, scroll.titleKey, scroll.customTitle);

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
