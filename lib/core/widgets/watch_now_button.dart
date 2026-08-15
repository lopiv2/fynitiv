import 'package:material_ui/material_ui.dart';

/// Botón "Ver ahora": blanco con icono de play y texto en negro. Es el mismo
/// botón que usa el slider de novedades y se reutiliza donde haya una acción
/// de reproducción (p. ej. el panel de extensión de las tarjetas al hacer
/// hover).
class WatchNowButton extends StatelessWidget {
  const WatchNowButton({
    super.key,
    required this.label,
    required this.onTap,
    this.scale = 1.0,
  });

  final String label;
  final VoidCallback onTap;

  /// Escala del botón (heredada del contenido donde se muestre).
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34 * s,
        padding: EdgeInsets.symmetric(horizontal: 14 * s),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4 * s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: Colors.black, size: 20 * s),
            SizedBox(width: 4 * s),
            Text(
              label,
              style: TextStyle(
                color: Colors.black,
                fontSize: 13 * s,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
