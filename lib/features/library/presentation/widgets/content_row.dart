import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import 'poster_card.dart';

/// Fila horizontal de tarjetas con un título (estilo Prime/Disney).
class ContentRow extends StatelessWidget {
  const ContentRow({
    super.key,
    required this.title,
    required this.items,
    required this.serverUrl,
    this.height = 270,
    this.cardWidth = 150,
  });

  final String title;
  final List<BaseItemDto> items;
  final String? serverUrl;

  /// Alto de la fila.
  final double height;

  /// Ancho de cada tarjeta.
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: cardWidth,
              child: PosterCard(
                item: items[i],
                serverUrl: serverUrl,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
