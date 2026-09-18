import 'package:material_ui/material_ui.dart';

import '../constants/ui_constants.dart';
import 'horizontal_scroll_behavior.dart';

/// Scroll horizontal cuyo ancho de tarjeta se calcula para que quepa un nº
/// de elementos visibles sin desplazar ([count], o el que toque por
/// resolución con [carouselVisibleCount]). Evita repetir el LayoutBuilder
/// y la cuenta en cada scroll de música.
class ResponsiveCarousel extends StatelessWidget {
  const ResponsiveCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 14,
    this.sidePadding = 24,
    this.extraHeight = 64,
    this.count,
    this.physics,
    this.clipBehavior = Clip.hardEdge,
  });

  final int itemCount;

  /// Constructor de cada tarjeta con su ancho ya resuelto.
  final Widget Function(BuildContext context, int index, double cardWidth)
  itemBuilder;

  /// Separación entre tarjetas.
  final double spacing;

  /// Margen lateral del scroll.
  final double sidePadding;

  /// Alto extra sobre la carátula (textos + paddings de la tarjeta).
  final double extraHeight;

  /// Nº visible forzado. Nulo = automático por resolución.
  final int? count;

  final ScrollPhysics? physics;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = cardWidthForCount(
          constraints.maxWidth,
          sidePadding: sidePadding,
          spacing: spacing,
          count: count,
        );
        return SizedBox(
          height: cardWidth + extraHeight,
          child: ScrollConfiguration(
            behavior: const HorizontalScrollBehavior(),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              clipBehavior: clipBehavior,
              physics: physics,
              itemCount: itemCount,
              separatorBuilder: (_, _) => SizedBox(width: spacing),
              itemBuilder: (context, i) => itemBuilder(context, i, cardWidth),
            ),
          ),
        );
      },
    );
  }
}
