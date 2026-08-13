import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/navigation/platform_mode.dart';
import '../core/navigation/sidebar_controller.dart';
import '../core/skin/skin.dart';
import '../core/skin/skin_controller.dart';
import '../core/theme/dashboard_background.dart';
import '../features/library/presentation/widgets/sidebar.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(platformModeProvider).value ?? PlatformMode.mobile;
    final sidebar = ref.watch(sidebarControllerProvider);
    final skin = ref.watch(skinControllerProvider).value;
    final sidebarOnRight =
        skin?.sidebarPosition == SidebarPosition.right;

    // En móvil, la sidebar arranca colapsada (se abre con el botón).
    ref.listen(platformModeProvider, (_, next) {
      if (next.value == PlatformMode.mobile) {
        ref.read(sidebarControllerProvider.notifier).collapseForContent();
      }
    });

    final sidebarWidget = _showSidebar(mode, sidebar)
        ? Sidebar(
            currentIndex: navigationShell.currentIndex,
            onNavigateBranch: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
          )
        : null;
    final content = Expanded(
      child: Focus(
        autofocus: true,
        onFocusChange: (focused) {
          if (mode == PlatformMode.tv && focused) {
            ref.read(sidebarControllerProvider.notifier).collapseForContent();
          }
        },
        child: navigationShell,
      ),
    );

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: mode == PlatformMode.tv
          ? (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                ref.read(sidebarControllerProvider.notifier).expand();
              }
            }
          : null,
      child: Scaffold(
        body: DashboardBackground(
          child: Row(
            children: [
              if (sidebarWidget != null && !sidebarOnRight) sidebarWidget,
              content,
              if (sidebarWidget != null && sidebarOnRight) sidebarWidget,
            ],
          ),
        ),
        floatingActionButton: switch (mode) {
          PlatformMode.desktop => FloatingActionButton.small(
              heroTag: 'sidebar_toggle',
              onPressed: () =>
                  ref.read(sidebarControllerProvider.notifier).toggle(),
              child: Icon(
                sidebar.expanded ? Icons.chevron_left : Icons.chevron_right,
              ),
            ),
          PlatformMode.mobile => FloatingActionButton.small(
              heroTag: 'sidebar_mobile_toggle',
              onPressed: () =>
                  ref.read(sidebarControllerProvider.notifier).toggle(),
              child: Icon(sidebar.visible ? Icons.close : Icons.menu),
            ),
          PlatformMode.tv => null,
        },
      ),
    );
  }

  bool _showSidebar(PlatformMode mode, SidebarState sidebar) {
    switch (mode) {
      case PlatformMode.desktop:
        return sidebar.expanded;
      case PlatformMode.tv:
        return sidebar.visible;
      case PlatformMode.mobile:
        return sidebar.expanded && sidebar.visible;
    }
  }
}
