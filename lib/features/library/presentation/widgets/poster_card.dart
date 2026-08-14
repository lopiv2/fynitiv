import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/logo_image.dart';
import '../../../../core/widgets/scale_button.dart';
import '../../application/image_url.dart';

/// Tarjeta de póster de un item (estilo Prime/Disney).
class PosterCard extends ConsumerWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.serverUrl,
    this.onTap,
    this.cardLogo,
  });

  final BaseItemDto item;
  final String? serverUrl;
  final VoidCallback? onTap;

  /// Logotipo superpuesto abajo a la derecha (asset o ruta de archivo).
  final String? cardLogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = serverUrl != null ? itemImageUrl(serverUrl!, item) : null;
    final progress = item.userData?.playedPercentage;
    final skin = ref.watch(skinControllerProvider).value;
    final radius = skin?.cardBorderRadius ?? 10;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final logoSize = skin?.cardLogoSize ?? 18;

    return ScaleButton(
      selectedScale: 1.08,
      borderRadius: BorderRadius.circular(radius + 2),
      onPressed: onTap ?? () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radius * 2),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (url != null)
                    Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _PosterFallback(item: item, color: fallbackColor),
                    )
                  else
                    _PosterFallback(item: item, color: fallbackColor),
                  // Barra de progreso de reproducción (Continuar viendo),
                  // superpuesta en la parte inferior de la tarjeta.
                  if (progress != null && progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: (progress / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: Colors.black38,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  // Logotipo superpuesto abajo a la derecha.
                  if (cardLogo != null && cardLogo!.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: LogoImage(logo: cardLogo!, height: logoSize),
                    ),
                ],
              ),
            ),
          ),
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

/// Tarjeta horizontal (16:9) que usa el backdrop del item, para filas tipo
/// "Continuar viendo" cuando el skin prefiere imagen panorámica (Prime).
class BackdropCard extends ConsumerWidget {
  const BackdropCard({
    super.key,
    required this.item,
    required this.serverUrl,
    this.onTap,
    this.cardLogo,
  });

  final BaseItemDto item;
  final String? serverUrl;
  final VoidCallback? onTap;

  /// Logotipo superpuesto abajo a la derecha (asset o ruta de archivo).
  final String? cardLogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backdropUrl = serverUrl != null
        ? itemBackdropUrl(serverUrl!, item)
        : null;
    final posterUrl = serverUrl != null ? itemImageUrl(serverUrl!, item) : null;
    final progress = item.userData?.playedPercentage;
    final skin = ref.watch(skinControllerProvider).value;
    final radius = skin?.cardBorderRadius ?? 10;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final logoSize = skin?.cardLogoSize ?? 18;

    // Prefiere el backdrop; si el item no tiene (o falla), usa el póster en la
    // misma proporción 16:9; si tampoco hay, muestra la letra de relleno.
    final fallback = _PosterFallback(item: item, color: fallbackColor);
    final Widget image;
    if (backdropUrl != null) {
      image = Image.network(
        backdropUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => posterUrl != null
            ? Image.network(
                posterUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      );
    } else if (posterUrl != null) {
      image = Image.network(
        posterUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = fallback;
    }

    return ScaleButton(
      selectedScale: 1.08,
      borderRadius: BorderRadius.circular(radius + 2),
      onPressed: onTap ?? () {},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radius * 6),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  // Barra de progreso de reproducción (Continuar viendo),
                  // superpuesta en la parte inferior de la tarjeta.
                  if (progress != null && progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: (progress / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: Colors.black38,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  // Logotipo superpuesto abajo a la derecha.
                  if (cardLogo != null && cardLogo!.isNotEmpty)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: LogoImage(logo: cardLogo!, height: logoSize),
                    ),
                ],
              ),
            ),
          ),
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
