import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/widgets/backdrop_card.dart';
import '../../library/presentation/widgets/poster_card.dart';
import '../../library/presentation/widgets/floating_island_bar.dart';
import '../../library/presentation/widgets/sidebar.dart';
import 'widgets/category_dialog.dart';

/// Pantalla con todas las películas: grid paginado 100 por página,
/// con isla flotante, 3 botones (Categorías, Orden, Paginación) entre isla y grid.
class AllMoviesScreen extends ConsumerStatefulWidget {
  const AllMoviesScreen({super.key});

  @override
  ConsumerState<AllMoviesScreen> createState() => _AllMoviesScreenState();
}

class _AllMoviesScreenState extends ConsumerState<AllMoviesScreen> {
  int _page = 0;
  bool _sortAsc = true;
  String? _genre;

  void _goBranch(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/vod');
        break;
      case 3:
        context.go('/live');
        break;
      case 4:
        context.go('/music');
        break;
      case 5:
        context.go('/ereader');
        break;
      case 6:
        context.go('/games');
        break;
      case 7:
        context.go('/settings');
        break;
      default:
        context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final skin = ref.watch(skinControllerProvider).value;
    final useBackdrop =
        (skin?.cardImageType ?? CardImageType.poster) == CardImageType.backdrop;

    final args = AllMoviesFilteredArgs(pageIndex: _page, sortAscending: _sortAsc, genre: _genre);
    final pageAsync = ref.watch(allMoviesFilteredPageProvider(args));
    final totalAsync = ref.watch(allMoviesTotalCountProvider(_genre));
    final items = pageAsync.value ?? const <BaseItemDto>[];
    final totalCount = totalAsync.value ?? 0;
    final totalPages = totalCount == 0 ? 1 : ((totalCount + kAllMoviesPageSize - 1) ~/ kAllMoviesPageSize);
    final currentDisplay = (_page + 1).clamp(1, totalPages);
    final isLoading = pageAsync.isLoading && items.isEmpty;

    // Determinar si mostrar isla (Prime: sidebar top)
    final showIsland = skin?.sidebarPosition == SidebarPosition.top;
    // Si es isla flotante o barra top, necesita offset superior
    final topPadding = MediaQuery.of(context).padding.top;
    final islandHeight = showIsland ? (topPadding + 70) : 0.0;

    return Scaffold(
      body: DashboardBackground(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: islandHeight + 8),
                // Cabecera con volver
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.back,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        },
                      ),
                      Expanded(
                        child: Text(
                          l10n.allMovies,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tres botones entre isla y grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      // Botón categorías -> dialog
                      _PillButton(
                        icon: Icons.category_outlined,
                        label: _genre ?? l10n.categories,
                        onTap: () async {
                          final selected = await showCategoryDialog(context, selected: _genre);
                          if (selected != null) {
                            setState(() {
                              _genre = selected.isEmpty ? null : selected;
                              _page = 0;
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      // Orden alfabético
                      _PillButton(
                        icon: _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                        label: _sortAsc ? l10n.sortAZ : l10n.sortZA,
                        onTap: () => setState(() {
                          _sortAsc = !_sortAsc;
                          _page = 0;
                        }),
                      ),
                      const Spacer(),
                      // Paginación flechas
                      IconButton(
                        tooltip: 'Anterior',
                        onPressed: _page > 0 ? () => setState(() => _page--) : null,
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: Colors.white10, disabledBackgroundColor: Colors.white12),
                      ),
                      const SizedBox(width: 8),
                      Text(l10n.pageOf(currentDisplay, totalPages),
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Siguiente',
                        onPressed: (_page + 1) < totalPages ? () => setState(() => _page++) : null,
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: Colors.white10, disabledBackgroundColor: Colors.white12),
                      ),
                    ],
                  ),
                ),
                if (_genre != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text('${l10n.filterByCategory}: $_genre', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 8),
                        TextButton(onPressed: () => setState(() { _genre = null; _page = 0; }), child: Text(l10n.clearFilter)),
                      ],
                    ),
                  ),
                Expanded(
                  child: isLoading
                      ? const Center(child: AppLoader())
                      : items.isEmpty
                          ? Center(child: Text(l10n.noResults, style: const TextStyle(color: Colors.white54)))
                          : GridView.builder(
                              padding: const EdgeInsets.all(24),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 20,
                                childAspectRatio: useBackdrop ? 1.5 : 0.6,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, i) {
                                final item = items[i];
                                final card = useBackdrop
                                    ? BackdropCard(
                                        item: item,
                                        serverUrl: serverUrl,
                                        cardLogo: skin?.cardLogo,
                                        hoverExtension: true,
                                        onTap: () => context.push('/player/${item.id}', extra: item),
                                        onImageTap: () => context.push('/home/details/${item.id}', extra: item),
                                      )
                                    : PosterCard(
                                        item: item,
                                        serverUrl: serverUrl,
                                        cardLogo: skin?.cardLogo,
                                        hoverExtension: true,
                                        onTap: () => context.push('/player/${item.id}', extra: item),
                                        onImageTap: () => context.push('/home/details/${item.id}', extra: item),
                                      );
                                return card;
                              },
                            ),
                ),
              ],
            ),
            // Isla flotante superpuesta (como en HomeShell)
            if (showIsland)
              Positioned(
                top: topPadding + 10,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingIslandBar(
                    currentIndex: -1,
                    onNavigateBranch: _goBranch,
                  ),
                ),
              ),
            // Fallback barra lateral / top no flotante - usar Sidebar normal sin shell es complejo,
            // para /movies fuera del shell mostramos solo isla; si skin es left/right mostramos Sidebar lateral
            if (!showIsland && (skin?.sidebarPosition == SidebarPosition.left || skin?.sidebarPosition == SidebarPosition.right))
              Positioned.fill(
                child: Row(
                  children: [
                    if (skin?.sidebarPosition == SidebarPosition.left)
                      Sidebar(currentIndex: -1, onNavigateBranch: _goBranch),
                    const Expanded(child: SizedBox.shrink()),
                    if (skin?.sidebarPosition == SidebarPosition.right)
                      Sidebar(currentIndex: -1, onNavigateBranch: _goBranch),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.icon, required this.label, required this.onTap});
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
        // Asegura foco visible para TV/D-pad (focusColor + canRequestFocus)
        canRequestFocus: true,
        focusColor: Colors.white24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
