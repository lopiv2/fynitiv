import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:flutter/services.dart';

import '../../../../core/navigation/platform_mode.dart';
import '../../../../core/navigation/tv_focus_nodes.dart';
import '../../../../core/skin/skin.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/age_rating_badge.dart';
import '../../../../core/widgets/included_badge.dart';
import '../../../../core/widgets/round_icon_button.dart';
import '../../../../core/widgets/scale_button.dart';
import '../../../../core/widgets/scroll_title.dart';
import '../../../../core/widgets/watch_now_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/image_url.dart';
import '../../application/library_providers.dart';

/// Carrusel de banners horizontales genérico (estilo Disney+/Prime).
///
/// Reutilizable por cualquier skin mediante sus parámetros: borde, altura,
/// alineación de puntos, tamaño del logo, etc.
class FeaturedSlider extends ConsumerStatefulWidget {
  const FeaturedSlider({
    super.key,
    required this.title,
    required this.items,
    required this.serverUrl,
    this.maxItems = 10,
    this.autoPlayInterval = const Duration(seconds: 6),
    this.showBorder = false,
    this.borderColor = Colors.white,
    this.borderWidth = 1.5,
    this.hoverBorderWidth = 2.5,
    this.heightFactor = 0.38,
    this.minHeight = 280,
    this.maxHeight = 440,
    this.dotAlignment = SliderDotAlignment.right,
    this.dotsOutside = false,
    this.logoWidthFactor = kDefaultLogoWidthFactor,
    this.logoMaxHeight = kDefaultLogoMaxHeight,
    this.showArrows = false,
    this.showIncludedBadge = false,
    this.showJellyfinLogo = false,
    this.hoverReveal = false,
    this.showActions = false,
    this.transition = SliderTransition.slide,
    this.arrowsOnHover = false,
    this.showTitle = true,
    this.showAgeRating = false,
    this.contentScale = 1.0,
    this.showTrailer = false,
    this.showNewBadge = false,
    this.inlineMeta = false,
    this.horizontalPadding = 0,
    this.showShadow = false,
    this.hoverScale = 1.02,
    this.showVignette = true,
    this.vignetteMode = SliderVignetteMode.around,
    this.vignetteOpacity = 1.0,
    this.vignetteSize = 160,
  });

  /// Tamaño por defecto del logo (fracción del ancho del banner).
  static const double kDefaultLogoWidthFactor = 0.32;

  /// Altura máxima por defecto del logo (px, antes de la escala).
  static const double kDefaultLogoMaxHeight = 110.0;

  final String title;
  final List<BaseItemDto> items;
  final String? serverUrl;

  /// Máximo número de banners mostrados.
  final int maxItems;

  /// Intervalo de avance automático. `null` desactiva el auto-play.
  final Duration? autoPlayInterval;

  /// Muestra un borde alrededor de cada banner.
  final bool showBorder;
  final Color borderColor;
  final double borderWidth;
  final double hoverBorderWidth;

  /// Factor de altura relativo al ancho disponible.
  final double heightFactor;
  final double minHeight;
  final double maxHeight;

  /// Dónde colocar los puntos de navegación.
  final SliderDotAlignment dotAlignment;

  /// Si `true`, los puntos se muestran centrados debajo del slider,
  /// fuera del banner.
  final bool dotsOutside;

  /// Anchura máxima del logo del título relativa al ancho del banner.
  final double logoWidthFactor;

  /// Altura máxima del logo del título (px, antes de la escala).
  final double logoMaxHeight;

  /// Muestra flechas a los lados para ir al anterior/siguiente banner
  /// (con ciclo: del primero vuelve al último y viceversa).
  final bool showArrows;

  /// Muestra la insignia "Se incluye con Jellyfin" bajo el logo.
  final bool showIncludedBadge;

  /// Muestra el logo de Jellyfin en pequeño sobre el logo del título.
  final bool showJellyfinLogo;

  /// En escritorio, al pasar el ratón el logo se desliza hacia arriba y se
  /// revela la descripción del elemento.
  final bool hoverReveal;

  /// Muestra los botones de acción (Ver ahora, +, i) bajo el logo.
  final bool showActions;

  /// Tipo de transición entre banners (deslizamiento o desvanecimiento).
  final SliderTransition transition;

  /// Muestra las flechas solo al pasar el ratón sobre el slider.
  final bool arrowsOnHover;

  /// Muestra el título sobre el slider.
  final bool showTitle;

  /// Muestra la edad recomendada del contenido en un recuadro de color,
  /// ocultando el año y el tipo de contenido.
  final bool showAgeRating;

  /// Escala del conjunto (logo, botones, insignia y descripción) del banner.
  final double contentScale;

  /// Muestra el botón de trailer, solo para películas o series.
  final bool showTrailer;

  /// Muestra la pastilla "Nueva película"/"Nueva serie" sobre el logo
  /// cuando el contenido es reciente (estilo Disney+).
  final bool showNewBadge;

  /// Meta inferior en línea estilo Disney+: insignia de edad oscura
  /// + año • géneros, sin nota de estrellas). Se muestra justo bajo el logo.
  final bool inlineMeta;

  /// Padding horizontal (izquierda + derecha) del slider. Deja hueco entre
  /// el borde de la pantalla y el banner. 0 = a ancho completo.
  final double horizontalPadding;

  /// Si `true`, muestra sombra elevada alrededor de cada banner.
  final bool showShadow;

  /// Escala al hacer hover sobre el banner (1.0 = sin escala, 1.02 = efecto previo).
  final double hoverScale;

  /// Si `true`, muestra viñeta en bordes del banner (Prime). `false` la quita (Disney).
  final bool showVignette;

  /// Lados donde se dibuja la viñeta (left/right/top/bottom/around).
  final SliderVignetteMode vignetteMode;

  /// Opacidad global de la viñeta (0..1, multiplica las alfas base).
  final double vignetteOpacity;

  /// Grosor en px de la viñeta en los modos por lado. `around` usa su
  /// composición fija de degradados.
  final double vignetteSize;

  @override
  ConsumerState<FeaturedSlider> createState() => _FeaturedSliderState();
}

class _FeaturedSliderState extends ConsumerState<FeaturedSlider> {
  late final PageController _controller;
  Timer? _timer;
  int _currentPage = 0;
  bool _sliderHovered = false;
  bool _sliderFocused = false;

  /// El borde solo se muestra cuando el slider tiene hover o foco,
  /// pero nunca cuando el foco/h over está en los puntos (dots).
  /// Así en Disney el hover/click sobre dots no remarca el borde.
  bool get _borderActive {
    if (!widget.showBorder) return false;
    if (_sliderHovered) return true;
    if (!_sliderFocused) return false;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && _dotNodes.contains(primary)) return false;
    return true;
  }

  void _onFocusManagerChanged() {
    if (mounted) setState(() {});
  }

  /// Pausado por un trailer reproduciéndose.
  bool _trailerPaused = false;

  /// Pausado por la descripción revelada al hacer hover sobre el logo.
  bool _hoverPaused = false;

  /// El auto-play está pausado si lo está por cualquiera de los motivos.
  bool get _autoPlayPaused => _trailerPaused || _hoverPaused;

  List<BaseItemDto> get _banners => widget.items.take(widget.maxItems).toList();

  bool get _useFade => widget.transition == SliderTransition.fade;

  /// FocusNodes para navegación TV: acciones (Ver ahora, Trailer, Fav, Info) y dots.
  /// Se crean aquí para poder controlar el flujo isla → acciones → dots → continuar viendo.
  late List<FocusNode> _actionNodes;
  late List<FocusNode> _dotNodes;

  void _initTvNodes() {
    // El primer nodo es global para que la isla pueda hacer ↓ determinista a Ver ahora
    _actionNodes = [
      tvSliderFirstActionFocusNode,
      FocusNode(debugLabel: 'slider_action_1'),
      FocusNode(debugLabel: 'slider_action_2'),
      FocusNode(debugLabel: 'slider_action_3'),
    ];
    _dotNodes = List.generate(
      _banners.length,
      (i) => FocusNode(debugLabel: 'slider_dot_$i'),
    );
  }

  void _updateDotNodesIfNeeded() {
    if (_dotNodes.length == _banners.length) return;
    for (final n in _dotNodes) {
      n.dispose();
    }
    _dotNodes = List.generate(
      _banners.length,
      (i) => FocusNode(debugLabel: 'slider_dot_$i'),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _initTvNodes();
    FocusManager.instance.addListener(_onFocusManagerChanged);
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant FeaturedSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateDotNodesIfNeeded();
    if (oldWidget.autoPlayInterval != widget.autoPlayInterval) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusManagerChanged);
    _timer?.cancel();
    _controller.dispose();
    for (final n in _actionNodes) {
      if (identical(n, tvSliderFirstActionFocusNode)) continue;
      n.dispose();
    }
    for (final n in _dotNodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// Pausa el auto-play mientras un trailer se está reproduciendo.
  void _setTrailerPaused(bool paused) {
    if (_trailerPaused == paused) return;
    _trailerPaused = paused;
    _syncAutoPlay();
  }

  /// Pausa el auto-play mientras la descripción se muestra al hacer hover
  /// sobre el logo del banner.
  void _setHoverPaused(bool paused) {
    if (_hoverPaused == paused) return;
    _hoverPaused = paused;
    _syncAutoPlay();
  }

  /// Sincroniza el auto-play con el estado de pausa: si está pausado se
  /// cancela el timer y se detiene cualquier animación de página en curso;
  /// si no, se reanuda el avance automático.
  void _syncAutoPlay() {
    if (_autoPlayPaused) {
      _timer?.cancel();
      // Si el timer ya disparó y hay una animación de página en curso, se
      // cancela volviendo a la página actual para que el banner no cambie.
      if (!_useFade && _controller.hasClients) {
        _controller.jumpToPage(_currentPage);
      }
    } else {
      _startAutoPlay();
    }
    if (mounted) setState(() {});
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (_autoPlayPaused) return;
    final interval = widget.autoPlayInterval;
    if (interval == null || _banners.length < 2) return;
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _banners.length;
      if (_useFade) {
        setState(() => _currentPage = next);
      } else {
        if (!_controller.hasClients) return;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _goToPage(int index) {
    if (index == _currentPage) return;
    if (_useFade) {
      setState(() => _currentPage = index);
    } else {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
    // Unificado: si el foco estaba en Trailer y el nuevo banner no tiene trailer, mover a Ver ahora (todas las plataformas con teclado)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final primary = FocusManager.instance.primaryFocus;
      if (primary == null) return;
      if (_banners.isEmpty || index < 0 || index >= _banners.length) return;
      final targetItem = _banners[index];
      final hasTrailer =
          widget.showTrailer &&
          (targetItem.type == BaseItemKind.movie ||
              targetItem.type == BaseItemKind.series);
      // El nodo 1 es Trailer cuando existe; si el nuevo banner no tiene trailer
      // y el foco quedó en ese nodo huérfano, llevarlo a Ver ahora
      if (!hasTrailer && identical(primary, _actionNodes[1])) {
        _actionNodes.first.requestFocus();
      }
    });
  }

  /// Va al banner anterior (del primero salta al último).
  void _goToPrev() {
    if (_banners.length < 2) return;
    final target = (_currentPage - 1 + _banners.length) % _banners.length;
    _goToPage(target);
  }

  /// Va al banner siguiente (del último salta al primero).
  void _goToNext() {
    if (_banners.length < 2) return;
    final target = (_currentPage + 1) % _banners.length;
    _goToPage(target);
  }

  // ignore: unused_element
  bool _isFocusInsideScope(FocusNode scope, FocusNode? focused) {
    if (focused == null) return false;
    FocusNode? cur = focused;
    while (cur != null) {
      if (identical(cur, scope)) return true;
      cur = cur.parent;
    }
    return false;
  }

  bool get _arrowsVisible =>
      widget.showArrows &&
      _banners.length > 1 &&
      (!widget.arrowsOnHover || _sliderHovered);

  /// Flecha lateral con fade: visible al hacer hover sobre el slider.
  Widget _buildArrow({
    required IconData icon,
    required VoidCallback onTap,
    required Alignment align,
    required EdgeInsets padding,
  }) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_arrowsVisible,
        child: AnimatedOpacity(
          opacity: _arrowsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Align(
            alignment: align,
            child: Padding(
              padding: padding,
              child: _SliderArrow(icon: icon, onTap: onTap),
            ),
          ),
        ),
      ),
    );
  }

  /// Fila de puntos (sin posicionar): usada dentro y fuera del slider.
  Widget _buildDotsRow() {
    Widget dotAt(int i) {
      final dot = _SliderDot(
        active: i == _currentPage,
        onTap: () => _goToPage(i),
      );
      // Dots focuseables para teclado en todas las plataformas (tv, desktop, tablet, mobile)
      // Al enfocar un dot con teclado/mando también cambia de banner.
      // El hover de ratón solo escala el punto (no cambia de banner):
      // el cambio con ratón es solo con click.
      final node = (i < _dotNodes.length) ? _dotNodes[i] : null;
      return ScaleButton(
        focusNode: node,
        selectedScale: 1.35,
        borderRadius: BorderRadius.circular(4),
        notifyHoverAsFocus: false,
        onPressed: () => _goToPage(i),
        onFocusChange: (focused) {
          if (focused) {
            // Cambiar banner al navegar por dots con izquierda/derecha.
            _goToPage(i);
          }
        },
        child: dot,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (var i = 0; i < _banners.length; i++) dotAt(i)],
    );
  }

  /// Puntos dentro del banner (overlay). Si [dotsOutside] es `true` no se
  /// muestra nada aquí: los puntos van debajo del slider.
  Widget _buildDots() {
    if (widget.dotsOutside) return const SizedBox.shrink();
    final dots = _buildDotsRow();

    switch (widget.dotAlignment) {
      case SliderDotAlignment.left:
        return Positioned(left: 40, bottom: 14, child: dots);
      case SliderDotAlignment.center:
        return Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [dots],
          ),
        );
      case SliderDotAlignment.right:
        return Positioned(right: 40, bottom: 14, child: dots);
    }
  }

  /// Puntos fuera del slider, centrados debajo del banner.
  Widget _buildDotsOutside() {
    if (!widget.dotsOutside) return const SizedBox.shrink();
    final dots = _buildDotsRow();
    final MainAxisAlignment alignment = switch (widget.dotAlignment) {
      SliderDotAlignment.left => MainAxisAlignment.start,
      SliderDotAlignment.center => MainAxisAlignment.center,
      SliderDotAlignment.right => MainAxisAlignment.end,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(mainAxisAlignment: alignment, children: [dots]),
    );
  }

  Widget _bannerCard(BaseItemDto item) => _SliderBannerCard(
    item: item,
    serverUrl: widget.serverUrl,
    showBorder: widget.showBorder,
    isBorderHovered: _borderActive,
    borderColor: widget.borderColor,
    borderWidth: widget.borderWidth,
    hoverBorderWidth: widget.hoverBorderWidth,
    showNewBadge: widget.showNewBadge,
    inlineMeta: widget.inlineMeta,
    logoWidthFactor: widget.logoWidthFactor,
    logoMaxHeight: widget.logoMaxHeight,
    showIncludedBadge: widget.showIncludedBadge,
    showJellyfinLogo: widget.showJellyfinLogo,
    hoverReveal: widget.hoverReveal,
    showActions: widget.showActions,
    showAgeRating: widget.showAgeRating,
    contentScale: widget.contentScale,
    showTrailer: widget.showTrailer,
    showShadow: widget.showShadow,
    hoverScale: widget.hoverScale,
    showVignette: widget.showVignette,
    vignetteMode: widget.vignetteMode,
    vignetteOpacity: widget.vignetteOpacity,
    vignetteSize: widget.vignetteSize,
    onTrailerPlaybackChanged: _setTrailerPaused,
    onHoverChanged: _setHoverPaused,
    actionFocusNodes: _actionNodes,
  );

  /// Capa de banners: PageView (deslizamiento) o AnimatedSwitcher (fade).
  Widget _buildBannerLayer() {
    if (_useFade) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentPage),
          child: _bannerCard(_banners[_currentPage]),
        ),
      );
    }
    return PageView.builder(
      clipBehavior: Clip.none,
      controller: _controller,
      itemCount: _banners.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        _startAutoPlay();
      },
      itemBuilder: (context, i) => _bannerCard(_banners[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();
    final hp = widget.horizontalPadding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hp > 0 ? hp : 24),
            child: ScrollTitle(title: widget.title),
          ),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hp),
          child: LayoutBuilder(
          builder: (context, constraints) {
            final mode =
                ref.watch(platformModeProvider).value ?? PlatformMode.mobile;
            final isTv = mode == PlatformMode.tv;
            // En TV la altura original (0.38 / 280-440) ocupa demasiado vertical
            // en 720p y con isla flotante. Se reduce ~25% para dejar ver filas.
            final heightFactor = isTv
                ? widget.heightFactor * 0.72
                : widget.heightFactor;
            final minH = isTv ? 260.0 : widget.minHeight;
            final maxH = isTv ? 420.0 : widget.maxHeight;
            final height = (constraints.maxWidth * heightFactor).clamp(
              minH,
              maxH,
            );
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  _timer?.cancel();
                } else if (notification is ScrollEndNotification) {
                  _startAutoPlay();
                }
                return false;
              },
              child: FocusScope(
                onFocusChange: (hasFocus) {
                  if (_sliderFocused != hasFocus) {
                    setState(() => _sliderFocused = hasFocus);
                  }
                },
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  // Comportamiento de teclado unificado para todas las plataformas
                  // (tv, desktop, tablet, mobile) con teclado/mando conectado

                  final primary = FocusManager.instance.primaryFocus;
                  final isAction =
                      primary != null && _actionNodes.contains(primary);
                  final isDot = primary != null && _dotNodes.contains(primary);
                  // Índice del dot actual (para foco inicial al bajar desde acciones)
                  final currentDotNode =
                      _dotNodes.isNotEmpty && _currentPage < _dotNodes.length
                      ? _dotNodes[_currentPage]
                      : (_dotNodes.isNotEmpty ? _dotNodes.first : null);
                  final firstActionNode = _actionNodes.isNotEmpty
                      ? _actionNodes.first
                      : null;

                  // ── ARRIBA: isla/top bar ──────────────────────────────
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    if (isDot) {
                      if (firstActionNode != null) {
                        if (firstActionNode.context != null) {
                          firstActionNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                      }
                    }
                    // Desde acciones o cualquier parte del slider, ↑ → isla
                    // + scroll total arriba para que el slider se vea como al entrar
                    tvInicioFocusNode.requestFocus();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final ctx = node.context;
                      if (ctx == null) return;
                      // Buscar el Scrollable ancestro (ListView de HomeScreen)
                      final scrollable = Scrollable.maybeOf(ctx);
                      if (scrollable != null &&
                          scrollable.position.pixels !=
                              scrollable.position.minScrollExtent) {
                        scrollable.position.animateTo(
                          scrollable.position.minScrollExtent,
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        );
                      } else {
                        // Fallback: ensureVisible del slider al tope
                        try {
                          Scrollable.ensureVisible(
                            ctx,
                            alignment: 0.0,
                            alignmentPolicy:
                                ScrollPositionAlignmentPolicy.explicit,
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                          );
                        } catch (_) {}
                      }
                    });
                    return KeyEventResult.handled;
                  }

                  // ── ABAJO ─────────────────────────────────────────────
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    if (isAction) {
                      // Desde Ver ahora/trailer/fav/info → ↓ a dots
                      if (currentDotNode != null) {
                        currentDotNode.requestFocus();
                        return KeyEventResult.handled;
                      }
                    }
                    if (isDot) {
                      // Desde dots → ↓ a Continuar viendo (siguiente fila).
                      // El slider está aislado en su FocusScope, por lo que
                      // node.focusInDirection(down) nunca encuentra la fila
                      // exterior. Hay que subir al scope padre (HomeShell)
                      // que contiene slider + filas.
                      bool movedDownFromParent() {
                        FocusNode? scope = node.parent;
                        while (scope != null) {
                          if (scope is FocusScopeNode) {
                            if (scope.focusInDirection(
                              TraversalDirection.down,
                            )) {
                              return true;
                            }
                          }
                          scope = scope.parent;
                        }
                        return false;
                      }

                      if (movedDownFromParent()) {
                        return KeyEventResult.handled;
                      }
                      final root = FocusManager.instance.rootScope;
                      if (root.focusInDirection(TraversalDirection.down)) {
                        return KeyEventResult.handled;
                      }
                      // Último fallback: next en el scope padre (siguiente fila)
                      final parent = node.parent;
                      if (parent is FocusScopeNode) {
                        parent.nextFocus();
                        return KeyEventResult.handled;
                      }
                      root.nextFocus();
                      return KeyEventResult.handled;
                    }
                    // Fallback: si no está en acción ni dot, intentar bajar dentro
                    // del slider (acción → dot) y si no, salir a la siguiente fila
                    if (isAction || isDot) {
                      return KeyEventResult.handled;
                    }
                    final movedInside = node.focusInDirection(
                      TraversalDirection.down,
                    );
                    if (movedInside) return KeyEventResult.handled;
                    // Intentar desde el padre antes de root
                    FocusNode? scope = node.parent;
                    while (scope != null) {
                      if (scope is FocusScopeNode) {
                        if (scope.focusInDirection(TraversalDirection.down)) {
                          return KeyEventResult.handled;
                        }
                      }
                      scope = scope.parent;
                    }
                    final root = FocusManager.instance.rootScope;
                    final moved = root.focusInDirection(
                      TraversalDirection.down,
                    );
                    if (moved) return KeyEventResult.handled;
                    root.nextFocus();
                    return KeyEventResult.handled;
                  }

                  // ── IZQUIERDA / DERECHA ───────────────────────────────
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                      event.logicalKey == LogicalKeyboardKey.arrowRight) {
                    final dir = event.logicalKey == LogicalKeyboardKey.arrowLeft
                        ? TraversalDirection.left
                        : TraversalDirection.right;

                    if (isAction) {
                      // Intentar mover entre Ver ahora ↔ trailer ↔ fav ↔ info
                      final moved = node.focusInDirection(dir);
                      if (moved) return KeyEventResult.handled;
                      // En el borde derecho (Info) → → va a dots (no cambia banner)
                      if (dir == TraversalDirection.right &&
                          currentDotNode != null) {
                        currentDotNode.requestFocus();
                        return KeyEventResult.handled;
                      }
                      // En el borde izquierdo (Ver ahora) → ← se queda (no wrap)
                      return KeyEventResult.handled;
                    }

                    if (isDot) {
                      final moved = node.focusInDirection(dir);
                      if (moved) return KeyEventResult.handled;
                      // En bordes de dots no se cambia de banner automáticamente;
                      // el cambio ocurre al enfocar otro dot (onFocusChange).
                      return KeyEventResult.handled;
                    }

                    // Foco en otro elemento del slider (o sin foco claro):
                    // mantener navegación horizontal contenida
                    final moved = node.focusInDirection(dir);
                    if (moved) return KeyEventResult.handled;
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MouseRegion(
                        onEnter: (_) => setState(() => _sliderHovered = true),
                        onExit: (_) => setState(() => _sliderHovered = false),
                        child: SizedBox(
                          height: height,
                          child: Stack(
                            clipBehavior: Clip.none,
                            fit: StackFit.expand,
                            children: [
                              _buildBannerLayer(),
                              _buildDots(),
                              if (widget.showArrows && _banners.length > 1) ...[
                                _buildArrow(
                                  icon: Icons.chevron_left,
                                  onTap: _goToPrev,
                                  align: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 10),
                                ),
                                _buildArrow(
                                  icon: Icons.chevron_right,
                                  onTap: _goToNext,
                                  align: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 10),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      _buildDotsOutside(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Tarjeta de banner horizontal de una película/serie.
class _SliderBannerCard extends ConsumerStatefulWidget {
  const _SliderBannerCard({
    required this.item,
    required this.serverUrl,
    required this.showBorder,
    required this.borderColor,
    required this.borderWidth,
    required this.logoWidthFactor,
    required this.logoMaxHeight,
    required this.showIncludedBadge,
    required this.showJellyfinLogo,
    required this.hoverReveal,
    required this.showActions,
    required this.showAgeRating,
    required this.contentScale,
    required this.showTrailer,
    required this.showNewBadge,
    required this.inlineMeta,
    this.showShadow = false,
    this.hoverScale = 1.02,
    this.showVignette = true,
    this.vignetteMode = SliderVignetteMode.around,
    this.vignetteOpacity = 1.0,
    this.vignetteSize = 160,
    this.hoverBorderWidth = 2.5,
    this.isBorderHovered = false,
    this.onTrailerPlaybackChanged,
    this.onHoverChanged,
    this.actionFocusNodes,
  });

  final BaseItemDto item;
  final String? serverUrl;
  final bool showBorder;
  final Color borderColor;
  final double borderWidth;
  final double logoWidthFactor;
  final double logoMaxHeight;
  final bool showIncludedBadge;
  final bool showJellyfinLogo;
  final bool hoverReveal;
  final bool showActions;
  final bool showAgeRating;
  final double contentScale;
  final bool showTrailer;
  final bool showNewBadge;
  final bool inlineMeta;
  final bool showShadow;
  final double hoverScale;
  final bool showVignette;
  final SliderVignetteMode vignetteMode;
  final double vignetteOpacity;
  final double vignetteSize;
  final double hoverBorderWidth;
  final bool isBorderHovered;

  /// Notifica al slider si un trailer está reproduciéndose (para pausar el
  /// avance automático mientras tanto).
  final ValueChanged<bool>? onTrailerPlaybackChanged;

  /// Notifica al slider si la descripción está visible por el hover sobre el
  /// logo (pausa el avance automático mientras se muestra).
  final ValueChanged<bool>? onHoverChanged;

  /// FocusNodes de TV para los botones de acción (inyectados desde el slider
  /// padre para poder orquestar el flujo isla → acciones → dots).
  final List<FocusNode>? actionFocusNodes;

  @override
  ConsumerState<_SliderBannerCard> createState() => _SliderBannerCardState();
}

class _SliderBannerCardState extends ConsumerState<_SliderBannerCard> {
  bool _hovered = false;
  bool _trailerLoading = false;
  bool _trailerBuffering = false;
  Player? _trailerPlayer;
  VideoController? _trailerVideoController;
  StreamSubscription<dynamic>? _trailerCompletionSub;
  StreamSubscription<dynamic>? _trailerBufferingSub;
  StreamSubscription<dynamic>? _trailerCropSub;

  /// Id del item cuyo trailer se está resolviendo/reproduciendo. Permite
  /// descartar una carga en curso si el banner cambia o se cierra el trailer.
  String? _trailerItemId;

  /// Evita abrir un trailer mientras el reproductor anterior se está cerrando.
  bool _closingTrailer = false;

  /// Ratio de aspecto objetivo para recortar los bordes negros (letterbox)
  /// incrustados en los trailers. La mayoría son 2.39:1 dentro de un
  /// contenedor 16:9, por lo que se recorta verticalmente hasta este ratio.
  static const double _trailerCropAspect = 2.39;

  /// Rango de aspecto (w/h) en el que el trailer se considera letterboxed
  /// (16:9 con barras). Si el video ya es tan ancho o más, no se recorta.
  static const double _trailerCropMinAspect = 1.5;
  static const double _trailerCropMaxAspect = 2.1;

  void _setHovered(bool value) {
    if (_hovered != value) {
      setState(() => _hovered = value);
    }
    // Notifica al slider si la descripción está visible (hover + hoverReveal +
    // overview) para pausar o reanudar el avance automático.
    widget.onHoverChanged?.call(_reveal && value);
  }

  @override
  void didUpdateWidget(covariant _SliderBannerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _closeTrailer();
      // Al cambiar de banner se suelta el hover para no dejar el auto-play
      // pausado por la descripción de un banner que ya no se muestra.
      _setHovered(false);
    }
  }

  @override
  void dispose() {
    _trailerCompletionSub?.cancel();
    _trailerBufferingSub?.cancel();
    _trailerCropSub?.cancel();
    _trailerPlayer?.dispose();
    widget.onTrailerPlaybackChanged?.call(false);
    super.dispose();
  }

  /// Reproduce el trailer en el panel derecho del banner con media_kit
  /// (libmpv, fiable en Windows). Al pulsar el botón se pausa de inmediato el
  /// avance automático del slider, para que no cambie de banner mientras se
  /// resuelve y reproduce el trailer.
  Future<void> _openTrailer() async {
    if (_trailerPlayer != null || _trailerLoading || _closingTrailer) return;
    final itemId = widget.item.id;
    setState(() {
      _trailerLoading = true;
      _trailerItemId = itemId;
    });
    // Pausa el auto-play en cuanto se pulsa el botón, no cuando el stream ya
    // está listo. Así el slider no puede cambiar de elemento durante la carga.
    widget.onTrailerPlaybackChanged?.call(true);
    final streamUrl = await ref.read(trailerStreamProvider(widget.item).future);
    // El banner cambió o el trailer se cerró mientras se resolvía el stream:
    // se descarta la carga (el cierre ya reanudó el auto-play).
    if (!mounted || itemId != _trailerItemId) return;
    if (streamUrl == null) {
      setState(() => _trailerLoading = false);
      // Sin trailer disponible: se reanuda el avance automático.
      widget.onTrailerPlaybackChanged?.call(false);
      return;
    }
    final player = Player();
    // El VideoController se crea antes de open() para que la textura del
    // vídeo se asocie correctamente. `auto-copy` evita desfase A/V con la
    // decodificación directa por hardware en algunos GPUs.
    final videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto-copy'),
    );
    // Muestra el loader mientras el reproductor bufferiza (antes del primer
    // frame) además de durante la apertura del stream.
    _trailerBufferingSub = player.stream.buffering.listen((isBuffering) {
      if (mounted) setState(() => _trailerBuffering = isBuffering);
    });
    // Recorta los bordes negros (letterbox) incrustados en el trailer en
    // cuanto se conocen las dimensiones reales del video.
    _trailerCropSub = player.stream.videoParams.listen((params) async {
      final width = params.dw;
      final height = params.dh;
      if (width == null || height == null) return;
      await _applyTrailerCrop(player, width, height);
      await _trailerCropSub?.cancel();
      _trailerCropSub = null;
    });
    try {
      await player.open(
        Media(
          streamUrl,
          httpHeaders: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
          },
        ),
      );
    } catch (_) {
      await _trailerBufferingSub?.cancel();
      _trailerBufferingSub = null;
      await player.dispose();
      if (mounted) setState(() => _trailerLoading = false);
      return;
    }
    // El trailer se cerró o el banner cambió mientras se abría el stream:
    // se descarta el reproductor recién creado.
    if (!mounted || itemId != _trailerItemId) {
      await _trailerBufferingSub?.cancel();
      _trailerBufferingSub = null;
      await player.dispose();
      return;
    }
    setState(() {
      _trailerLoading = false;
      _trailerPlayer = player;
      _trailerVideoController = videoController;
    });
    widget.onTrailerPlaybackChanged?.call(true);
    // Detecta el final de forma fiable (position >= duration) para reanudar
    // el auto-play; el stream "completed" puede dispararse de forma espuria.
    _trailerCompletionSub = player.stream.position.listen((pos) {
      final duration = player.state.duration;
      if (duration > Duration.zero && pos >= duration) {
        _closeTrailer();
      }
    });
    await player.play();
  }

  /// Abre el reproductor a pantalla completa con el contenido del banner.
  Future<void> _openPlayer() async {
    final itemId = widget.item.id;
    if (itemId == null || itemId.isEmpty) return;
    // Se cierra el trailer por completo (liberando el stream nativo) antes de
    // abrir el reproductor, para no dejar dos sesiones de media_kit activas.
    await _closeTrailer();
    if (!mounted) return;
    context.push('/player/$itemId', extra: widget.item);
  }

  /// Abre la pantalla de detalles (misma que al pulsar una tarjeta de película).
  Future<void> _openDetails() async {
    final id = widget.item.id;
    if (id == null || id.isEmpty) return;
    await _closeTrailer();
    if (!mounted) return;
    context.push('/home/details/$id', extra: widget.item);
  }

  /// Recorta verticalmente el trailer hasta [_trailerCropAspect] para
  /// eliminar las barras negras de letterbox, mediante la propiedad
  /// `video-crop` de libmpv (expuesta por media_kit). El frame recortado se
  /// escala luego al llenar el contenedor con `BoxFit.cover`.
  Future<void> _applyTrailerCrop(Player player, int width, int height) async {
    final aspect = width / height;
    if (aspect < _trailerCropMinAspect || aspect > _trailerCropMaxAspect) {
      return;
    }
    final cropHeight = (width / _trailerCropAspect).round();
    if (cropHeight >= height) return;
    final cropY = (height - cropHeight) ~/ 2;
    final native = player.platform;
    if (native is NativePlayer) {
      try {
        await native.setProperty('video-crop', '${width}x$cropHeight+0+$cropY');
      } catch (_) {}
    }
  }

  Future<void> _closeTrailer() async {
    if (_closingTrailer) return;
    _closingTrailer = true;
    final player = _trailerPlayer;
    _trailerCompletionSub?.cancel();
    _trailerCompletionSub = null;
    _trailerBufferingSub?.cancel();
    _trailerBufferingSub = null;
    _trailerCropSub?.cancel();
    _trailerCropSub = null;
    _trailerPlayer = null;
    _trailerVideoController = null;
    _trailerLoading = false;
    _trailerBuffering = false;
    _trailerItemId = null;
    widget.onTrailerPlaybackChanged?.call(false);
    if (mounted) setState(() {});
    if (player != null) {
      try {
        // Se espera el dispose para que libmpv libere de verdad el stream
        // antes de volver a crear otro reproductor (o de un hot reload).
        await player.dispose();
      } catch (_) {
        // El dispose nativo puede fallar si el engine se está cerrando.
      }
    }
    _closingTrailer = false;
  }

  String? get _logoUrl {
    final server = widget.serverUrl;
    return server != null ? itemLogoUrl(server, widget.item) : null;
  }

  bool get _hasOverview => (widget.item.overview ?? '').isNotEmpty;
  bool get _reveal => widget.hoverReveal && _hasOverview;

  /// Edad recomendada del contenido (ej. "PG-13", "R", "+18"), si tiene.
  String? get _ageRating {
    final rating = (widget.item.officialRating ?? '').trim();
    return rating.isNotEmpty ? rating : null;
  }

  /// Contenido reciente: añadido hace poco, con estreno cercano o del
  /// año en curso/siguiente. Solo entonces se muestra la pastilla "Nueva".
  bool get _isNew {
    final now = DateTime.now();
    final created = widget.item.dateCreated;
    if (created != null && now.difference(created).inDays <= 90) {
      return true;
    }
    final premiere = widget.item.premiereDate;
    if (premiere != null &&
        premiere.isBefore(now.add(const Duration(days: 30))) &&
        now.difference(premiere).inDays <= 365) {
      return true;
    }
    final year = widget.item.productionYear;
    if (year != null && (year == now.year || year == now.year + 1)) {
      return true;
    }
    return false;
  }

  /// Hay datos para la meta en línea (edad, año o géneros).
  bool get _hasInlineMeta =>
      _ageRating != null ||
      widget.item.productionYear != null ||
      (widget.item.genres ?? const <String>[]).isNotEmpty;

  /// Fila de meta en línea estilo Disney+ (insignia de edad oscura +
  /// año • géneros, sin nota de estrellas). Se muestra justo bajo el logo.
  Widget _buildInlineMeta() {
    final year = widget.item.productionYear;
    final genres = widget.item.genres ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_ageRating != null) ...[
            _DisneyAgeBadge(rating: _ageRating!),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              [
                if (year != null) '$year',
                if (genres.isNotEmpty) genres.take(3).join(', '),
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Etiqueta de la pastilla "Nueva película"/"Nueva serie" según el tipo.
  /// `null` si el tipo no es película ni serie (no se muestra pastilla).
  String? _newBadgeLabel(AppLocalizations l10n) {
    switch (widget.item.type) {
      case BaseItemKind.movie:
        return l10n.newMovie;
      case BaseItemKind.series:
      case BaseItemKind.season:
      case BaseItemKind.episode:
        return l10n.newSeries;
      default:
        return null;
    }
  }

  Widget _titleText({double? fontSize}) {
    final skin = ref.read(skinControllerProvider).value;
    return Text(
      widget.item.name ?? '',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: skin?.textPrimary ?? Colors.white,
        fontSize: (fontSize ?? 32) * widget.contentScale,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(blurRadius: 8, color: Colors.black54, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  /// Multiplica la alfa base de un color por la opacidad de la viñeta (0..1).
  Color _vignetteAlpha(Color base) {
    final o = widget.vignetteOpacity.clamp(0.0, 1.0);
    return base.withValues(alpha: (base.a * o).clamp(0.0, 1.0));
  }

  /// Capas de viñeta según [SliderVignetteMode]. Vacío si `showVignette` es false.
  List<Widget> _buildVignette() {
    if (!widget.showVignette) return const [];
    switch (widget.vignetteMode) {
      case SliderVignetteMode.left:
        return [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: widget.vignetteSize,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _vignetteAlpha(const Color(0xE6000000)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ];
      case SliderVignetteMode.right:
        return [
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: widget.vignetteSize,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      _vignetteAlpha(const Color(0xE6000000)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ];
      case SliderVignetteMode.top:
        return [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: widget.vignetteSize,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _vignetteAlpha(const Color(0xE6000000)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ];
      case SliderVignetteMode.bottom:
        return [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: widget.vignetteSize,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      _vignetteAlpha(const Color(0xE6000000)),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ];
      case SliderVignetteMode.around:
        // Composición previa: radial + lineal superior + laterales.
        return [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.35,
                colors: [
                  Colors.transparent,
                  _vignetteAlpha(const Color(0x1A000000)),
                  _vignetteAlpha(const Color(0x66000000)),
                  _vignetteAlpha(const Color(0xB3000000)),
                ],
                stops: const [0.55, 0.75, 0.92, 1.0],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  _vignetteAlpha(const Color(0xE6000000)),
                  _vignetteAlpha(const Color(0x66000000)),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.28, 0.55],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.center,
                colors: [
                  _vignetteAlpha(const Color(0x66000000)),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.center,
                colors: [
                  _vignetteAlpha(const Color(0x14000000)),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.12],
              ),
            ),
          ),
        ];
    }
  }

  Widget _buildLogoSlide(BoxConstraints constraints) {
    final s = widget.contentScale;
    final logoUrl = _logoUrl;
    return AnimatedSlide(
      offset: _reveal && _hovered ? const Offset(0, -0.12) : Offset.zero,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: logoUrl != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showJellyfinLogo) ...[
                  Image.asset(
                    'assets/images/jellyfin-logo.png',
                    height: 20 * s,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 6 * s),
                ],
                SizedBox(
                  width: constraints.maxWidth * widget.logoWidthFactor,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: widget.logoMaxHeight * s,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.network(
                        logoUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : _titleText(fontSize: 20),
                        errorBuilder: (_, _, _) => _titleText(fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _titleText(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = ref.watch(skinControllerProvider).value;
    final bannerRadius =
        skin?.bannerBorderRadius ?? (skin?.cardBorderRadius ?? 10) + 2;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final item = widget.item;
    final serverUrl = widget.serverUrl;
    final backdrop = serverUrl != null
        ? itemBackdropUrl(serverUrl, item)
        : null;
    final poster = serverUrl != null ? itemImageUrl(serverUrl, item) : null;
    final hasBackdrop =
        backdrop != null && (item.backdropImageTags?.isNotEmpty ?? false);

    final year = item.productionYear;
    final genres = item.genres ?? const <String>[];
    final rating = item.communityRating;
    final isTv =
        (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) ==
        PlatformMode.tv;
    // En TV se quitó la descripción (causaba overflow 167px) y se puede
    // aumentar la altura del slider. Escala menor en TV para que la columna
    // (logo+botones+badge) quepa en 316px sin overflow de 6px.
    final s = widget.contentScale * (isTv ? 0.82 : 1.5);
    final backdropAlignment = (skin?.topBarFloating ?? false)
        ? const Alignment(0, -0.75)
        : const Alignment(0, -0.75);
    // El botón de trailer solo se muestra para películas o series.
    final showTrailer =
        widget.showTrailer &&
        (item.type == BaseItemKind.movie || item.type == BaseItemKind.series);
    final showYear = !widget.showAgeRating && year != null;
    final showGenres = !widget.showAgeRating && genres.isNotEmpty;
    // Pastilla "Nueva película"/"Nueva serie" (estilo Disney+).
    final newBadgeLabel = widget.showNewBadge && _isNew
        ? _newBadgeLabel(AppLocalizations.of(context)!)
        : null;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(bannerRadius),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            if (hasBackdrop)
              Image.network(
                backdrop,
                fit: BoxFit.cover,
                // Baja ligeramente el encuadre para que no se entrecorte por
                // arriba (más visible en Prime con isla flotante sobre el
                // banner). -0.3 = ~30% hacia arriba dentro del BoxFit.cover.
                alignment: backdropAlignment,
                errorBuilder: (_, _, _) => _SliderFallback(
                  posterUrl: poster,
                  color: fallbackColor,
                  alignment: backdropAlignment,
                ),
              )
            else
              _SliderFallback(
                posterUrl: poster,
                color: fallbackColor,
                alignment: backdropAlignment,
              ),
            // Degradado para legibilidad del texto.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.55, 1.0],
                  colors: [
                    Colors.transparent,
                    Color(0x33000000),
                    Color(0xE6000000),
                  ],
                ),
              ),
            ),
            // Viñeta oscurecida para que la barra superior (Prime) se lea bien
            // sobre el banner. `around` = composición completa (radial +
            // degradados, aspecto previo); los modos por lado dibujan una
            // franja de [vignetteSize] px en ese borde. Todo escalado por
            // [vignetteOpacity]. Solo si showVignette.
            ..._buildVignette(),
            // Capa táctil / foco solo en móvil/desktop. En TV el foco debe
            // estar en los botones de acción (WatchNow etc.) para que ←/→
            // navegue entre ellos y ↑ vuelva a Inicio.
            // Sin efecto de escala al hacer hover/focus (eliminado por petición).
            if (!isTv)
              Positioned.fill(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
                      final id = item.id;
                      if (id != null && id.isNotEmpty) {
                        context.push('/home/details/$id', extra: item);
                      }
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        final id = item.id;
                        if (id != null && id.isNotEmpty) {
                          context.push('/home/details/$id', extra: item);
                        }
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            // Columna izquierda: logo/título, botones de acción, insignia y
            // descripción (solo al pasar el ratón). Al hacer hover se desliza
            // hacia arriba únicamente el logo/título (con el logo de Jellyfin).
            Positioned(
              left: isTv ? 60 : 70,
              top: isTv ? 80 : 134,
              bottom: isTv ? 24 : (widget.hoverReveal ? 80 : 130),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pastilla "Nueva película"/"Nueva serie" sobre el logo
                      // (estilo Disney+), solo si el contenido es reciente.
                      if (newBadgeLabel != null) ...[
                        _NewBadge(label: newBadgeLabel),
                        SizedBox(height: 10 * s),
                      ],
                      // El hover solo se detecta sobre el logo/título: el
                      // MouseRegion envuelve al AnimatedSlide (fuera) para que su
                      // área no se mueva al deslizarse y no parpadee.
                      if (widget.hoverReveal)
                        MouseRegion(
                          onEnter: (_) => _setHovered(true),
                          onExit: (_) => _setHovered(false),
                          child: _buildLogoSlide(constraints),
                        )
                      else
                        _buildLogoSlide(constraints),
                      // Descripción revelada al pasar el ratón (desktop). En TV
                      // se oculta: era la que desbordaba 167px con altura
                      // reducida y no aporta en mando a distancia.
                      if (!isTv)
                        Flexible(
                          fit: FlexFit.loose,
                          child: AnimatedSlide(
                            offset: _reveal && _hovered
                                ? Offset.zero
                                : const Offset(0, 0.15),
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic,
                            child: AnimatedOpacity(
                              opacity: _reveal && _hovered ? 1 : 0,
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOut,
                              child: _reveal && _hovered
                                  ? Padding(
                                      padding: EdgeInsets.only(top: 1 * s),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: constraints.maxWidth * 0.4,
                                        ),
                                        child: Text(
                                          item.overview!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color:
                                                skin?.textSecondary ??
                                                Colors.white70,
                                            fontSize: 13 * s,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      if (widget.showActions) ...[
                        SizedBox(height: 12 * s),
                        _ActionButtons(
                          scale: s,
                          showTrailer: showTrailer,
                          onTrailer: _openTrailer,
                          onWatch: _openPlayer,
                          onDetails: _openDetails,
                          watchLabel: AppLocalizations.of(context)!.watchNow,
                          favoritesTooltip: AppLocalizations.of(
                            context,
                          )!.addToFavorites,
                          detailsTooltip: AppLocalizations.of(context)!.details,
                          trailerTooltip: AppLocalizations.of(
                            context,
                          )!.watchTrailer,
                          tvFocusNodes: widget.actionFocusNodes,
                        ),
                      ],
                      if (widget.showIncludedBadge) ...[
                        SizedBox(height: 10 * s),
                        IncludedBadge(
                          scale: s / 1.1,
                          label: AppLocalizations.of(
                            context,
                          )!.includedWithJellyfin,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Fila inferior. Disney (inlineMeta) la sube para acercarla
            // al logo; Prime y el resto la mantienen abajo del todo.
            Positioned(
              left: isTv ? 60 : 68,
              right: isTv ? 16 : 28,
              bottom: widget.inlineMeta ? (isTv ? 40 : 130) : (isTv ? 8 : 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Meta en línea estilo Disney+: insignia de edad oscura +
                  // año • géneros, sin nota de estrellas.
                  if (widget.inlineMeta && _hasInlineMeta)
                    _buildInlineMeta()
                  else if (!widget.inlineMeta &&
                      (rating != null || showYear || showGenres))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (rating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFF5C518),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (showYear)
                            Text(
                              '$year',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (showGenres) ...[
                            const SizedBox(width: 12),
                            Text(
                              genres.take(3).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (!isTv &&
                      !widget.hoverReveal &&
                      !widget.inlineMeta &&
                      (item.overview ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        item.overview!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: (skin?.textSecondary ?? Colors.white70),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Edad recomendada del contenido, abajo a la derecha.
            // En modo inline (Disney+) la edad ya va en la meta inferior.
            if (widget.showAgeRating &&
                !widget.inlineMeta &&
                _ageRating != null)
              Positioned(
                right: isTv ? 30 : 28,
                bottom: isTv ? 8 : 34,
                child: AgeRatingBadge(rating: _ageRating!),
              ),
            // Reproductor del trailer en el lado derecho (estilo Prime).
            if (_trailerLoading || _trailerPlayer != null)
              Positioned(
                right: 34,
                top: isTv ? 80 : 12,
                bottom: isTv ? 40 : 64,
                width: (constraints.maxWidth * 1).clamp(420.0, 880.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(bannerRadius),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child:
                              _trailerVideoController != null &&
                                  !_trailerBuffering
                              ? _TrailerVideoPlayer(
                                  controller: _trailerVideoController!,
                                )
                              : const Center(child: AppLoader()),
                        ),
                        // Degradado oscuro en el borde izquierdo que funde
                        // con el fondo del banner (estilo Amazon Prime).
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 160,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    fallbackColor,
                                    fallbackColor.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _CloseTrailerButton(onTap: _closeTrailer),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    // Borde como overlay para no afectar el layout del banner al hacer hover.
    // Antes el borde estaba en el BoxDecoration del contenedor del card y al
    // pasar de borderWidth -> hoverBorderWidth el contenido se encogía
    // ligeramente (efecto "escala" percibido). Ahora el borde se dibuja por
    // encima con Positioned.fill y no modifica el tamaño de la imagen.
    final borderOverlay = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(bannerRadius),
        border: Border.all(
          color: widget.showBorder ? widget.borderColor : Colors.transparent,
          width: widget.showBorder
              ? (widget.isBorderHovered ? widget.hoverBorderWidth : widget.borderWidth)
              : 0,
        ),
      ),
    );

    Widget cardContent = Stack(
      children: [
        card,
        Positioned.fill(child: IgnorePointer(child: borderOverlay)),
      ],
    );

    if (widget.showShadow) {
      // Sombra exterior sin recorte.
      cardContent = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(bannerRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(bannerRadius),
          child: cardContent,
        ),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
        child: cardContent,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(bannerRadius),
      child: cardContent,
    );
  }
}

/// Botones de acción del banner: "Ver ahora", trailer, añadir (+) e info (i).
class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({
    required this.watchLabel,
    required this.favoritesTooltip,
    required this.detailsTooltip,
    required this.trailerTooltip,
    this.showTrailer = false,
    this.onTrailer,
    this.onWatch,
    this.onDetails,
    this.scale = 1.0,
    this.tvFocusNodes,
  });

  final String watchLabel;
  final String favoritesTooltip;
  final String detailsTooltip;
  final String trailerTooltip;
  final bool showTrailer;

  /// Acción al pulsar el botón de trailer.
  final VoidCallback? onTrailer;

  /// Acción al pulsar "Ver ahora" (abre el reproductor a pantalla completa).
  final VoidCallback? onWatch;

  /// Acción al pulsar info (i) → pantalla de detalles (misma que tarjeta película).
  final VoidCallback? onDetails;
  final double scale;

  /// FocusNodes inyectados desde el slider para orquestar flujo TV.
  /// Orden: 0=Ver ahora, 1=Trailer (si existe), 2=Fav, 3=Info
  final List<FocusNode>? tvFocusNodes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = scale;
    // Botones navegables con flechas en todas las plataformas (TV, desktop, tablet, mobile)
    // para que el teclado/mando funcione igual en cualquier modo.

    Widget wrapWithFocus(Widget child, VoidCallback onTap, FocusNode? node) {
      return ScaleButton(
        focusNode: node,
        onPressed: onTap,
        selectedScale: 1.06,
        borderRadius: BorderRadius.circular(8),
        child: child,
      );
    }

    // Mapeo de nodos: si no hay trailer, se compactan los índices para que
    // Fav e Info queden contiguos (0,1,2) y ←/→ funcione sin hueco.
    FocusNode? nodeAt(int visualIndex) {
      if (tvFocusNodes == null) {
        return null;
      }
      // visualIndex es el orden visual 0..n-1, se mapea directo a nodos 0..n-1
      if (visualIndex < tvFocusNodes!.length) {
        return tvFocusNodes![visualIndex];
      }
      return null;
    }

    double order = 0;
    final children = <Widget>[];
    children.add(
      FocusTraversalOrder(
        order: NumericFocusOrder(order++),
        child: wrapWithFocus(
          WatchNowButton(label: watchLabel, onTap: onWatch ?? () {}, scale: s),
          onWatch ?? () {},
          nodeAt(0),
        ),
      ),
    );
    children.add(SizedBox(width: 12 * s));
    if (showTrailer) {
      children.add(
        FocusTraversalOrder(
          order: NumericFocusOrder(order++),
          child: wrapWithFocus(
            RoundIconButton(
              icon: Icons.play_circle_outline,
              tooltip: trailerTooltip,
              scale: s,
              onTap: onTrailer ?? () {},
            ),
            onTrailer ?? () {},
            nodeAt(1),
          ),
        ),
      );
      children.add(SizedBox(width: 8 * s));
    }
    final favOrder = order++;
    final infoOrder = order++;
    // Fav usa el siguiente nodo visual
    final favNodeIndex = showTrailer ? 2 : 1;
    final infoNodeIndex = showTrailer ? 3 : 2;
    children.add(
      FocusTraversalOrder(
        order: NumericFocusOrder(favOrder),
        child: wrapWithFocus(
          RoundIconButton(
            icon: Icons.add,
            tooltip: favoritesTooltip,
            scale: s,
            onTap: () {},
          ),
          () {},
          nodeAt(favNodeIndex),
        ),
      ),
    );
    children.add(SizedBox(width: 8 * s));
    children.add(
      FocusTraversalOrder(
        order: NumericFocusOrder(infoOrder),
        child: wrapWithFocus(
          RoundIconButton(
            icon: Icons.info_outline,
            tooltip: detailsTooltip,
            scale: s,
            onTap: onDetails ?? () {},
          ),
          onDetails ?? () {},
          nodeAt(infoNodeIndex),
        ),
      ),
    );

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// Reproductor nativo del trailer mediante video_player (sin webview).
/// Reproductor nativo del trailer mediante media_kit (libmpv), sin webview.
class _TrailerVideoPlayer extends StatelessWidget {
  const _TrailerVideoPlayer({required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: controller,
      controls: NoVideoControls,
      fit: BoxFit.cover,
      fill: const Color(0xFF000000),
    );
  }
}

/// Botón para cerrar el reproductor del trailer.
class _CloseTrailerButton extends StatelessWidget {
  const _CloseTrailerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Botón de flecha para navegar entre banners.
class _SliderArrow extends StatelessWidget {
  const _SliderArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

/// Pastilla blanca "Nueva película"/"Nueva serie" sobre el logo
/// (estilo Disney+).
class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Insignia de edad oscura para la meta en línea (estilo Disney+).
class _DisneyAgeBadge extends StatelessWidget {
  const _DisneyAgeBadge({required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A42),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rating,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Punto del slider de navegación.
class _SliderDot extends ConsumerWidget {
  const _SliderDot({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent =
        ref.watch(skinControllerProvider).value?.accent ??
        const Color(0xFF2B7FFF);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: active ? 22 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active ? accent : Colors.white38,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Fallback cuando no hay imagen de fondo disponible: muestra el póster (o un
/// color) sin la inicial del nombre.
class _SliderFallback extends StatelessWidget {
  const _SliderFallback({
    required this.color,
    this.posterUrl,
    this.alignment = const Alignment(0, -0.2),
  });

  final String? posterUrl;
  final Color color;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (posterUrl != null)
          Image.network(
            posterUrl!,
            fit: BoxFit.cover,
            alignment: alignment,
            errorBuilder: (_, _, _) => ColoredBox(color: color),
          )
        else
          ColoredBox(color: color),
        const ColoredBox(color: Color(0x66000000)),
      ],
    );
  }
}
