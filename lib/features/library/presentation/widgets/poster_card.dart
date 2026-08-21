import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/hover_play_card.dart';
import '../../../../core/widgets/logo_image.dart';
import '../../application/image_url.dart';
import 'poster_fallback.dart';

/// Tarjeta de póster de un item (estilo Prime/Disney).
class PosterCard extends ConsumerWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.serverUrl,
    this.onTap,
    this.onImageTap,
    this.cardLogo,
    this.hoverExtension = false,
    this.onHoverChanged,
    this.onPointerSignal,
    this.overlayBelowEntry,
  });

  final BaseItemDto item;
  final String? serverUrl;
  final VoidCallback? onTap;
  final VoidCallback? onImageTap;

  /// Logotipo superpuesto abajo a la derecha (asset o ruta de archivo).
  final String? cardLogo;

  /// Permite el panel de extensión al hacer hover (estilo Prime). Solo debe
  /// activarse en filas horizontales, no en grids.
  final bool hoverExtension;

  /// Notifica el hover de la tarjeta (para reordenar el pintado en la fila).
  final ValueChanged<bool>? onHoverChanged;
  final ValueChanged<PointerSignalEvent>? onPointerSignal;
  final OverlayEntry? Function()? overlayBelowEntry;

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
    final showExtension = hoverExtension && (skin?.cardHoverExtension ?? false);
    // Elemento de "Continuar viendo" (tiene posición de reproducción): el
    // botón del panel muestra "Reanudar" en lugar de "Ver ahora".
    final resume = (item.userData?.playbackPositionTicks ?? 0) > 0;

    return HoverPlayCard(
      title: item.name ?? '',
      onPlay: onTap ?? () {},
      onImageTap: onImageTap,
      showExtension: showExtension,
      onHoverChanged: onHoverChanged,
      onPointerSignal: onPointerSignal,
      overlayBelowEntry: overlayBelowEntry,
      resume: resume,
      ageRating: item.officialRating,
      year: item.productionYear,
      runTimeTicks: item.runTimeTicks,
      overview: item.overview,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // La imagen usa AspectRatio para no requerir altura finita del padre.
          // Así funciona tanto en GridView (con constraints finitas) como en
          // ListView vertical sin altura fija (evita Expanded con h=Infinity).
          Flexible(
            fit: FlexFit.loose,
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: HoverPlayRadius(
                radius: radius * 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url != null)
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            PosterFallback(item: item, color: fallbackColor),
                      )
                    else
                      PosterFallback(item: item, color: fallbackColor),
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
          ),
          // Con el panel de extensión (Prime) el título no se muestra bajo la
          // imagen: aparece en el propio panel al hacer hover, evitando que
          // se vea dos veces.
          if (!showExtension) ...[
            const SizedBox(height: 6),
            Text(
              item.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textPrimary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
