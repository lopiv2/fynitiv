import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/horizontal_scroll_behavior.dart';

/// Scroll horizontal para las barras superiores con pistas visuales.
///
/// - Envuelve la fila de items en un `SingleChildScrollView` horizontal
///   (como ya hacían las tres variantes a mano).
/// - Añade fades laterales (`ShaderMask`) solo cuando el contenido
///   desborda: izquierda si se puede volver, derecha si queda más.
/// - Auto-centra el item activo al montar y cuando cambia de activo
///   (salto sin animación al montar, animado después). No reacciona a
///   rebuilds por otros motivos (p. ej. opacidad de la barra al scrollear).
/// - No toca el foco: transparente para D-pad/teclado y traversal.
class TopBarScroller extends StatefulWidget {
  const TopBarScroller({
    super.key,
    required this.children,
    required this.isActive,
  });

  final List<Widget> children;

  /// Dice si un hijo directo es el item activo (se centra en la vista).
  final bool Function(Widget child) isActive;

  @override
  State<TopBarScroller> createState() => _TopBarScrollerState();
}

class _TopBarScrollerState extends State<TopBarScroller> {
  final _controller = ScrollController();
  bool _showStartFade = false;
  bool _showEndFade = false;
  bool _canScroll = false;
  int _lastActive = -2;
  bool _firstLayout = true;
  BuildContext? _activeCtx;
  int _activeIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterLayout());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TopBarScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterLayout());
  }

  void _syncFades() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    final showStart = pos.pixels > 1;
    final showEnd = pos.pixels < pos.maxScrollExtent - 1;
    final canScroll = pos.maxScrollExtent > 1;
    if (showStart != _showStartFade ||
        showEnd != _showEndFade ||
        canScroll != _canScroll) {
      setState(() {
        _showStartFade = showStart;
        _showEndFade = showEnd;
        _canScroll = canScroll;
      });
    }
  }

  void _afterLayout() {
    if (!mounted) return;
    _syncFades();
    final ctx = _activeCtx;
    final idx = _activeIndex;
    if (ctx == null || !ctx.mounted || idx == _lastActive) return;
    _lastActive = idx;
    final first = _firstLayout;
    _firstLayout = false;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: first ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    _activeCtx = null;
    var found = -1;
    final wrapped = <Widget>[
      for (var i = 0; i < widget.children.length; i++)
        if (widget.isActive(widget.children[i]))
          Builder(
            builder: (ctx) {
              if (found < 0) {
                found = i;
                _activeCtx = ctx;
              }
              return widget.children[i];
            },
          )
        else
          widget.children[i],
    ];
    _activeIndex = found;

    // `HorizontalScrollBehavior`: el `ScrollBehavior` de Flutter no acepta
    // arrastre con ratón, así que en escritorio (o probando el móvil en el
    // simulador) la barra parecería no tener scroll. Mismo patrón que las
    // filas de contenido (`content_row.dart`).
    final scroll = ScrollConfiguration(
      behavior: const HorizontalScrollBehavior(),
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(mainAxisSize: MainAxisSize.min, children: wrapped),
      ),
    );
    if (!_canScroll) return scroll;
    const fade = 0.07;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          _showStartFade ? Colors.transparent : Colors.black,
          Colors.black,
          Colors.black,
          _showEndFade ? Colors.transparent : Colors.black,
        ],
        stops: const [0.0, fade, 1.0 - fade, 1.0],
      ).createShader(rect),
      child: scroll,
    );
  }
}
