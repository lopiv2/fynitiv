import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../application/library_providers.dart';
import 'widgets/poster_card.dart';

/// Grid de items de una biblioteca concreta (/library/:viewId).
class LibraryViewScreen extends ConsumerWidget {
  const LibraryViewScreen({super.key, required this.viewId});

  final String viewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverUrl = ref.watch(authServerUrlProvider);
    final items = ref.watch(libraryItemsProvider(viewId));

    return Scaffold(
      body: DashboardBackground(
        child: items.when(
          loading: () =>
              const Center(child: AppLoader()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 20,
                crossAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) => AppHover(
                effect: AppHoverEffect.scaleHighlightOutline,
                config: AppHoverConfig.scaleHighlightOutline(
                  scale: 1.04,
                  radius: BorderRadius.circular(12),
                  outlineHoveredColor: Colors.white,
                  outlineHoveredWidth: 2,
                ),
                onTap: () {},
                child: PosterCard(
                  item: list[i],
                  serverUrl: serverUrl,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
