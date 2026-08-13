import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/feature_placeholder.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: const FeaturePlaceholder(
        title: 'Ajustes',
        icon: Icons.settings_outlined,
        description:
            'Configuración de servidor, cuenta y preferencias.',
      ),
    );
  }
}
