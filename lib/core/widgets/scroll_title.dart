import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../skin/skin_controller.dart';

/// Título de un scroll/fila de contenido: el texto con el color de texto
/// primario del skin ([Skin.textPrimary]) y en negrita. Se usa en todos los
/// títulos de las filas del dashboard.
class ScrollTitle extends ConsumerWidget {
  const ScrollTitle({super.key, required this.title, this.fontSize = 28});

  final String title;
  final double fontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary =
        ref.watch(skinControllerProvider).value?.textPrimary ?? Colors.white;
    return Text(
      title,
      style: TextStyle(
        color: textPrimary,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
