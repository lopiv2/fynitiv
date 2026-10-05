import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_scope.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../core/widgets/scroll_title.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/widgets/content_row.dart';
import '../../library/presentation/widgets/poster_card.dart';
import '../application/ereader_providers.dart';

/// E-Reader: biblioteca de libros/cómics de Jellyfin.
///
/// Arriba una fila de "recién añadidos" y debajo un grid paginado con todos los
/// libros. Usa un skin fijo propio ([eReaderSkin]) que no cambia con el skin
/// global (VOD, etc.).
class EReaderScreen extends ConsumerStatefulWidget {
  const EReaderScreen({super.key});

  @override
  ConsumerState<EReaderScreen> createState() => _EReaderScreenState();
}

class _EReaderScreenState extends ConsumerState<EReaderScreen> {
  int _page = 0;
  bool _sortAsc = true;

  void _openDetail(BaseItemDto item) {
    context.push('/ereader/details/${item.id}', extra: item);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final latest =
        ref.watch(eReaderLatestBooksProvider).value ?? const <BaseItemDto>[];

    final args = EReaderBooksArgs(pageIndex: _page, sortAscending: _sortAsc);
    final pageAsync = ref.watch(eReaderBooksPageProvider(args));
    final totalAsync = ref.watch(eReaderBooksCountProvider);
    final items = pageAsync.value ?? const <BaseItemDto>[];
    final total = totalAsync.value ?? 0;
    final totalPages = total == 0
        ? 1
        : ((total + kLibraryPageSize - 1) ~/ kLibraryPageSize);
    final current = (_page + 1).clamp(1, totalPages);
    final isLoading = pageAsync.isLoading && items.isEmpty;

    return SkinScope(
      skin: eReaderSkin,
      child: Scaffold(
        body: DashboardBackground(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: libraryPageTopPadding(context, eReaderSkin)),
              Expanded(
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                          child: ScrollTitle(
                            title: l10n.eReader,
                            fontSize: 34,
                          ),
                        ),
                      ),
                      if (latest.isNotEmpty)
                        SliverToBoxAdapter(
                          child: ContentRow(
                            title: l10n.eReaderRecent,
                            items: latest,
                            serverUrl: serverUrl,
                            showPlayIcon: false,
                            onItemTap: _openDetail,
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: ScrollTitle(title: l10n.eReaderAllBooks),
                              ),
                              _PillButton(
                                icon: _sortAsc
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                label: _sortAsc ? l10n.sortAZ : l10n.sortZA,
                                onTap: () => setState(() {
                                  _sortAsc = !_sortAsc;
                                  _page = 0;
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: AppLoader()),
                        )
                      else if (items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              l10n.noResults,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 190,
                                  mainAxisSpacing: 20,
                                  crossAxisSpacing: 20,
                                  childAspectRatio: 0.58,
                                ),
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final item = items[i];
                                return PosterCard(
                                  item: item,
                                  serverUrl: serverUrl,
                                  hoverExtension: true,
                                  onTap: () => _openDetail(item),
                                  onImageTap: () => _openDetail(item),
                                );
                              },
                              childCount: items.length,
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: l10n.back,
                                onPressed: _page > 0
                                    ? () => setState(() => _page--)
                                    : null,
                                icon: const Icon(
                                  Icons.chevron_left,
                                  color: Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white10,
                                  disabledBackgroundColor: Colors.white12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.pageOf(current, totalPages),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: l10n.seeMore,
                                onPressed: (_page + 1) < totalPages
                                    ? () => setState(() => _page++)
                                    : null,
                                icon: const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white10,
                                  disabledBackgroundColor: Colors.white12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
