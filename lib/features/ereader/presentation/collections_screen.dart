import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_hover_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../application/ereader_providers.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/widgets/poster_card.dart';
import 'widgets/collections_content_row.dart';

/// Pantalla completa de colecciones on-the-fly, como las bibliotecas:
/// buscador por título, orden A-Z / por nº de libros y paginado con flechas.
/// Tocar una colección abre su detalle con el grid de libros.
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  static const int _pageSize = 48;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _sortAsc = true;
  int _page = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final globalSkin = ref.watch(skinControllerProvider).value;
    final serverUrl = ref.watch(authServerUrlProvider);
    final async = ref.watch(eReaderCollectionsProvider);
    final all = async.value ?? const <EReaderCollection>[];
    final isLoading = async.isLoading && all.isEmpty;

    final query = _query.trim().toLowerCase();
    final filtered = <EReaderCollection>[
      for (final c in all)
        if (query.isEmpty || c.title.toLowerCase().contains(query)) c,
    ];
    if (_sortAsc) {
      filtered.sort((a, b) => a.title.compareTo(b.title));
    } else {
      filtered.sort((a, b) {
        final byCount = b.items.length.compareTo(a.items.length);
        return byCount != 0 ? byCount : a.title.compareTo(b.title);
      });
    }

    final totalPages = filtered.isEmpty
        ? 1
        : ((filtered.length + _pageSize - 1) ~/ _pageSize);
    final current = (_page + 1).clamp(1, totalPages);
    final pageItems = filtered.isEmpty
        ? const <EReaderCollection>[]
        : filtered.sublist(
            (_page * _pageSize).clamp(0, filtered.length),
            ((_page + 1) * _pageSize).clamp(0, filtered.length),
          );

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: libraryPageTopPadding(context, globalSkin)),
            LibraryPageHeader(title: l10n.bookCollections),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() {
                        _query = v;
                        _page = 0;
                      }),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: l10n.search,
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppHoverButton.text(
                    label: _sortAsc ? l10n.sortAZ : l10n.sortZA,
                    icon: _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                    onPressed: () => setState(() {
                      _sortAsc = !_sortAsc;
                      _page = 0;
                    }),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.back,
                    onPressed: _page > 0 ? () => setState(() => _page--) : null,
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white10,
                      disabledBackgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.pageOf(current, totalPages),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.seeMore,
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
            Expanded(
              child: isLoading
                  ? const Center(child: AppLoader())
                  : pageItems.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noResults,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 20,
                            childAspectRatio: 0.58,
                          ),
                      itemCount: pageItems.length,
                      itemBuilder: (context, i) {
                        final collection = pageItems[i];
                        final index = filtered.indexOf(collection);
                        return PosterCard(
                          item: collectionTileDto(index, collection),
                          serverUrl: serverUrl,
                          imageUrl: collectionCoverUrl(serverUrl, collection),
                          cornerBadge: collectionCountBadge(
                            collection.items.length,
                          ),
                          hideYear: true,
                          showHoverIncludedBadge: false,
                          hoverActionLabel: l10n.details,
                          hoverExtension: true,
                          onTap: () => context.push(
                            '/ereader/collections/detail',
                            extra: collection,
                          ),
                          onImageTap: () => context.push(
                            '/ereader/collections/detail',
                            extra: collection,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
