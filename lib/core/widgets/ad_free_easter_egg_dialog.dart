import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../skin/skin_controller.dart';

/// Abre el Easter Egg del boton de contenido sin anuncios.
Future<void> showAdFreeEasterEggDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const AdFreeEasterEggDialog(),
  );
}

/// Dialogo tematizado que recuerda, con humor, que Jellyfin no inserta
/// anuncios en la reproduccion.
class AdFreeEasterEggDialog extends ConsumerWidget {
  const AdFreeEasterEggDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final accent = skin?.accent ?? const Color(0xFFAA5CC3);
    final background = skin?.backgroundBottom ?? const Color(0xFF1A2568);

    return Dialog(
      backgroundColor: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: 0.8), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.celebration, color: accent, size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.adFreeEasterEggTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.adFreeEasterEggMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  l10n.adFreeEasterEggClose,
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
