import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/skin/skin.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../library/application/library_providers.dart';
import '../../../library/presentation/widgets/content_row.dart';

/// `true` si las tarjetas de Seerr deben usar backdrop (16:9) en lugar de
/// póster vertical, según el skin activo.
bool seerrUseBackdrop(Skin? skin) =>
    (skin?.cardImageType ?? CardImageType.poster) == CardImageType.backdrop;

/// Fila de contenido de Seerr construida sobre el [ContentRow] del resto de la
/// app: mismo look, hover, foco (TV) y tamaños del skin que los scrolls de
/// Descubrir, Home o biblioteca.
///
/// Los items se reciben ya mapeados a `BaseItemDto`; la imagen de cada uno se
/// resuelve con [imageUrlFor] (contenido externo, p. ej. TMDB).
class SeerrContentRow extends ConsumerWidget {
  const SeerrContentRow({
    super.key,
    required this.title,
    required this.items,
    required this.onItemTap,
    this.imageUrlFor,
    this.cardLogoFor,
    this.cornerLogosFor,
    this.cornerBadgeFor,
    this.hoverActionLabel,
    this.useBackdrop,
  });

  final String title;
  final List<BaseItemDto> items;

  /// Se invoca al pulsar (o pulsar la imagen de) una tarjeta.
  final void Function(BaseItemDto item) onItemTap;

  /// URL de imagen explícita por item (TMDB).
  final String? Function(BaseItemDto item)? imageUrlFor;

  /// Logo de tarjeta por item (p. ej. Jellyfin si ya está en la biblioteca).
  final String? Function(BaseItemDto item)? cardLogoFor;

  /// Logos de plataformas por item (esquina de la tarjeta).
  final List<String> Function(BaseItemDto item)? cornerLogosFor;

  /// Badge por item (esquina superior izquierda de la carátula).
  final Widget? Function(BaseItemDto item)? cornerBadgeFor;

  /// Texto del botón principal del hover ("Solicitar", "Detalles"…).
  final String? hoverActionLabel;

  /// `null` = derivar del skin (`cardImageType`).
  final bool? useBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();
    final skin = ref.watch(skinControllerProvider).value;
    final serverUrl = ref.watch(authServerUrlProvider);
    final scale = skin?.homeCardScale ?? 1.0;
    final backdrop = useBackdrop ?? seerrUseBackdrop(skin);
    return Padding(
      padding: const EdgeInsets.only(top: kBetweenSectionsGap),
      child: ContentRow(
        title: title,
        items: items,
        serverUrl: serverUrl,
        height: (skin?.homeRowHeight ?? 270) * scale,
        cardWidth: (skin?.homeCardWidth ?? 150) * scale,
        itemSpacing: skin?.itemSpacing,
        useBackdrop: backdrop,
        cardLogo: null,
        cardLogoFor: cardLogoFor,
        showPlayIcon: false,
        showHoverIncludedBadge: false,
        hoverActionLabel: hoverActionLabel,
        excludePlaceholders: false,
        imageUrlFor: imageUrlFor,
        cornerLogosFor: cornerLogosFor,
        cornerBadgeFor: cornerBadgeFor,
        onItemTap: onItemTap,
        onItemImageTap: onItemTap,
      ),
    );
  }
}
