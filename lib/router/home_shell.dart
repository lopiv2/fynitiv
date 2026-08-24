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
    final sidebarPosition =
        skin?.sidebarPosition ?? SidebarPosition.left;

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
        autofocus: mode != PlatformMode.tv,
        onFocusChange: (focused) {
          // En TV la barra lateral (skin jellyfin) debe permanecer visible.
          // Antes se colapsaba al enfocar el contenido, lo que la ocultaba
          // siempre por el autofocus inicial. Ya no se colapsa automáticamente.
          if (mode == PlatformMode.tv && focused) {
            ref.read(sidebarControllerProvider.notifier).expand();
          }
        },
        child: navigationShell,
      ),
    );

    final isLeftRight = sidebarPosition == SidebarPosition.left ||
        sidebarPosition == SidebarPosition.right;
    final Widget body;
    if (isLeftRight) {
      body = Row(
        children: [
          if (sidebarWidget != null && sidebarPosition == SidebarPosition.left)
            sidebarWidget,
          content,
          if (sidebarWidget != null && sidebarPosition == SidebarPosition.right)
            sidebarWidget,
        ],
      );
    } else {
      body = Column(
        children: [
          if (sidebarWidget != null && sidebarPosition == SidebarPosition.top)
            sidebarWidget,
          content,
          if (sidebarWidget != null &&
              sidebarPosition == SidebarPosition.bottom)
            sidebarWidget,
        ],
      );
    }

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
          child: body,
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
        // En TV la sidebar debe verse siempre (skin jellyfin: barra izquierda).
        // Ignora el estado colapsado por foco para que no desaparezca al
        // navegar con el mando.
        return true;
      case PlatformMode.mobile:
        return sidebar.expanded && sidebar.visible;
    }
  }
}
