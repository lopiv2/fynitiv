import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'radio_view.dart';

/// Pantalla Radio — archivo separado como solicitado.
///
/// Mantiene los 2 tabs como ahora: este widget es el contenido del tab Radio
/// dentro de LiveTvScreen (shell). También puede usarse standalone si en el
/// futuro se quiere ruta propia /radio.
///
/// Delega toda la UI a RadioView para no duplicar lógica.
class RadioScreen extends ConsumerWidget {
  const RadioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const RadioView();
  }
}
