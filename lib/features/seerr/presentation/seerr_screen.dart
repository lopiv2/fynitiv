import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';

/// Seerr: peticiones de contenido a demanda.
///
/// Pantalla placeholder hasta la integración real con la API de
/// Seerr/Overseerr (configuración de servidor y token en ajustes,
/// listado y petición de elementos). De momento solo reserva el hueco
/// en la sidebar (entre Juego online y Biblioteca) y la ruta `/seerr`.
class SeerrScreen extends ConsumerWidget {
  const SeerrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final textSecondary = skin?.textSecondary ?? Colors.white70;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(height: libraryPageTopPadding(context, skin)),
        ),
        SliverToBoxAdapter(
          child: LibraryPageHeader(
            title: l10n.seerr,
            showBack: false,
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    FontAwesomeIcons.cloudArrowDown,
                    color: textSecondary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.seerr,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.seerrComingSoon,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
