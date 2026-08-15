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

/// Pantalla con todas las películas del servidor: grid de 6 por fila con
/// desplazamiento infinito. Las tarjetas conservan el comportamiento de
/// hovercard del skin (Amazon Prime la muestra; el resto solo el icono de
/// play al hacer hover).
class AllMoviesScreen extends ConsumerStatefulWidget {
  const AllMoviesScreen({super.key});

  @override
  ConsumerState<AllMoviesScreen> createState() => _AllMoviesScreenState();
}

class _AllMoviesScreenState extends ConsumerState<AllMoviesScreen> {
  final ScrollController _controller = ScrollController();
  int _loadedPages = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore) return;
    // No cargar más si la última página todavía se está resolviendo.
    if (ref.read(allMoviesPageProvider(_loadedPages - 1)).isLoading) return;
    if (_controller.position.extentAfter < 600) {
      setState(() => _loadedPages++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final skin = ref.watch(skinControllerProvider).value;
    // En Prime las tarjetas del home son backdrops (16:9); se respeta aquí.
    final useBackdrop =
        (skin?.cardImageType ?? CardImageType.poster) == CardImageType.backdrop;

    // Se observan las páginas cargadas y se concatenan sus items.
    final pages = [
      for (var i = 0; i < _loadedPages; i++)
        ref.watch(allMoviesPageProvider(i)),
    ];
    final items = [
      for (final page in pages) ...(page.value ?? const <BaseItemDto>[]),
    ];
    final last = pages.last;
    _hasMore =
        last.isLoading || (last.value?.length ?? 0) >= kAllMoviesPageSize;
    final loadingMore = last.isLoading;
    // Carga inicial: sin items y la primera página resolviéndose.
    final initialLoading = items.isEmpty && pages.first.isLoading;

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con el título y el botón de volver.
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: initialLoading
                  ? const Center(child: AppLoader())
                  : GridView.builder(
                      controller: _controller,
                      padding: const EdgeInsets.all(24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 20,
                        // Backdrop (16:9) es mucho más ancho que un póster (2:3).
                        childAspectRatio: useBackdrop ? 1.5 : 0.6,
                      ),
                      itemCount: items.length + (loadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= items.length) {
                          return const Center(child: AppLoader());
                        }
                        final item = items[i];
                        final card = useBackdrop
                            ? BackdropCard(
                                item: item,
                                serverUrl: serverUrl,
                                cardLogo: skin?.cardLogo,
                                hoverExtension: true,
                                onTap: () => context.push(
                                  '/player/${item.id}',
                                  extra: item,
                                ),
                              )
                            : PosterCard(
                                item: item,
                                serverUrl: serverUrl,
                                cardLogo: skin?.cardLogo,
                                hoverExtension: true,
                                onTap: () => context.push(
                                  '/player/${item.id}',
                                  extra: item,
                                ),
                              );
                        return card;
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
