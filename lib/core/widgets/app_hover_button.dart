import 'package:material_ui/material_ui.dart';

import 'app_hover.dart';

/// Variante visual del botón con hover universal.
enum AppHoverButtonVariant { text, filled, outlined }

/// Widget universal para botones de texto con efecto hover/focus.
///
/// Usa [AppHover] internamente para reutilizar la lógica universal de
/// hover + foco TV (MouseRegion + Focus + AnimatedContainer + AnimatedScale).
/// - [effect] por defecto `highlightWithScale` (pedido para TV).
/// - [variant] elige el estilo base (texto, relleno, borde).
/// - Soporta [icon] opcional (a la izquierda del texto) y configuración
///   personalizable por botón vía [config].
class AppHoverButton extends StatelessWidget {
  const AppHoverButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = AppHoverButtonVariant.text,
    this.effect = AppHoverEffect.highlightWithScale,
    this.config,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.textStyle,
    this.iconSize = 18,
  });

  /// Constructor para botón de texto con icono opcional.
  const AppHoverButton.text({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.effect = AppHoverEffect.highlightWithScale,
    this.config,
    this.textColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.textStyle,
    this.iconSize = 18,
  })  : variant = AppHoverButtonVariant.text,
        backgroundColor = null,
        borderColor = null;

  /// Botón relleno.
  const AppHoverButton.filled({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.effect = AppHoverEffect.highlightWithScale,
    this.config,
    this.textColor,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.textStyle,
    this.iconSize = 18,
  })  : variant = AppHoverButtonVariant.filled,
        borderColor = null;

  /// Botón con borde.
  const AppHoverButton.outlined({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.effect = AppHoverEffect.highlightWithScale,
    this.config,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.textStyle,
    this.iconSize = 18,
  }) : variant = AppHoverButtonVariant.outlined;

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppHoverButtonVariant variant;
  final AppHoverEffect effect;
  final AppHoverConfig? config;
  final Color? textColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final double iconSize;

  AppHoverConfig get _defaultConfig {
    // Config por defecto optimizada para TV: highlight sutil + escala.
    switch (variant) {
      case AppHoverButtonVariant.filled:
        return const AppHoverConfig(
          highlightNormal: Colors.transparent,
          highlightHovered: Color(0xFF3A3A3A),
          borderRadius: BorderRadius.all(Radius.circular(8)),
          scale: 1.05,
        );
      case AppHoverButtonVariant.outlined:
        return const AppHoverConfig(
          highlightNormal: Colors.transparent,
          highlightHovered: Color(0x1FFFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(8)),
          scale: 1.05,
        );
      case AppHoverButtonVariant.text:
        return const AppHoverConfig(
          highlightNormal: Colors.transparent,
          highlightHovered: Color(0x1FFFFFFF),
          borderRadius: BorderRadius.all(Radius.circular(8)),
          scale: 1.05,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveConfig = config ?? _defaultConfig;
    final isDisabled = onPressed == null;

    // Colores por defecto según variante.
    final Color defaultTextColor;
    final Color defaultIconColor;
    switch (variant) {
      case AppHoverButtonVariant.filled:
        defaultTextColor = Colors.white;
        defaultIconColor = Colors.white;
        break;
      case AppHoverButtonVariant.outlined:
        defaultTextColor = Colors.white70;
        defaultIconColor = Colors.white70;
        break;
      case AppHoverButtonVariant.text:
        defaultTextColor = Colors.white70;
        defaultIconColor = Colors.white70;
        break;
    }

    final Color resolvedTextColor = textColor ?? defaultTextColor;
    final Color resolvedIconColor = icon != null ? (textColor ?? defaultIconColor) : defaultIconColor;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: resolvedIconColor),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (textStyle ??
                    theme.textTheme.labelLarge?.copyWith(
                      color: resolvedTextColor,
                      fontWeight: FontWeight.w600,
                    ) ??
                    TextStyle(color: resolvedTextColor, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );

    // Envoltura según variante para borde/fondo base.
    if (variant == AppHoverButtonVariant.outlined) {
      content = Container(
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor ?? Colors.white24, width: 1),
          borderRadius: effectiveConfig.borderRadius,
        ),
        child: content,
      );
    } else if (variant == AppHoverButtonVariant.filled) {
      // El fondo del filled se maneja vía AppHover highlight + backgroundColor opcional.
      // Si hay backgroundColor custom, lo pintamos debajo del highlight usando Stack.
      if (backgroundColor != null) {
        content = Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: effectiveConfig.borderRadius,
          ),
          child: content,
        );
      } else {
        content = Padding(padding: padding, child: content);
      }
    } else {
      content = Padding(padding: padding, child: content);
    }

    // Opacidad para disabled.
    if (isDisabled) {
      content = Opacity(opacity: 0.5, child: content);
    }

    return AppHover(
      effect: effect,
      config: effectiveConfig,
      onTap: onPressed ?? () {},
      child: content,
    );
  }
}
