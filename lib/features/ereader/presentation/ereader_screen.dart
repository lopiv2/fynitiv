import 'package:material_ui/material_ui.dart';

import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/feature_placeholder.dart';
import '../../../l10n/app_localizations.dart';

/// Pantalla E-Reader (libros/comics) - placeholder hasta integrar lector.
class EReaderScreen extends StatelessWidget {
  const EReaderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: DashboardBackground(
        child: FeaturePlaceholder(
          title: l10n.eReader,
          icon: Icons.menu_book_outlined,
          description: l10n.eReaderDescription,
        ),
      ),
    );
  }
}
