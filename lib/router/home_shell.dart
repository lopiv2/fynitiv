import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/audio/game_bg_player.dart';
import '../core/navigation/platform_mode.dart';
import '../core/navigation/sidebar_controller.dart';
import '../core/settings/game_bg_music_controller.dart';
import '../core/skin/skin.dart';
import '../core/skin/skin_controller.dart';
import '../core/theme/dashboard_background.dart';
import '../features/library/presentation/widgets/sidebar.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> with WidgetsBindingObserver {
  bool _insideGames = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      GameBgPlayer.instance.pauseForExternal();
    } else if (state == AppLifecycleState.resumed) {
      GameBgPlayer.instance.resumeIfNeeded();
    }
  }

  bool _isInsideGames(String loc, int branchIndex) {
    // Solo rama games (índice 5) puede tener música
    if (branchIndex != 5) return false;
    if (loc == '/games') return true;
    if (loc.startsWith('/games/platform')) return true;
    return false;
  }

  void _syncMusic(String loc, int branchIndex) {
    final nowInside = _isInsideGames(loc, branchIndex);
    if (nowInside == _insideGames) return;
    _insideGames = nowInside;
    if (_insideGames) {
      final muted = ref.read(gameBgMutedProvider);
      GameBgPlayer.instance.setMuted(muted);
      GameBgPlayer.instance.enter();
    } else {
      GameBgPlayer.instance.leave();
    }
  }

  @override
  Widget build(BuildContext context) {
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

    ref.listen<bool>(gameBgMutedProvider, (_, muted) {
      GameBgPlayer.instance.setMuted(muted);
    });

    // Sincroniza música según rama y ubicación (hub/lista vs detalle)
    final loc = GoRouterState.of(context).matchedLocation;
    final branchIndex = widget.navigationShell.currentIndex;
    _syncMusic(loc, branchIndex);

    final sidebarWidget = _showSidebar(mode, sidebar)
        ? Sidebar(
            currentIndex: widget.navigationShell.currentIndex,
            onNavigateBranch: (index) => widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            ),
          )
        : null;
    final contentFocus = Focus(
      autofocus: false,
      onFocusChange: (focused) {
        // En TV la barra lateral (skin jellyfin) debe permanecer visible.
        if (mode == PlatformMode.tv && focused) {
          ref.read(sidebarControllerProvider.notifier).expand();
        }
      },
      child: widget.navigationShell,
    );

    final isLeftRight = sidebarPosition == SidebarPosition.left ||
        sidebarPosition == SidebarPosition.right;
    final isFloatingTopIsland =
        sidebarPosition == SidebarPosition.top &&
        (skin?.topBarFloating ?? false);
    final Widget body;
    if (isLeftRight) {
      body = Row(
        children: [
          if (sidebarWidget != null && sidebarPosition == SidebarPosition.left)
            sidebarWidget,
          Expanded(child: contentFocus),
          if (sidebarWidget != null && sidebarPosition == SidebarPosition.right)
            sidebarWidget,
        ],
      );
    } else if (isFloatingTopIsland) {
      // Isla flotante: Stack con el contenido a pantalla completa y la barra
      // pill superpuesta (glass blur radius 28) centrada arriba. La pill
      // abraza su contenido (ver [Image 1]), por eso se centra con Align
      // y no se estira a left/right.
      final topPadding = MediaQuery.of(context).padding.top;
      body = Stack(
        children: [
          Positioned.fill(child: contentFocus),
          if (sidebarWidget != null)
            Positioned(
              top: topPadding + 10,
              left: 0,
              right: 0,
              child: Center(child: sidebarWidget),
            ),
        ],
      );
    } else {
      body = Column(
        children: [
          if (sidebarWidget != null && sidebarPosition == SidebarPosition.top)
            sidebarWidget,
          Expanded(child: contentFocus),
          if (sidebarWidget != null &&
              sidebarPosition == SidebarPosition.bottom)
            sidebarWidget,
        ],
      );
    }

    // Grupo de traversals para que flechas del D-pad (HardwareKeyboard +
    // fallback focusInDirection) puedan moverse entre sidebar y contenido.
    final traversedBody = FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: body,
    );

    // Tras seleccionar perfil (/users → /home) en TV, el foco debe quedar
    // en Inicio de la barra (isla o lateral). El primer _NavItem/
    // _FloatingNavItem tiene autofocus:true en TV, pero tras el redirect de
    // GoRouter el foco anterior (perfil) queda huérfano. Se fuerza nextFocus
    // en el siguiente frame si sigue sin foco o en rootScope.
    if (mode == PlatformMode.tv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final primary = FocusManager.instance.primaryFocus;
        if (primary == null || primary == FocusManager.instance.rootScope || primary.context == null || !primary.context!.mounted) {
          // ignore: use_build_context_synchronously
          FocusScope.of(context).nextFocus();
        }
      });
    }

    return FocusScope(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (mode == PlatformMode.tv && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          ref.read(sidebarControllerProvider.notifier).expand();
          return KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        body: DashboardBackground(
          child: traversedBody,
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
