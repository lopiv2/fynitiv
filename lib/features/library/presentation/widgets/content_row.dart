import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/navigation/platform_mode.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/app_hover.dart';
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
    this.itemSpacing,
    this.useBackdrop = false,
    this.useSeriesPoster = false,
    this.cardLogo,
    this.onItemTap,
    this.onItemImageTap,
    this.onSeeMore,
    this.showTitle = true,
  });

  final String title;
  final List<BaseItemDto> items;
  final String? serverUrl;

  /// Alto de la fila.
  final double height;

  /// Ancho de cada tarjeta (póster vertical).
  final double cardWidth;

  /// Espacio horizontal entre elementos. Si es `null` usa el del skin
  /// (`itemSpacing`, 12 por defecto; backdrop antes 20).
  final double? itemSpacing;

  /// Muestra tarjetas horizontales (backdrop 16:9) en lugar de pósteres.
  final bool useBackdrop;

  /// Para episodios (A continuación): usa el póster principal de la serie en
  /// lugar del capítulo, como pide el diseño.
  final bool useSeriesPoster;

  /// Logotipo superpuesto abajo a la derecha de cada tarjeta (asset o ruta).
  final String? cardLogo;

  /// Se invoca al pulsar una tarjeta de la fila.
  final void Function(BaseItemDto item)? onItemTap;

  /// Accion al pulsar la imagen expandida de una tarjeta.
  final void Function(BaseItemDto item)? onItemImageTap;

  /// Acción de "Ver más >" en el título de la fila. Si es null no se muestra.
  final VoidCallback? onSeeMore;

  /// Oculta el titulo cuando la fila ya tiene una cabecera propia.
  final bool showTitle;

  @override
  ConsumerState<ContentRow> createState() => _ContentRowState();
}

class _ContentRowState extends ConsumerState<ContentRow> {
  final ScrollController _controller = ScrollController();
  final LayerLink _rowLink = LayerLink();
  final GlobalKey _rowKey = GlobalKey();
  OverlayEntry? _arrowOverlay;
  Timer? _arrowHideTimer;
  ScrollPosition? _pageScrollPosition;

  /// Índice de la tarjeta con hover (para reordenar el pintado y que la
  /// tarjeta escalada se superponga a las vecinas). -1 = ninguna.
  int _hoveredIndex = -1;

  /// Las flechas se muestran mientras el puntero está sobre la fila o sobre
  /// una hovercard expandida.
  bool _rowHovered = false;

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
    _arrowHideTimer?.cancel();
    _arrowOverlay?.remove();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (mounted) {
      setState(() {});
      _arrowOverlay?.markNeedsBuild();
    }
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
  double get _spacing {
    if (widget.itemSpacing != null) return widget.itemSpacing!;
    // Fallback al skin (12 por defecto) o valores legacy por tipo.
    final skinSpacing = ref.watch(skinControllerProvider).value?.itemSpacing;
    if (skinSpacing != null) return skinSpacing;
    return widget.useBackdrop ? 20 : 12;
  }

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

  void _scrollPage(double direction, double viewportWidth) {
    _scrollBy(direction * viewportWidth * 0.8);
  }

  void _onPagePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    _pageScrollPosition?.pointerScroll(event.scrollDelta.dy);
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
    if (_hoveredIndex != next || _rowHovered != value) {
      setState(() {
        _hoveredIndex = next;
        if (value) _rowHovered = true;
      });
    }
    if (value) {
      _showArrowOverlay();
      // La hovercard se inserta inmediatamente despues de esta notificacion.
      // Volver a elevar las flechas al final del frame evita carreras durante
      // la transicion entre dos tarjetas con hover.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hoveredIndex == index) _showArrowOverlay();
      });
    }
  }

  void _showArrowOverlay() {
    _arrowHideTimer?.cancel();
    _arrowOverlay?.remove();
    final entry = OverlayEntry(
      builder: (_) {
        final rowBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
        final width = rowBox?.size.width ?? MediaQuery.sizeOf(context).width;
        return CompositedTransformFollower(
          link: _rowLink,
          showWhenUnlinked: false,
          child: MouseRegion(
            hitTestBehavior: HitTestBehavior.deferToChild,
            onEnter: (_) => _arrowHideTimer?.cancel(),
            onExit: (_) => _scheduleArrowOverlayHide(),
            child: SizedBox(
              width: width,
              height: _rowHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: 6,
                    top: (_rowHeight - 44) / 2,
                    child: _scrollArrow(
                      icon: Icons.chevron_left,
                      enabled:
                          _controller.hasClients &&
                          _controller.offset >
                              _controller.position.minScrollExtent,
                      onPressed: () =>
                          _scrollPage(-1, MediaQuery.sizeOf(context).width),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: (_rowHeight - 44) / 2,
                    child: _scrollArrow(
                      icon: Icons.chevron_right,
                      enabled:
                          _controller.hasClients &&
                          _controller.offset <
                              _controller.position.maxScrollExtent,
                      onPressed: () =>
                          _scrollPage(1, MediaQuery.sizeOf(context).width),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _arrowOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  /// Reubica las flechas en la cima antes de que una hovercard se inserte.
  /// Devuelve la misma entrada que se usara como referencia `below`.
  OverlayEntry? _prepareArrowOverlayForHover() {
    _showArrowOverlay();
    return _arrowOverlay;
  }

  void _scheduleArrowOverlayHide() {
    _arrowHideTimer?.cancel();
    _arrowHideTimer = Timer(const Duration(milliseconds: 180), () {
      if (_hoveredIndex == -1) {
        _arrowOverlay?.remove();
        _arrowOverlay = null;
        if (mounted) setState(() => _rowHovered = false);
      }
    });
  }

  Widget _scrollArrow({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _rowHovered && enabled ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_rowHovered || !enabled,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 28),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          ),
        ),
      ),
    );
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
    final isTv = (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) == PlatformMode.tv;
    return [
      for (final i in indices)
        Positioned(
          key: ValueKey('content_card_$i'),
          left: i * step,
          top: 0,
          width: _cardWidth,
          child: _wrapForTv(
            isTv: isTv,
            onTap: widget.onItemTap == null ? null : () => widget.onItemTap!(items[i]),
            child: widget.useBackdrop
                ? BackdropCard(
                    item: items[i],
                    serverUrl: widget.serverUrl,
                    cardLogo: widget.cardLogo,
                    hoverExtension: true,
                    useSeriesPoster: widget.useSeriesPoster,
                    onTap: widget.onItemTap == null ? null : () => widget.onItemTap!(items[i]),
                    onImageTap: widget.onItemImageTap == null ? null : () => widget.onItemImageTap!(items[i]),
                    onHoverChanged: (v) => _onCardHover(i, v),
                    onPointerSignal: _onPagePointerSignal,
                    overlayBelowEntry: _prepareArrowOverlayForHover,
                  )
                : PosterCard(
                    item: items[i],
                    serverUrl: widget.serverUrl,
                    cardLogo: widget.cardLogo,
                    hoverExtension: true,
                    useSeriesPoster: widget.useSeriesPoster,
                    onTap: widget.onItemTap == null ? null : () => widget.onItemTap!(items[i]),
                    onImageTap: widget.onItemImageTap == null ? null : () => widget.onItemImageTap!(items[i]),
                    onHoverChanged: (v) => _onCardHover(i, v),
                    onPointerSignal: _onPagePointerSignal,
                    overlayBelowEntry: _prepareArrowOverlayForHover,
                  ),
          ),
        ),
    ];
  }

  Widget _wrapForTv({required bool isTv, required VoidCallback? onTap, required Widget child}) {
    if (onTap == null) return child;
    return AppHover(
      effect: AppHoverEffect.scaleHighlightOutline,
      config: AppHoverConfig.scaleHighlightOutline(
        scale: 1.04,
        radius: BorderRadius.circular(12),
        outlineHoveredColor: Colors.white,
        outlineHoveredWidth: 2,
      ),
      onTap: onTap,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    // Separación vertical entre filas, definida por el skin.
    final rowSpacing =
        ref.watch(skinControllerProvider).value?.rowSpacing ?? 24;
    _pageScrollPosition = Scrollable.maybeOf(context)?.position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ScrollTitle(
              title: widget.title,
              onSeeMore: widget.onSeeMore,
            ),
          ),
          const SizedBox(height: 12),
        ],
        FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SizedBox(
            height: _rowHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Listener de bajo nivel: captura el arrastre con el botón del
                // medio del ratón para desplazar la fila en horizontal. La rueda
                // (PointerScrollEvent) no se intercepta, así que sigue haciendo
                // scroll vertical de página.
                MouseRegion(
                  onEnter: (_) {
                    setState(() => _rowHovered = true);
                    _showArrowOverlay();
                  },
                  onExit: (_) => _scheduleArrowOverlayHide(),
                  child: CompositedTransformTarget(
                    key: _rowKey,
                    link: _rowLink,
                    child: Listener(
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
                  ),
                ),
              ],
          ),
        ),
        ),
        SizedBox(height: rowSpacing),
      ],
    );
  }
}
