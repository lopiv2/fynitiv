import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/home_scroll.dart';
import '../../../core/skin/skin.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../movies/presentation/widgets/category_dialog.dart';
import '../application/library_providers.dart';
import 'widgets/backdrop_card.dart';
import 'widgets/poster_card.dart';

/// Grid universal de una biblioteca (/library/:viewId) con paginado,
/// filtros por categoría y orden alfabético.
///
/// Reemplaza al antiguo `AllMoviesScreen` para Películas y Series y
/// sirve para cualquier biblioteca (Colecciones, etc.) manteniendo
/// el header dinámico de donde viene la navegación.
///
/// Si se navega con `extra` de tipo [HomeScroll] (ver más de un scroll
/// determinado como Acción / Familia) se aplica ese filtro de géneros
/// automáticamente. Ejemplo: pulsar ver más en "Películas de Acción" ahora
/// muestra solo `Action` dentro de la biblioteca correspondiente.
class LibraryViewScreen extends ConsumerStatefulWidget {
  const LibraryViewScreen({
    super.key,
    required this.viewId,
    this.initialGenre,
    this.titleOverride,
    this.scroll,
  });

  final String viewId;

  /// Género inicial (ej. 'Action') si viene de un scroll determinado.
  final String? initialGenre;

  /// Título forzado (ej. 'Películas de Acción') si viene de scroll.
  final String? titleOverride;

  /// Scroll completo para filtros múltiples (ej. ['Animation','Family','Kids']).
  final HomeScroll? scroll;

  @override
  ConsumerState<LibraryViewScreen> createState() => _LibraryViewScreenState();
}

class _LibraryViewScreenState extends ConsumerState<LibraryViewScreen> {
  late int _page;
  late bool _sortAsc;
  late ItemSortBy _sortBy;
  late String? _genre;
  late String? _genresPipe;
  List<BaseItemKind>? _includeTypes;

  static ItemSortBy _sortByForScroll(HomeScroll? scroll) {
    switch (scroll?.sort) {
      case HomeScrollSort.alphabetical:
        return ItemSortBy.sortName;
      case HomeScrollSort.recent:
        return ItemSortBy.premiereDate;
      case HomeScrollSort.rating:
        return ItemSortBy.communityRating;
      case HomeScrollSort.added:
        return ItemSortBy.dateCreated;
      case HomeScrollSort.random:
        return ItemSortBy.random;
      case null:
        return ItemSortBy.sortName;
    }
  }

  static bool _sortAscForScroll(HomeScroll? scroll) {
    switch (scroll?.sort) {
      case HomeScrollSort.alphabetical:
      case HomeScrollSort.random:
      case null:
        return true;
      case HomeScrollSort.recent:
      case HomeScrollSort.rating:
      case HomeScrollSort.added:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _page = 0;
    _sortBy = _sortByForScroll(widget.scroll);
    _sortAsc = _sortAscForScroll(widget.scroll);
    // Prioridad: scroll -> initialGenre -> nada
    if (widget.scroll != null) {
      final g =
          widget.scroll!.genres.map((e) => e.value).toList();
      if (g.isNotEmpty) {
        _genresPipe = g.join('|');
        _genre = g.length == 1 ? g.first : null;
      }
      _includeTypes = widget.scroll!.types.isEmpty
          ? null
          : widget.scroll!.types;
    } else if (widget.initialGenre != null && widget.initialGenre!.isNotEmpty) {
      _genre = widget.initialGenre;
      _genresPipe = null;
    } else {
      _genre = null;
      _genresPipe = null;
    }
  }

  @override
  void didUpdateWidget(covariant LibraryViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scroll != widget.scroll ||
        oldWidget.initialGenre != widget.initialGenre) {
      if (widget.scroll != null) {
        final g =
            widget.scroll!.genres.map((e) => e.value).toList();
        _genresPipe = g.isNotEmpty ? g.join('|') : null;
        _genre = g.length == 1 ? g.first : null;
        _includeTypes = widget.scroll!.types.isEmpty
            ? null
            : widget.scroll!.types;
        _sortBy = _sortByForScroll(widget.scroll);
        _sortAsc = _sortAscForScroll(widget.scroll);
      } else {
        _genre = widget.initialGenre;
        _genresPipe = null;
        _includeTypes = null;
      }
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final skin = ref.watch(skinControllerProvider).value;
    final topPadding = libraryPageTopPadding(context, skin);
    final useBackdrop =
        (skin?.cardImageType ?? CardImageType.poster) == CardImageType.backdrop;

    // Título dinámico: override > view.name > fallback library
    final views = ref.watch(userViewsProvider).value ?? const <BaseItemDto>[];
    final view = views.where((v) => v.id == widget.viewId).firstOrNull;
    final String headerTitle;
    if (widget.titleOverride != null &&
        widget.titleOverride!.trim().isNotEmpty) {
      headerTitle = widget.titleOverride!;
    } else if (widget.scroll != null) {
      headerTitle = _resolveScrollTitle(l10n, widget.scroll!.titleKey);
    } else if (view?.name != null && view!.name!.trim().isNotEmpty) {
      headerTitle = view.name!;
    } else {
      headerTitle = l10n.library;
    }

    // Determinar includeTypes efectivo:
    // 1) Si viene de un HomeScroll (ver más Acción etc.) respetamos sus tipos.
    // 2) Si no, inferimos del tipo de biblioteca (Series -> solo Series, no episodios).
    // Esto evita que el grid de Series muestre un elemento por cada capítulo.
    final List<BaseItemKind>? effectiveTypes;
    if (_includeTypes != null) {
      effectiveTypes = _includeTypes;
    } else if (view != null) {
      effectiveTypes = _kindsForCollectionType(view.collectionType);
    } else {
      effectiveTypes = null;
    }

    final args = LibraryFilteredArgs(
      viewId: widget.viewId,
      pageIndex: _page,
      sortAscending: _sortAsc,
      genre: _genre,
      genresPipe: _genresPipe,
      includeItemTypes: effectiveTypes,
      sortBy: _sortBy,
    );
    final pageAsync = ref.watch(libraryFilteredPageProvider(args));
    final countAsync = ref.watch(libraryFilteredCountProvider(args));
    final items = pageAsync.value ?? const <BaseItemDto>[];
    final totalCount = countAsync.value ?? 0;
    final totalPages = totalCount == 0
        ? 1
        : ((totalCount + kLibraryPageSize - 1) ~/ kLibraryPageSize);
    final currentDisplay = (_page + 1).clamp(1, totalPages);
    final isLoading = pageAsync.isLoading && items.isEmpty;
    final effectiveGenreLabel =
        _genre ?? (_genresPipe != null ? _genreFromPipe(_genresPipe!) : null);
    // Rango centrado tipo "1-100 de 913"
    final startItem = totalCount == 0 ? 0 : _page * kLibraryPageSize + 1;
    final endItem = ((_page + 1) * kLibraryPageSize).clamp(0, totalCount);
    final rangeText = totalCount == 0
        ? (isLoading ? '… de …' : '0-0 de 0')
        : '$startItem-$endItem de $totalCount';

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: topPadding),
            LibraryPageHeader(title: headerTitle),
            // Fila de filtros: categorías, orden, paginación (solo Películas/Series
            // muestran categorías, pero se muestra genérico para cualquier biblioteca)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  _PillButton(
                    icon: Icons.category_outlined,
                    label: effectiveGenreLabel ?? l10n.categories,
                    onTap: () async {
                      final selected = await showCategoryDialog(
                        context,
                        selected: _genre,
                      );
                      if (selected != null) {
                        setState(() {
                          _genre = selected.isEmpty ? null : selected;
                          // Si se eligió una categoría manual, resetea el pipe multi-género
                          if (_genre != null) _genresPipe = null;
                          if (selected.isEmpty) {
                            // Limpiar también tubo si se limpia filtro y venía de scroll
                            if (widget.scroll != null) {
                              // Re-aplica filtro original del scroll si se limpia?
                              // En este caso solo limpia selección manual, mantiene scroll pipe
                              // Si el usuario quiere ver todo dentro de la biblioteca,
                              // lo dejamos en null para mostrar todo.
                            }
                          }
                          _page = 0;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _PillButton(
                    icon: _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                    label: _sortAsc ? l10n.sortAZ : l10n.sortZA,
                    onTap: () => setState(() {
                      _sortAsc = !_sortAsc;
                      _page = 0;
                    }),
                  ),
                  // Conteo centrado "1-100 de 913"
                  Expanded(
                    child: Center(
                      child: Text(
                        rangeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Anterior',
                    onPressed: _page > 0 ? () => setState(() => _page--) : null,
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white10,
                      disabledBackgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.pageOf(currentDisplay, totalPages),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Siguiente',
                    onPressed: (_page + 1) < totalPages
                        ? () => setState(() => _page++)
                        : null,
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white10,
                      disabledBackgroundColor: Colors.white12,
                    ),
                  ),
                ],
              ),
            ),
            if (effectiveGenreLabel != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      '${l10n.filterByCategory}: $effectiveGenreLabel',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _genre = null;
                        _genresPipe = null;
                        _page = 0;
                      }),
                      child: Text(l10n.clearFilter),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: isLoading
                  ? const Center(child: AppLoader())
                  : items.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noResults,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : FocusTraversalGroup(
                      policy: ReadingOrderTraversalPolicy(),
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 20,
                          childAspectRatio: useBackdrop ? 1.5 : 0.6,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final scroll = widget.scroll;
                          if (useBackdrop) {
                            return BackdropCard(
                              item: item,
                              serverUrl: serverUrl,
                              cardLogo: skin?.cardLogo,
                              hoverExtension: true,
                              showBottomVignette:
                                  scroll?.bottomVignette ?? false,
                              bottomVignetteHeight:
                                  scroll?.bottomVignetteHeight ?? 56,
                              bottomVignetteOpacity:
                                  scroll?.bottomVignetteOpacity ?? 0.72,
                              showMetaOverlay: scroll?.metaOverlay ?? false,
                              showNewBadge: scroll?.showNewBadge ?? false,
                              showStackLogo: scroll?.showLogo ?? false,
                              logoPosition:
                                  scroll?.logoPosition ??
                                  RowLogoPosition.top,
                              metaAlignment:
                                  scroll?.metaAlignment ?? RowMetaAlign.left,
                              logoSize: scroll?.logoSize,
                              hideTitle: scroll?.hideTitle ?? false,
                              hideYear: scroll?.hideYear ?? false,
                              showHoverOverlay:
                                  scroll?.showHoverOverlay ?? true,
                              cardBorderRadius: scroll?.cardBorderRadius,
                              hoverScale: scroll?.hoverScale,
                              onTap: () => context.push(
                                '/player/${item.id}',
                                extra: item,
                              ),
                              onImageTap: () => context.push(
                                '/home/details/${item.id}',
                                extra: item,
                              ),
                            );
                          }
                          return PosterCard(
                            item: item,
                            serverUrl: serverUrl,
                            cardLogo: skin?.cardLogo,
                            hoverExtension: true,
                            showBottomVignette:
                                scroll?.bottomVignette ?? false,
                            bottomVignetteHeight:
                                scroll?.bottomVignetteHeight ?? 56,
                            bottomVignetteOpacity:
                                scroll?.bottomVignetteOpacity ?? 0.72,
                            showMetaOverlay: scroll?.metaOverlay ?? false,
                            showNewBadge: scroll?.showNewBadge ?? false,
                            showStackLogo: scroll?.showLogo ?? false,
                            logoPosition:
                                scroll?.logoPosition ??
                                RowLogoPosition.top,
                            metaAlignment:
                                scroll?.metaAlignment ?? RowMetaAlign.left,
                            logoSize: scroll?.logoSize,
                            hideTitle: scroll?.hideTitle ?? false,
                            hideYear: scroll?.hideYear ?? false,
                            showHoverOverlay:
                                scroll?.showHoverOverlay ?? true,
                            cardBorderRadius: scroll?.cardBorderRadius,
                            hoverScale: scroll?.hoverScale,
                            onTap: () =>
                                context.push('/player/${item.id}', extra: item),
                            onImageTap: () => context.push(
                              '/home/details/${item.id}',
                              extra: item,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveScrollTitle(AppLocalizations l10n, HomeScrollTitle key) =>
      HomeScrollTitle.resolve(l10n, key);

  String _genreFromPipe(String pipe) {
    final parts = pipe.split('|');
    if (parts.length == 1) return parts.first;
    return parts.join(', ');
  }

  List<BaseItemKind>? _kindsForCollectionType(CollectionType? type) {
    switch (type) {
      case CollectionType.movies:
        return const [BaseItemKind.movie];
      case CollectionType.tvshows:
        // Solo series, evita mostrar temporadas/episodios sueltos.
        return const [BaseItemKind.series];
      case CollectionType.music:
        return const [BaseItemKind.musicAlbum];
      case CollectionType.books:
        return const [BaseItemKind.book];
      case CollectionType.boxsets:
        return const [BaseItemKind.boxSet];
      case CollectionType.playlists:
        return const [BaseItemKind.playlist];
      case CollectionType.livetv:
        // Canales/programas, sin filtro genérico.
        return null;
      default:
        return null;
    }
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        canRequestFocus: true,
        focusColor: Colors.white24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
