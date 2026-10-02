import 'package:material_ui/material_ui.dart';

import 'app_hover.dart';

/// Elemento de una pestaña para [AppTabBar].
class AppTabItem {
  const AppTabItem({required this.label, this.iconBuilder});

  final String label;

  /// Icono opcional. Recibe si la pestaña está seleccionada para pintar
  /// el color correspondiente (negro seleccionado, blanco70 si no).
  final Widget Function(bool selected)? iconBuilder;
}

/// Barra de pestañas segmentada (estilo pastilla) reutilizable.
///
/// Réplica visual del selector TV / Radio de Live TV, para mantener coherencia
/// en toda la app. Es index-based (no requiere `TabController`) y usa el
/// [AppHover] universal para hover + foco de mando (TV).
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.fontSize = 20,
    this.tabPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  final List<AppTabItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final double fontSize;
  final EdgeInsetsGeometry tabPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _AppTab(
              item: items[i],
              selected: i == index,
              onTap: () => onChanged(i),
              fontSize: fontSize,
              padding: tabPadding,
            ),
          ],
        ],
      ),
    );
  }
}

class _AppTab extends StatelessWidget {
  const _AppTab({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.fontSize,
    required this.padding,
  });

  final AppTabItem item;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.black : Colors.white70;
    return AppHover(
      effect: AppHoverEffect.highlight,
      config: AppHoverConfig(
        duration: const Duration(milliseconds: 150),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        highlightNormal: selected ? Colors.white : Colors.transparent,
        highlightHovered: selected ? Colors.white : Colors.white24,
      ),
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (item.iconBuilder != null) ...[
              item.iconBuilder!(selected),
              const SizedBox(width: 10),
            ],
            Text(
              item.label,
              style: TextStyle(
                color: foreground,
                fontSize: fontSize,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
