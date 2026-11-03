import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_hover.dart';
import 'settings_metrics.dart';

/// Una tarjeta por grupo semántico con filas separadas por `Divider`.
///
/// Pasa de N tarjetas con N bordes y 24 px entre ellas a un grupo con
/// filas de 64–72 px: ~45 % menos scroll (ver FTD `settings-adaptativo`).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.metrics,
    required this.title,
    required this.children,
  });

  final SettingsMetrics metrics;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white70,
              fontSize: metrics.rowTitleSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(metrics.radius),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: Colors.white12),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Fila de ajuste con título, subtítulo opcional y control alineado a un
/// borde derecho fijo.
///
/// La fila interactiva envuelve [AppHover] (regla del proyecto): escala
/// 1.02, contorno 2 px, sonido de hover y `ensureVisibleOnFocus: true`
/// para mando de TV.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.metrics,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.autofocus = false,
  });

  final SettingsMetrics metrics;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(minHeight: metrics.minRowHeight),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.cardPadding,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: metrics.rowTitleSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: metrics.rowSubtitleSize,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: metrics.trailingWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing!,
              ),
            ),
          ],
        ],
      ),
    );

    // Fila informativa sin interacción: sin hover.
    if (onTap == null) return content;

    // En TV la fila debe ser ancha para el foco; en el resto basta el
    // highlight + outline sin escalar el layout.
    return AppHover(
      effect: AppHoverEffect.scaleHighlightOutline,
      config: AppHoverConfig.scaleHighlightOutline(
        scale: 1.02,
        radius: BorderRadius.circular(metrics.radius),
        outlineHoveredWidth: 2,
      ),
      autofocus: autofocus,
      ensureVisibleOnFocus: true,
      onTap: onTap!,
      child: content,
    );
  }
}
