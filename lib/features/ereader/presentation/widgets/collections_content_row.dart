import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../library/application/image_url.dart';
import '../../../library/application/library_providers.dart';
import '../../../library/presentation/widgets/content_row.dart';
import '../../application/ereader_providers.dart';

/// DTO sintético para pintar una colección con las tarjetas estándar.
/// La imagen real llega por `imageUrlFor`; el `id` (`collection:$index`)
/// solo sirve para recuperar la colección en los callbacks.
BaseItemDto collectionTileDto(int index, EReaderCollection collection) =>
    BaseItemDto(id: 'collection:$index', name: collection.title);

/// Recupera la colección de un DTO sintético por su índice.
EReaderCollection? collectionOfTile(
  BaseItemDto dto,
  List<EReaderCollection> collections,
) {
  final id = dto.id ?? '';
  final index = int.tryParse(id.split(':').last);
  if (index == null || index < 0 || index >= collections.length) return null;
  return collections[index];
}

/// Portada de la colección: primer libro con imagen disponible.
String? collectionCoverUrl(String? serverUrl, EReaderCollection collection) {
  if (serverUrl == null) return null;
  for (final item in collection.items) {
    final url = singleCardImageUrl(serverUrl, item, CardImageKind.primary);
    if (url != null) return url;
  }
  return null;
}

/// Pastilla con el nº de títulos para la esquina de la tarjeta.
Widget collectionCountBadge(int count) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.book_outlined, color: Colors.white, size: 12),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Fila de colecciones construida sobre el [ContentRow] del resto de la app:
/// mismo look, hover, foco (TV) y tamaños del skin que los scrolls de Home o
/// biblioteca (patrón de `SeerrContentRow`).
class CollectionsContentRow extends ConsumerWidget {
  const CollectionsContentRow({
    super.key,
    required this.title,
    required this.collections,
    required this.onCollectionTap,
    this.onSeeMore,
  });

  final String title;
  final List<EReaderCollection> collections;
  final ValueChanged<EReaderCollection> onCollectionTap;
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (collections.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final serverUrl = ref.watch(authServerUrlProvider);
    final scale = skin?.homeCardScale ?? 1.0;
    final tiles = [
      for (var i = 0; i < collections.length; i++)
        collectionTileDto(i, collections[i]),
    ];

    EReaderCollection? lookup(BaseItemDto dto) =>
        collectionOfTile(dto, collections);

    return Padding(
      padding: const EdgeInsets.only(top: kBetweenSectionsGap),
      child: ContentRow(
        title: title,
        items: tiles,
        serverUrl: serverUrl,
        height: (skin?.homeRowHeight ?? 270) * scale,
        cardWidth: (skin?.homeCardWidth ?? 150) * scale,
        itemSpacing: skin?.itemSpacing,
        showPlayIcon: false,
        showHoverIncludedBadge: false,
        hideYear: true,
        hoverActionLabel: l10n.details,
        imageUrlFor: (dto) {
          final collection = lookup(dto);
          if (collection == null) return null;
          return collectionCoverUrl(serverUrl, collection);
        },
        cornerBadgeFor: (dto) {
          final collection = lookup(dto);
          if (collection == null) return null;
          return collectionCountBadge(collection.items.length);
        },
        onItemTap: (dto) {
          final collection = lookup(dto);
          if (collection != null) onCollectionTap(collection);
        },
        onItemImageTap: (dto) {
          final collection = lookup(dto);
          if (collection != null) onCollectionTap(collection);
        },
        onSeeMore: onSeeMore,
      ),
    );
  }
}
