import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../skin/skin_controller.dart';

/// Título de un scroll/fila de contenido: el texto con el color de texto
/// primario del skin ([Skin.textPrimary]) y en negrita. Si se aporta
/// [onSeeMore], se muestra "Ver más >" a la derecha del título.
class ScrollTitle extends ConsumerWidget {
  const ScrollTitle({
    super.key,
    required this.title,
    this.fontSize = 28,
    this.onSeeMore,
  });

  final String title;
  final double fontSize;

  /// Acción de "Ver más >". Si es null no se muestra el enlace.
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textPrimary =
        ref.watch(skinControllerProvider).value?.textPrimary ?? Colors.white;
    final titleWidget = Text(
      title,
      style: TextStyle(
        color: textPrimary,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      ),
    );
    if (onSeeMore == null) return titleWidget;
    return Row(
      children: [
        Expanded(child: titleWidget),
        GestureDetector(
          onTap: onSeeMore,
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              l10n.seeMore,
              style: TextStyle(
                color: textPrimary,
                fontSize: fontSize * 0.7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
