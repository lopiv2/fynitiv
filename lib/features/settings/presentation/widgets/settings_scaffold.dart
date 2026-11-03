import 'package:material_ui/material_ui.dart';

import 'settings_metrics.dart';

/// Scaffold único de Ajustes: scroll + safe area inferior + columna
/// centrada con ancho máximo desde tokens.
///
/// Sustituye las copias dispersas (560/560/560/620) de cada panel.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    super.key,
    required this.metrics,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final SettingsMetrics metrics;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: metrics.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: metrics.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: metrics.pageTitleSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: metrics.rowSubtitleSize + 1,
                  ),
                ),
              ],
              SizedBox(height: metrics.groupGap),
              ...children,
              // Colchón inferior: safe area + mini-player / barras laterales.
              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }
}
