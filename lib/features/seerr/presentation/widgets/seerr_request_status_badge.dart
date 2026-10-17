import 'package:material_ui/material_ui.dart';

/// Pastilla de estado de una petición de Seerr, pensada para
/// `PosterCard.cornerBadge` (no interactiva, legible sobre cualquier portada).
class SeerrRequestStatusBadge extends StatelessWidget {
  const SeerrRequestStatusBadge({
    super.key,
    required this.label,
    this.status = 0,
    this.inLibrary = false,
  });

  final String label;

  /// Estado de la petición: 1 = pendiente, 2 = aprobada, 3 = rechazada.
  final int status;

  /// El título ya está disponible en la biblioteca: verde con tick, por encima
  /// del estado de la petición.
  final bool inLibrary;

  static const Color _green = Color(0xFF1B7F3B);
  static const Color _red = Color(0xFFC0392B);
  static const Color _orange = Color(0xFFB26A00);

  @override
  Widget build(BuildContext context) {
    final color = inLibrary
        ? _green
        : switch (status) {
            2 => _green,
            3 => _red,
            _ => _orange,
          };
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (inLibrary) ...[
              const Icon(Icons.check, color: Colors.white, size: 12),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
