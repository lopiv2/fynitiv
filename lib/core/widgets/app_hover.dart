import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../audio/hover_sound_player.dart';
import '../constants/button_sounds.dart';
import '../navigation/platform_mode.dart';
import '../settings/button_sound_controller.dart';

/// Efecto de hover universal.
enum AppHoverEffect {
  none,
  scale,
  highlight,
  highlightWithScale,
  outline,
  outlineWithScale,
  highlightWithOutline,
  scaleHighlightOutline,
  led,
  scaleHighlightOutlineLed,
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
    this.ledColor = Colors.transparent,
    this.ledHoveredColor = const Color(0xFF2B7FFF),
    this.ledBlurRadius = 18,
    this.ledSpreadRadius = 1.5,
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
  final Color ledColor;
  final Color ledHoveredColor;
  final double ledBlurRadius;
  final double ledSpreadRadius;

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

  /// Combina escala + highlight + outline (triple efecto).
  factory AppHoverConfig.scaleHighlightOutline({
    double scale = 1.04,
    BorderRadius? radius,
    Color highlightNormal = Colors.transparent,
    Color highlightHovered = const Color(0x1FFFFFFF),
    Color outlineColor = Colors.transparent,
    Color outlineHoveredColor = Colors.white,
    double outlineWidth = 0,
    double outlineHoveredWidth = 2,
    Duration duration = const Duration(milliseconds: 180),
  }) {
    return AppHoverConfig(
      scale: scale,
      borderRadius: radius ?? const BorderRadius.all(Radius.circular(16)),
      highlightNormal: highlightNormal,
      highlightHovered: highlightHovered,
      outlineColor: outlineColor,
      outlineHoveredColor: outlineHoveredColor,
      outlineWidth: outlineWidth,
      outlineHoveredWidth: outlineHoveredWidth,
      duration: duration,
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

  /// Full combo: escala + highlight + outline + LED glow (neón).
  /// `ledColor` se resuelve por plataforma (ej. PSX azul, Nintendo rojo, Xbox verde).
  factory AppHoverConfig.scaleHighlightOutlineLed({
    double scale = 1.04,
    BorderRadius? radius,
    Color highlightNormal = Colors.transparent,
    Color highlightHovered = const Color(0x1FFFFFFF),
    Color outlineColor = Colors.transparent,
    Color outlineHoveredColor = const Color(0xFF2B7FFF),
    Color ledColor = Colors.transparent,
    Color ledHoveredColor = const Color(0xFF2B7FFF),
    double ledBlurRadius = 18,
    double ledSpreadRadius = 1.5,
    double outlineWidth = 0,
    double outlineHoveredWidth = 1.5,
    Duration duration = const Duration(milliseconds: 180),
  }) {
    return AppHoverConfig(
      scale: scale,
      borderRadius: radius ?? const BorderRadius.all(Radius.circular(16)),
      highlightNormal: highlightNormal,
      highlightHovered: highlightHovered,
      outlineColor: outlineColor,
      outlineHoveredColor: outlineHoveredColor,
      outlineWidth: outlineWidth,
      outlineHoveredWidth: outlineHoveredWidth,
      duration: duration,
      ledColor: ledColor,
      ledHoveredColor: ledHoveredColor,
      ledBlurRadius: ledBlurRadius,
      ledSpreadRadius: ledSpreadRadius,
    );
  }

  /// Solo LED glow (sin escala/highlight) para chips ligeros.
  factory AppHoverConfig.led({
    BorderRadius? radius,
    Color ledColor = Colors.transparent,
    Color ledHoveredColor = const Color(0xFF2B7FFF),
    double ledBlurRadius = 16,
    double ledSpreadRadius = 1.2,
    Duration duration = const Duration(milliseconds: 180),
  }) {
    return AppHoverConfig(
      borderRadius: radius ?? const BorderRadius.all(Radius.circular(12)),
      highlightNormal: Colors.transparent,
      highlightHovered: Colors.transparent,
      ledColor: ledColor,
      ledHoveredColor: ledHoveredColor,
      ledBlurRadius: ledBlurRadius,
      ledSpreadRadius: ledSpreadRadius,
      duration: duration,
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
/// - `scaleHighlightOutline` combina escala + highlight + outline
/// - `led` glow neón exterior
/// - `scaleHighlightOutlineLed` full combo: escala + highlight + outline + LED por plataforma
/// - `none` sin efecto
/// El estado hover se expone vía [AppHoverScope] para que el hijo coloque el play donde quiera.
class AppHover extends ConsumerStatefulWidget {
  const AppHover({
    super.key,
    required this.child,
    required this.onTap,
    this.effect = AppHoverEffect.highlight,
    this.config = const AppHoverConfig(),
    this.trackFocus = true,
    this.cursor = SystemMouseCursors.click,
    this.playSoundOnHover = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final AppHoverEffect effect;
  final AppHoverConfig config;
  final bool trackFocus;
  final MouseCursor cursor;
  final bool playSoundOnHover;

  @override
  ConsumerState<AppHover> createState() => _AppHoverState();
}

class _AppHoverState extends ConsumerState<AppHover> {
  bool _hovered = false;
  bool _focused = false;
  final FocusNode _focusNode = FocusNode();
  bool _suppressInitialSound = true;
  static DateTime? _globalMuteUntil;

  @override
  void initState() {
    super.initState();
    // Supresión global para el primer foco automático al aparecer una
    // pantalla (ej. selección de perfiles al iniciar la app). El loader
    // async de users hace que los AppHover se creen con retardo y el
    // autofocus llegue fuera de la ventana corta de 350ms, por eso se
    // usa una ventana global de ~1s compartida entre todas las tarjetas.
    final now = DateTime.now();
    if (_globalMuteUntil == null || now.isAfter(_globalMuteUntil!)) {
      _globalMuteUntil = now.add(const Duration(milliseconds: 800));
    }
    final remaining = _globalMuteUntil!.difference(now);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final delay = remaining.isNegative ? const Duration(milliseconds: 350) : remaining + const Duration(milliseconds: 200);
      Future.delayed(delay, () {
        if (mounted) {
          // No hace falta setState visual, solo habilitar sonido
          _suppressInitialSound = false;
          if (mounted) setState(() {});
        }
      });
    });
  }

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
        widget.effect == AppHoverEffect.highlightWithOutline ||
        widget.effect == AppHoverEffect.scaleHighlightOutline ||
        widget.effect == AppHoverEffect.scaleHighlightOutlineLed;
    final isScale = widget.effect == AppHoverEffect.scale ||
        widget.effect == AppHoverEffect.highlightWithScale ||
        widget.effect == AppHoverEffect.outlineWithScale ||
        widget.effect == AppHoverEffect.scaleHighlightOutline ||
        widget.effect == AppHoverEffect.scaleHighlightOutlineLed;
    final isOutline = widget.effect == AppHoverEffect.outline ||
        widget.effect == AppHoverEffect.outlineWithScale ||
        widget.effect == AppHoverEffect.highlightWithOutline ||
        widget.effect == AppHoverEffect.scaleHighlightOutline ||
        widget.effect == AppHoverEffect.scaleHighlightOutlineLed;
    final isLed = widget.effect == AppHoverEffect.led ||
        widget.effect == AppHoverEffect.scaleHighlightOutlineLed;
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

    // LED glow solo por detrás como sombra difusa (neón por plataforma).
    // Más glow por abajo que por arriba: offset Y positivo y blur mayor hacia abajo.
    // Se coloca fuera del Clip para no recortar el desenfoque y se anima el BoxShadow.
    // Orden: base (highlight+outline) -> LED glow (sombra) -> escala (todo escala junto).
    Widget withLed = content;
    if (isLed) {
      final ledShadows = _active
          ? [
              // Halo principal pegado al borde, ligeramente desplazado abajo
              BoxShadow(
                color: widget.config.ledHoveredColor.withValues(alpha: 0.58),
                blurRadius: widget.config.ledBlurRadius,
                spreadRadius: widget.config.ledSpreadRadius,
                offset: const Offset(0, 12),
              ),
              // Glow difuso extendido por abajo, más suave y ancho
              BoxShadow(
                color: widget.config.ledHoveredColor.withValues(alpha: 0.20),
                blurRadius: widget.config.ledBlurRadius * 2.1,
                spreadRadius: widget.config.ledSpreadRadius + 5,
                offset: const Offset(0, 18),
              ),
            ]
          : null;
      withLed = AnimatedContainer(
        duration: widget.config.duration,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: widget.config.isCircular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.config.isCircular ? null : widget.config.borderRadius,
          boxShadow: ledShadows,
        ),
        child: withLed,
      );
    }

    if (isScale) {
      content = AnimatedScale(
        scale: _active ? widget.config.scale : 1.0,
        duration: widget.config.duration,
        curve: Curves.easeOut,
        child: withLed,
      );
    } else {
      content = withLed;
    }

    void playHoverSound() {
      if (!widget.playSoundOnHover) return;
      if (_suppressInitialSound) return;
      if (_globalMuteUntil != null && DateTime.now().isBefore(_globalMuteUntil!)) return;
      final key = ref.read(buttonSoundKeyProvider);
      final asset = assetForButtonSoundKey(key);
      if (asset.isEmpty) return;
      HoverSoundPlayer.instance.play(asset);
    }

    void setHovered(bool v) {
      final wasActive = _active;
      setState(() => _hovered = v);
      if (v && !wasActive) playHoverSound();
    }

    void setFocused(bool v) {
      final wasActive = _active;
      setState(() => _focused = v);
      if (v && !wasActive) {
        playHoverSound();
        // En TV, al enfocar con D-pad la tarjeta puede estar fuera del viewport
        // horizontal/vertical. Asegurar visibilidad para que nunca se pierda el foco visual.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !v) return;
          final mode = ref.read(platformModeProvider).value ?? PlatformMode.mobile;
          if (mode == PlatformMode.tv) {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: 0.5,
            );
          }
        });
      }
    }

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
