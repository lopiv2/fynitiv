import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/horizontal_scroll_behavior.dart';
import '../../../../core/widgets/scroll_title.dart';
import 'backdrop_card.dart';
import 'poster_card.dart';

/// Fila horizontal de tarjetas con un título (estilo Prime/Disney).
///
/// La rueda del ratón sigue desplazando la página (arriba/abajo); para
/// desplazar la fila en horizontal se muestran flechas al hacer hover y se
/// puede arrastrar con el ratón.
class ContentRow extends ConsumerStatefulWidget {
  const ContentRow({
    super.key,
    required this.title,
    required this.items,
    required this.serverUrl,
    this.height = 270,
    this.cardWidth = 150,
    this.useBackdrop = false,
    this.cardLogo,
    this.onItemTap,
    this.onSeeMore,
  });

  final String title;
  final List<BaseItemDto> items;
  final String? serverUrl;

  /// Alto de la fila.
  final double height;

  /// Ancho de cada tarjeta (póster vertical).
  final double cardWidth;

  /// Muestra tarjetas horizontales (backdrop 16:9) en lugar de pósteres.
  final bool useBackdrop;

  /// Logotipo superpuesto abajo a la derecha de cada tarjeta (asset o ruta).
  final String? cardLogo;

  /// Se invoca al pulsar una tarjeta de la fila.
  final void Function(BaseItemDto item)? onItemTap;

  /// Acción de "Ver más >" en el título de la fila. Si es null no se muestra.
  final VoidCallback? onSeeMore;

  @override
  ConsumerState<ContentRow> createState() => _ContentRowState();
}

class _ContentRowState extends ConsumerState<ContentRow> {
  final ScrollController _controller = ScrollController();

  /// Índice de la tarjeta con hover (para reordenar el pintado y que la
  /// tarjeta escalada se superponga a las vecinas). -1 = ninguna.
  int _hoveredIndex = -1;

  /// Estado del arrastre con el botón del medio del ratón (scroll horizontal).
  bool _middleDragging = false;
  double _lastDragX = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  /// Ancho de cada tarjeta (el fijado por el skin).
  double get _cardWidth => widget.cardWidth;

  /// Altura de la fila, derivada dinámicamente del ancho de tarjeta para que
  /// las tarjetas midan lo fijado. Con backdrop (16:9) la altura es la de la
  /// imagen; sin backdrop se mantiene el alto del skin. El hueco entre filas
  /// lo controla [rowSpacing].
  double get _rowHeight {
    if (widget.useBackdrop) return _cardWidth * 9 / 16;
    return widget.height;
  }

  /// Separación entre tarjetas.
  double get _spacing => widget.useBackdrop ? 20 : 12;

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = (_controller.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// Inicia el arrastre con el botón del medio del ratón (scroll horizontal).
  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kMiddleMouseButton != 0) {
      _middleDragging = true;
      _lastDragX = event.position.dx;
    }
  }

  /// Desplaza la fila horizontalmente mientras se arrastra con el botón medio.
  void _onPointerMove(PointerMoveEvent event) {
    if (!_middleDragging) return;
    final delta = event.position.dx - _lastDragX;
    _lastDragX = event.position.dx;
    if (delta != 0) _scrollBy(-delta);
  }

  /// Finaliza el arrastre con el botón del medio.
  void _onPointerUp(PointerUpEvent event) {
    _middleDragging = false;
  }

  /// Actualiza el índice de la tarjeta con hover.
  void _onCardHover(int index, bool value) {
    final next = value ? index : -1;
    if (_hoveredIndex != next) setState(() => _hoveredIndex = next);
  }

  /// Construye las tarjetas en un único [Stack] horizontal. El orden de pintado
  /// se reordena para que la tarjeta con hover sea la última (y quede por
  /// encima de las vecinas al escalar con el [ScaleButton]).
  List<Widget> _buildStackedItems() {
    final items = widget.items;
    final indices = List<int>.generate(items.length, (i) => i);
    indices.sort((a, b) {
      if (a == _hoveredIndex) return 1;
      if (b == _hoveredIndex) return -1;
      return a.compareTo(b);
    });
    final step = _cardWidth + _spacing;
    return [
      for (final i in indices)
        Positioned(
          key: ValueKey('content_card_$i'),
          left: i * step,
          top: 0,
          width: _cardWidth,
          child: widget.useBackdrop
              ? BackdropCard(
                  item: items[i],
                  serverUrl: widget.serverUrl,
                  cardLogo: widget.cardLogo,
                  hoverExtension: true,
                  onTap: widget.onItemTap == null
                      ? null
                      : () => widget.onItemTap!(items[i]),
                  onHoverChanged: (v) => _onCardHover(i, v),
                )
              : PosterCard(
                  item: items[i],
                  serverUrl: widget.serverUrl,
                  cardLogo: widget.cardLogo,
                  hoverExtension: true,
                  onTap: widget.onItemTap == null
                      ? null
                      : () => widget.onItemTap!(items[i]),
                  onHoverChanged: (v) => _onCardHover(i, v),
                ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    // Separación vertical entre filas, definida por el skin.
    final rowSpacing =
        ref.watch(skinControllerProvider).value?.rowSpacing ?? 24;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ScrollTitle(
              title: widget.title,
              onSeeMore: widget.onSeeMore,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _rowHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Listener de bajo nivel: captura el arrastre con el botón del
                // medio del ratón para desplazar la fila en horizontal. La rueda
                // (PointerScrollEvent) no se intercepta, así que sigue haciendo
                // scroll vertical de página.
                Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  behavior: HitTestBehavior.translucent,
                  child: ScrollConfiguration(
                    behavior: const HorizontalScrollBehavior(),
                    child: SingleChildScrollView(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width:
                            widget.items.length * _cardWidth +
                            (widget.items.length - 1) * _spacing,
                        height: _rowHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: _buildStackedItems(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: rowSpacing),
        ],
    );
  }
}
