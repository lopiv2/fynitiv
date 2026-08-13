import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/feature_placeholder.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: const FeaturePlaceholder(
        title: 'Búsqueda',
        icon: Icons.search,
        description: 'Busca películas, series y personas.',
      ),
    );
  }
}
