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
    this.autofocus = false,
    this.focusNode,
    this.notifyHoverAsFocus = true,
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

  /// Si es `false`, el hover de ratón solo produce el efecto visual
  /// (escala) sin notificar [onFocusChange]: el contenido solo cambia con
  /// foco real de teclado/mando o con click. Por defecto `true` para no
  /// cambiar el comportamiento existente.
  final bool notifyHoverAsFocus;

  final bool autofocus;

  /// FocusNode externo (para TV: permite al slider hacer ↑ → Inicio).
  final FocusNode? focusNode;

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton> {
  bool _focused = false;
  bool _hovered = false;
  final FocusNode _internalNode = FocusNode();

  FocusNode get _focusNode => widget.focusNode ?? _internalNode;

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ScaleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autofocus && !oldWidget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _internalNode.dispose();
    super.dispose();
  }

  bool get _active => widget.selected || _focused || _hovered;

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
    void notifyFocus(bool focused) {
      setState(() => _focused = focused);
      widget.onFocusChange?.call(focused);
    }

    void notifyHover(bool hovered) {
      setState(() => _hovered = hovered);
      if (widget.notifyHoverAsFocus) {
        widget.onFocusChange?.call(hovered);
      }
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: notifyFocus,
      onKeyEvent: _onKeyEvent,
      child: AnimatedScale(
        scale: _active ? widget.selectedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => notifyHover(true),
          onExit: (_) => notifyHover(false),
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
