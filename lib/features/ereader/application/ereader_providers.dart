import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../../core/skin/skin.dart';
import '../../../core/skin/skin_presets.dart';
import '../../library/application/library_providers.dart';

/// Skin fijo del E-Reader. No cambia con el skin global (VOD, etc.).
const Skin eReaderSkin = SkinPresets.jellyfinDefault;

/// Libros/cómics recién añadidos a la biblioteca (para la fila superior).
final eReaderLatestBooksProvider = FutureProvider<List<BaseItemDto>>((
  ref,
) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: const [BaseItemKind.book],
    sortBy: const [ItemSortBy.dateCreated],
    sortOrder: const [SortOrder.descending],
    limit: 20,
    fields: const [
      ItemFields.dateCreated,
      ItemFields.overview,
      ItemFields.primaryImageAspectRatio,
    ],
    enableImageTypes: const [ImageType.primary],
  );
  return res.data?.items ?? [];
});

/// Args del grid paginado de todos los libros/cómics.
class EReaderBooksArgs {
  const EReaderBooksArgs({required this.pageIndex, this.sortAscending = true});
  final int pageIndex;
  final bool sortAscending;

  @override
  bool operator ==(Object other) =>
      other is EReaderBooksArgs &&
      other.pageIndex == pageIndex &&
      other.sortAscending == sortAscending;

  @override
  int get hashCode => Object.hash(pageIndex, sortAscending);
}

/// Página del grid con todos los libros/cómics (reutiliza el paginado genérico).
final eReaderBooksPageProvider =
    FutureProvider.family<List<BaseItemDto>, EReaderBooksArgs>((ref, args) {
      return ref.watch(
        libraryFilteredPageProvider(
          LibraryFilteredArgs(
            viewId: '',
            pageIndex: args.pageIndex,
            sortAscending: args.sortAscending,
            includeItemTypes: const [BaseItemKind.book],
          ),
        ).future,
      );
    });

/// Total de libros/cómics (para calcular el número de páginas).
final eReaderBooksCountProvider = FutureProvider<int>((ref) {
  return ref.watch(
    libraryFilteredCountProvider(
      const LibraryFilteredArgs(
        viewId: '',
        pageIndex: 0,
        includeItemTypes: [BaseItemKind.book],
      ),
    ).future,
  );
});
