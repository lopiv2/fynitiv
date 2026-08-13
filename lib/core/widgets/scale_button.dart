import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Botón con efecto de aumento al recibir foco o hover.
///
/// Pensado para Android TV y escritorio: envuelve [child] y lo escala (1.0 →
/// [selectedScale]) cuando está seleccionado/focusado, permitiendo activarlo
/// con ratón, toque o teclado (Enter/OK).
class ScaleButton extends StatefulWidget {
  const ScaleButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.selected = false,
    this.selectedScale = 1.15,
    this.duration = const Duration(milliseconds: 180),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.onFocusChange,
  });

  final Widget child;

  /// Acción al activar (click, toque o Enter/OK).
  final VoidCallback onPressed;

  /// Fuerza el estado seleccionado (p. ej. idioma activo).
  final bool selected;

  final double selectedScale;
  final Duration duration;
  final BorderRadius borderRadius;

  /// Notifica cambios de foco/hover (selección visual de los hijos).
  final ValueChanged<bool>? onFocusChange;

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> {
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _active => widget.selected || _focused;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
      widget.onPressed();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    void notify(bool focused) {
      setState(() => _focused = focused);
      widget.onFocusChange?.call(focused);
    }

    return Focus(
      focusNode: _focusNode,
      onFocusChange: notify,
      onKeyEvent: _onKeyEvent,
      child: AnimatedScale(
        scale: _active ? widget.selectedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => notify(true),
          onExit: (_) => notify(false),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: widget.borderRadius,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
