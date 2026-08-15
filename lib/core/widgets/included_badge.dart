import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/skin/skin_controller.dart';

/// Insignia "Se incluye con Jellyfin": check en círculo + texto. Es el mismo
/// elemento que usa el slider de novedades y se reutiliza donde haga falta
/// (p. ej. en la hovercard de las tarjetas al hacer hover).
class IncludedBadge extends ConsumerWidget {
  const IncludedBadge({
    super.key,
    required this.label,
    this.scale = 1.0,
    this.fontSize,
  });

  final String label;
  final double scale;

  /// Tamaño de la fuente del texto. Si es `null` se usa el tamaño por defecto
  /// (13 * [scale]), lo que permite ajustarlo en otros sitios.
  final double? fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent =
        ref.watch(skinControllerProvider).value?.accent ??
        const Color(0xFF00A8E1);
    final s = scale;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18 * s,
          height: 18 * s,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          child: Icon(Icons.check, color: Colors.white, size: 12 * s),
        ),
        SizedBox(width: 6 * s),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize ?? 13 * s,
            fontWeight: FontWeight.w500,
            shadows: const [
              Shadow(
                blurRadius: 4,
                color: Colors.black54,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
