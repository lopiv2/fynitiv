import 'package:material_ui/material_ui.dart';

import 'hover_invert.dart';

/// Botón circular gris con un icono. Al pasar el ratón se invierten los
/// colores (fondo blanco e icono oscuro) y se muestra un [Tooltip]. Es el
/// mismo botón que usa el slider de novedades para trailer/favoritos/info y
/// se reutiliza donde haga falta.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.scale = 1.0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Tooltip(
      message: tooltip,
      verticalOffset: 24 * s,
      child: HoverInvert(
        builder: (context, hovered) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: 34 * s,
            height: 34 * s,
            decoration: BoxDecoration(
              color: hovered ? Colors.white : Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: hovered ? Colors.grey.shade800 : Colors.white,
              size: 20 * s,
            ),
          ),
        ),
      ),
    );
  }
}
