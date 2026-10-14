import 'package:material_ui/material_ui.dart';

/// Badge circular para las tarjetas de las filas estacionales.
///
/// Disco oscuro translúcido con la imagen (webp) de la temática centrada,
/// legible sobre cualquier carátula. No es interactivo ([IgnorePointer]) para
/// no bloquear el hover/tap de la tarjeta.
class SeasonalCardBadge extends StatelessWidget {
  const SeasonalCardBadge({super.key, required this.asset, this.size = 50});

  /// Ruta del asset (ver `seasonalBadgeAsset`).
  final String asset;

  /// Diámetro del disco.
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        /*decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),*/
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.all(size * 0.18),
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
