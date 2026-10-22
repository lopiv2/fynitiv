import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_hover.dart';

/// Botón de icono para las topbars (p. ej. la lupa de Buscar).
/// Widget genérico reutilizable: icono que se ilumina en hover/foco TV
/// mediante el [AppHover] universal.
class TopBarIconButton extends StatelessWidget {
  const TopBarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Colors.white70,
    this.hoverColor = Colors.white,
    this.size = 22,
    this.autofocus = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final Color hoverColor;
  final double size;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AppHover(
        effect: AppHoverEffect.none,
        onTap: onTap,
        autofocus: autofocus,
        child: Builder(
          builder: (context) {
            final hovered = AppHoverScope.of(context)?.hovered ?? false;
            return Tooltip(
              message: tooltip,
              child: Icon(
                icon,
                color: hovered ? hoverColor : color,
                size: size,
              ),
            );
          },
        ),
      ),
    );
  }
}
