import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/feature_placeholder.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca')),
      body: const FeaturePlaceholder(
        title: 'Tu biblioteca',
        icon: Icons.video_library_outlined,
        description:
            'Películas, series y demás contenido aparecerán aquí.',
      ),
    );
  }
}
