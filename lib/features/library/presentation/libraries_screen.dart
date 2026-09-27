import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../application/library_providers.dart';
import 'widgets/library_grid_card.dart';

/// Grid con todas las bibliotecas del usuario (/library).
///
/// Destino del item único "Biblioteca" de la sidebar en el skin Disney:
/// evita el scroll vertical de bibliotecas en la barra lateral.
/// Cada tarjeta navega a `/library/:viewId` como antes.
class LibrariesScreen extends ConsumerWidget {
  const LibrariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final viewsAsync = ref.watch(userViewsProvider);

    return viewsAsync.when(
      loading: () => const Center(child: AppLoader()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            IconButton(
              tooltip: l10n.retry,
              onPressed: () => ref.invalidate(userViewsProvider),
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
      ),
      data: (views) {
        if (views.isEmpty) {
          return Center(
            child: Text(
              l10n.librariesEmpty,
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
        return FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: libraryPageTopPadding(context, skin)),
              ),
              SliverToBoxAdapter(
                child: LibraryPageHeader(
                  title: l10n.library,
                  subtitle: l10n.yourLibrary,
                  showBack: false,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisSpacing: 54,
                    crossAxisSpacing: 34,
                    childAspectRatio: 1.55,
                  ),
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final v = views[i];
                    return LibraryGridCard(
                      view: v,
                      onTap: () {
                        final id = v.id ?? '';
                        if (id.isNotEmpty) context.go('/library/$id');
                      },
                    );
                  }, childCount: views.length),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
