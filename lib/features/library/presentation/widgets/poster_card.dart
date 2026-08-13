import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/scale_button.dart';
import '../../application/image_url.dart';

/// Tarjeta de póster de un item (estilo Prime/Disney).
class PosterCard extends ConsumerWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.serverUrl,
    this.onTap,
  });

  final BaseItemDto item;
  final String? serverUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = serverUrl != null ? itemImageUrl(serverUrl!, item) : null;
    final progress = item.userData?.playedPercentage;
    final skin = ref.watch(skinControllerProvider).value;
    final radius = skin?.cardBorderRadius ?? 10;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);

    return ScaleButton(
      selectedScale: 1.08,
      borderRadius: BorderRadius.circular(radius + 2),
      onPressed: onTap ?? () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: url != null
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _PosterFallback(
                        item: item,
                        color: fallbackColor,
                      ),
                    )
                  : _PosterFallback(item: item, color: fallbackColor),
            ),
          ),
          // Barra de progreso de reproducción (Continuar viendo).
          if (progress != null && progress > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (progress / 100).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            )
          else
            const SizedBox(height: 6),
          Text(
            item.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textPrimary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.item, required this.color});

  final BaseItemDto item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = (item.name ?? '?').substring(0, 1).toUpperCase();
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontSize: 40),
      ),
    );
  }
}
