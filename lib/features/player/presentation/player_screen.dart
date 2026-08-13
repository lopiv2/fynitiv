import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/feature_placeholder.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: FeaturePlaceholder(
        title: 'Reproductor',
        icon: Icons.play_circle_outline,
        description:
            'La reproducción de video y audio se implementará próximamente.',
      ),
    );
  }
}
