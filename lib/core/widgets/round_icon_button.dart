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
    // Nodo propio para el ancla del Tooltip: los botones del slider van
    // adyacentes en zona scrolleable y sin nodo propio su config se fusiona
    // con vecinas → el bridge de accesibilidad de Windows rechaza el update
    // en cada hover (`Failed to update ui::AXTree ... will not be in the
    // tree`, bug upstream flutter/flutter#182444). Solo agrupa.
    return Semantics(
      container: true,
      child: Tooltip(
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
      ),
    );
  }
}
