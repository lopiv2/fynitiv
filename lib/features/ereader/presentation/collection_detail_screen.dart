import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/library_page_header.dart';
import '../application/ereader_providers.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/widgets/poster_card.dart';

/// Detalle de una colección on-the-fly: grid con sus libros hacia el detalle.
class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.collection});

  final EReaderCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final globalSkin = ref.watch(skinControllerProvider).value;
    final serverUrl = ref.watch(authServerUrlProvider);

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: libraryPageTopPadding(context, globalSkin)),
            LibraryPageHeader(title: collection.title),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.58,
                ),
                itemCount: collection.items.length,
                itemBuilder: (context, i) {
                  final item = collection.items[i];
                  return PosterCard(
                    item: item,
                    serverUrl: serverUrl,
                    hoverExtension: true,
                    onTap: () => context.push(
                      '/ereader/details/${item.id}',
                      extra: item,
                    ),
                    onImageTap: () => context.push(
                      '/ereader/details/${item.id}',
                      extra: item,
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
