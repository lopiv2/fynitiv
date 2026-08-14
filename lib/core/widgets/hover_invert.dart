import 'package:material_ui/material_ui.dart';

/// Widget genérico que detecta cuando el puntero está encima (y opcionalmente
/// el foco) y lo expone a un builder para aplicar estilos, p. ej. invertir
/// los colores del contenido (fondo blanco / contenido oscuro).
class HoverInvert extends StatefulWidget {
  const HoverInvert({
    super.key,
    required this.builder,
    this.cursor = SystemMouseCursors.click,
    this.trackFocus = false,
  });

  /// Construye el contenido. [active] es `true` cuando el puntero está encima
  /// (o, si [trackFocus] está activo, cuando tiene el foco).
  final Widget Function(BuildContext context, bool active) builder;
  final MouseCursor cursor;

  /// También marca como activo cuando el widget recibe el foco (TV/teclado).
  final bool trackFocus;

  @override
  State<HoverInvert> createState() => _HoverInvertState();
}

class _HoverInvertState extends State<HoverInvert> {
  bool _active = false;

  void _set(bool value) {
    if (_active != value) setState(() => _active = value);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: widget.builder(context, _active),
    );
    if (widget.trackFocus) {
      child = Focus(onFocusChange: (focused) => _set(focused), child: child);
    }
    return child;
  }
}
