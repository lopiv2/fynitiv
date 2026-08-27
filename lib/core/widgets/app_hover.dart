import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Efecto de hover universal.
enum AppHoverEffect {
  none,
  scale,
  highlight,
  highlightWithScale,
  outline,
  outlineWithScale,
  highlightWithOutline,
}

class AppHoverConfig {
  const AppHoverConfig({
    this.duration = const Duration(milliseconds: 180),
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.scale = 1.03,
    this.highlightNormal = const Color(0xFF181818),
    this.highlightHovered = const Color(0xFF282828),
    this.outlineColor = Colors.transparent,
    this.outlineHoveredColor = Colors.white,
    this.outlineWidth = 0,
    this.outlineHoveredWidth = 3,
    this.isCircular = false,
  });

  final Duration duration;
  final BorderRadius borderRadius;
  final double scale;
  final Color highlightNormal;
  final Color highlightHovered;
  final Color outlineColor;
  final Color outlineHoveredColor;
  final double outlineWidth;
  final double outlineHoveredWidth;
  final bool isCircular;

  /// Config Spotify: fondo #181818 -> #282828, sin escala, radius 8.
  factory AppHoverConfig.spotify({required Color accent, double radius = 8, Duration? duration}) {
    return AppHoverConfig(
      highlightNormal: const Color(0xFF181818),
      highlightHovered: const Color(0xFF282828),
      borderRadius: BorderRadius.circular(radius),
      scale: 1.0,
      duration: duration ?? const Duration(milliseconds: 180),
    );
  }

  factory AppHoverConfig.scaleOnly({double scale = 1.05, BorderRadius? radius}) {
    return AppHoverConfig(
      scale: scale,
      borderRadius: radius ?? const BorderRadius.all(Radius.circular(12)),
      highlightNormal: Colors.transparent,
      highlightHovered: Colors.transparent,
    );
  }

  /// Config para avatar circular con outline blanco solo en hover/focus.
  factory AppHoverConfig.circularOutline({
    Color outlineColor = Colors.transparent,
    Color outlineHoveredColor = Colors.white,
    double outlineWidth = 0,
    double outlineHoveredWidth = 3,
    double scale = 1.12,
    Duration duration = const Duration(milliseconds: 180),
  }) {
    return AppHoverConfig(
      isCircular: true,
      outlineColor: outlineColor,
      outlineHoveredColor: outlineHoveredColor,
      outlineWidth: outlineWidth,
      outlineHoveredWidth: outlineHoveredWidth,
      scale: scale,
      duration: duration,
      highlightNormal: Colors.transparent,
      highlightHovered: Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
    );
  }
}

class AppHoverScope extends InheritedWidget {
  const AppHoverScope({super.key, required this.hovered, required super.child});
  final bool hovered;
  static AppHoverScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppHoverScope>();
  @override
  bool updateShouldNotify(AppHoverScope oldWidget) => hovered != oldWidget.hovered;
}

/// Widget universal para efectos hover/focus.
/// Personalizable por skin vía [config] y [effect].
/// - `scale` agranda (para TV/preset chips)
/// - `highlight` cambia fondo (Spotify)
/// - `highlightWithScale` combina ambos
/// - `outline` / `outlineWithScale` / `highlightWithOutline` añade borde
/// - `none` sin efecto
/// El estado hover se expone vía [AppHoverScope] para que el hijo coloque el play donde quiera.
class AppHover extends StatefulWidget {
  const AppHover({
    super.key,
    required this.child,
    required this.onTap,
    this.effect = AppHoverEffect.highlight,
    this.config = const AppHoverConfig(),
    this.trackFocus = true,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget child;
  final VoidCallback onTap;
  final AppHoverEffect effect;
  final AppHoverConfig config;
  final bool trackFocus;
  final MouseCursor cursor;

  @override
  State<AppHover> createState() => _AppHoverState();
}

class _AppHoverState extends State<AppHover> {
  bool _hovered = false;
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _active => _hovered || _focused;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isHighlight = widget.effect == AppHoverEffect.highlight ||
        widget.effect == AppHoverEffect.highlightWithScale ||
        widget.effect == AppHoverEffect.highlightWithOutline;
    final isScale = widget.effect == AppHoverEffect.scale ||
        widget.effect == AppHoverEffect.highlightWithScale ||
        widget.effect == AppHoverEffect.outlineWithScale;
    final isOutline = widget.effect == AppHoverEffect.outline ||
        widget.effect == AppHoverEffect.outlineWithScale ||
        widget.effect == AppHoverEffect.highlightWithOutline;
    final highlightColor = _active && isHighlight ? widget.config.highlightHovered : widget.config.highlightNormal;
    final outlineColor = _active && isOutline ? widget.config.outlineHoveredColor : widget.config.outlineColor;
    final outlineWidth = _active && isOutline ? widget.config.outlineHoveredWidth : widget.config.outlineWidth;

    Widget content = AnimatedContainer(
      duration: widget.config.duration,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isHighlight ? highlightColor : Colors.transparent,
        shape: widget.config.isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.config.isCircular ? null : widget.config.borderRadius,
        border: isOutline && outlineWidth > 0
            ? Border.all(color: outlineColor, width: outlineWidth)
            : isOutline
                ? Border.all(color: outlineColor, width: 0)
                : null,
      ),
      child: (widget.config.isCircular
          ? ClipOval(
              child: AppHoverScope(
                hovered: _active,
                child: widget.child,
              ),
            )
          : ClipRRect(
              borderRadius: widget.config.borderRadius,
              child: AppHoverScope(
                hovered: _active,
                child: widget.child,
              ),
            )),
    );

    if (isScale) {
      content = AnimatedScale(
        scale: _active ? widget.config.scale : 1.0,
        duration: widget.config.duration,
        curve: Curves.easeOut,
        child: content,
      );
    }

    void setHovered(bool v) => setState(() => _hovered = v);
    void setFocused(bool v) => setState(() => _focused = v);

    Widget wrapped = MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => setHovered(true),
      onExit: (_) => setHovered(false),
      child: GestureDetector(onTap: widget.onTap, child: content),
    );

    if (widget.trackFocus) {
      wrapped = Focus(
        focusNode: _focusNode,
        onFocusChange: setFocused,
        onKeyEvent: _onKeyEvent,
        child: wrapped,
      );
    }

    return wrapped;
  }
}
