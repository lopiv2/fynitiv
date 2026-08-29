import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/horizontal_scroll_behavior.dart';
import '../../../../core/widgets/scroll_title.dart';
import '../../domain/romm_game.dart';
import 'game_continue_card.dart';
import 'game_poster_card.dart';

/// Fila horizontal para ROMM, replica exactamente `ContentRow` de Jellyfin
/// (flechas overlay, drag medio, HoverPlayCard, reordenado de pintado)
/// pero tipada para `RommGame` y usando `GamePosterCard`.
/// Mantiene wrapper y permite `cardBuilder` para estilos distintos (ej. continuar jugando con `AppHover`).
class GameContentRow extends ConsumerStatefulWidget {
  const GameContentRow({
    super.key,
    required this.title,
    required this.games,
    this.headers,
    this.height = 270,
    this.cardWidth = 150,
    this.onGameTap,
    this.onSeeMore,
    this.showTitle = true,
    this.cardBuilder,
    this.useContinueStyle = false,
  });

  final String title;
  final List<RommGame> games;
  final Map<String, String>? headers;
  final double height;
  final double cardWidth;
  final void Function(RommGame game)? onGameTap;
  final VoidCallback? onSeeMore;
  final bool showTitle;
  /// Builder opcional para customizar la card (si es null usa GamePosterCard).
  final Widget Function(
    BuildContext context,
    RommGame game,
    Map<String, String>? headers,
    VoidCallback? onTap,
    ValueChanged<bool> onHoverChanged,
    ValueChanged<PointerSignalEvent> onPointerSignal,
    OverlayEntry? Function() overlayBelowEntry,
  )? cardBuilder;
  /// Atajo para usar el estilo “Continuar jugando” con AppHover (foto).
  final bool useContinueStyle;

  @override
  ConsumerState<GameContentRow> createState() => _GameContentRowState();
}

class _GameContentRowState extends ConsumerState<GameContentRow> {
  final ScrollController _controller = ScrollController();
  final LayerLink _rowLink = LayerLink();
  final GlobalKey _rowKey = GlobalKey();
  OverlayEntry? _arrowOverlay;
  Timer? _arrowHideTimer;
  ScrollPosition? _pageScrollPosition;

  int _hoveredIndex = -1;
  bool _rowHovered = false;
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

  double get _cardWidth => widget.cardWidth;
  double get _rowHeight => widget.height;
  double get _spacing => 12;

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = (_controller.offset + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    _controller.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  void _scrollPage(double direction, double viewportWidth) {
    _scrollBy(direction * viewportWidth * 0.8);
  }

  void _onPagePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    _pageScrollPosition?.pointerScroll(event.scrollDelta.dy);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kMiddleMouseButton != 0) {
      _middleDragging = true;
      _lastDragX = event.position.dx;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_middleDragging) return;
    final delta = event.position.dx - _lastDragX;
    _lastDragX = event.position.dx;
    if (delta != 0) _scrollBy(-delta);
  }

  void _onPointerUp(PointerUpEvent event) {
    _middleDragging = false;
  }

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
                      enabled: _controller.hasClients && _controller.offset > _controller.position.minScrollExtent,
                      onPressed: () => _scrollPage(-1, MediaQuery.sizeOf(context).width),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: (_rowHeight - 44) / 2,
                    child: _scrollArrow(
                      icon: Icons.chevron_right,
                      enabled: _controller.hasClients && _controller.offset < _controller.position.maxScrollExtent,
                      onPressed: () => _scrollPage(1, MediaQuery.sizeOf(context).width),
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

  Widget _scrollArrow({required IconData icon, required bool enabled, required VoidCallback onPressed}) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _rowHovered && enabled ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_rowHovered || !enabled,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72), shape: BoxShape.circle),
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

  List<Widget> _buildStackedItems() {
    final items = widget.games;
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
          key: ValueKey('game_card_$i'),
          left: i * step,
          top: 0,
          width: _cardWidth,
          child: _buildCardForIndex(i),
        ),
    ];
  }

  Widget _buildCardForIndex(int i) {
    final game = widget.games[i];
    final onTap = widget.onGameTap == null ? null : () => widget.onGameTap!(game);
    void onHover(bool v) => _onCardHover(i, v);
    if (widget.cardBuilder != null) {
      return widget.cardBuilder!(context, game, widget.headers, onTap, onHover, _onPagePointerSignal, _prepareArrowOverlayForHover);
    }
    if (widget.useContinueStyle) {
      return GameContinueCard(
        game: game,
        headers: widget.headers,
        onTap: onTap,
        onHoverChanged: onHover,
        onPointerSignal: _onPagePointerSignal,
        overlayBelowEntry: _prepareArrowOverlayForHover,
      );
    }
    return GamePosterCard(
      game: game,
      headers: widget.headers,
      onTap: onTap,
      onImageTap: onTap,
      onHoverChanged: onHover,
      onPointerSignal: _onPagePointerSignal,
      overlayBelowEntry: _prepareArrowOverlayForHover,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.games.isEmpty) return const SizedBox.shrink();
    final rowSpacing = ref.watch(skinControllerProvider).value?.rowSpacing ?? 24;
    _pageScrollPosition = Scrollable.maybeOf(context)?.position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ScrollTitle(title: widget.title, onSeeMore: widget.onSeeMore),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: _rowHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
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
                          width: widget.games.length * _cardWidth + (widget.games.length - 1) * _spacing,
                          height: _rowHeight,
                          child: Stack(clipBehavior: Clip.none, children: _buildStackedItems()),
                        ),
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
