import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/audio_eq_provider.dart';
import '../../../../l10n/app_localizations.dart';

/// Botón toggle universal de Auto-EQ para el music player.
///
/// Al activarlo intenta aplicar el preset que coincida con [genres];
/// al cambiar de canción el contenedor debe llamar a
/// `applyAutoEqForGenres` y mostrar el aviso con [showAutoEqFeedback].
class AutoEqToggleButton extends ConsumerWidget {
  const AutoEqToggleButton({
    super.key,
    required this.genres,
    this.size = 50,
  });

  final List<String>? genres;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(audioEqProvider);
    final active = eq.autoEq;
    return Container(
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: active
            ? Border.all(color: const Color(0xFF4DD0E1), width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ayuda a la izquierda del toggle.
          GestureDetector(
            onTap: () => showAutoEqHelp(context),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E1E2E),
                border: Border.all(color: Colors.white38, width: 1),
              ),
              child: const Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text("Auto-EQ"),
          Switch(
            value: active,
            activeTrackColor: const Color(0xFF4DD0E1),
            activeThumbColor: Colors.white,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            onChanged: (_) => toggleAutoEq(context, ref, genres),
          ),
        ],
      ),
    );
  }
}

/// Activa/desactiva el Auto-EQ y aplica el preset del género actual.
Future<void> toggleAutoEq(
  BuildContext context,
  WidgetRef ref,
  List<String>? genres,
) async {
  final notifier = ref.read(audioEqProvider.notifier);
  final currentlyOn = ref.read(audioEqProvider).autoEq;
  if (currentlyOn) {
    notifier.setAutoEq(false);
    if (context.mounted) {
      showAutoEqFeedback(context, null, disabled: true);
    }
    return;
  }
  notifier.setAutoEq(true);
  final applied = notifier.applyAutoEqForGenres(genres);
  if (context.mounted) {
    showAutoEqFeedback(context, applied);
  }
}

/// Diálogo de ayuda que explica qué hace el toggle de Auto-EQ.
void showAutoEqHelp(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        l10n.autoEq,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        l10n.autoEqTooltip,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(
            l10n.accept,
            style: const TextStyle(color: Color(0xFF4DD0E1)),
          ),
        ),
      ],
    ),
  );
}

/// Notificación de confirmación del Auto-EQ (aplicado / sin coincidencia).
/// Usa el sistema universal (EasyLoading): no necesita ScaffoldMessenger.
/// Si hay coincidencia muestra preset + género coincidente.
void showAutoEqFeedback(BuildContext context, AutoEqMatch? applied,
    {bool disabled = false}) {
  final l10n = AppLocalizations.of(context)!;
  final text = disabled
      ? l10n.autoEqOff
      : applied != null
          ? l10n.autoEqApplied(applied.preset, applied.genre)
          : l10n.autoEqNoMatch;
  unawaited(
    EasyLoading.showToast(
      text,
      toastPosition: EasyLoadingToastPosition.bottom,
      maskType: EasyLoadingMaskType.none,
      dismissOnTap: true,
    ),
  );
}
