import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/navigation/tv_focus_nodes.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/skin/skin_enums.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';
import 'top_bar_icon_button.dart';
import 'user_avatar_menu.dart';

/// Barra superior estilo Netflix (foto de referencia): avatar con
/// desplegable a la izquierda, navegación centrada con píldora blanca en el
/// activo y logo de marca a la derecha.
///
/// Los items vienen de `Skin.topBarNavItems` (modular por skin). Se muestra
/// transparente sobre el billboard y se vuelve sólida al hacer scroll
/// (vía [barOpacity], igual que la barra Prime anclada).
class NetflixTopBar extends ConsumerWidget {
  const NetflixTopBar({
    super.key,
    required this.currentIndex,
    required this.onNavigateBranch,
    this.barOpacity = 1.0,
  });

  final int currentIndex;

  /// Navega a una rama del [StatefulNavigationShell].
  final void Function(int index) onNavigateBranch;

  /// Opacidad de la barra (0 transparente arriba, 1 al scrollear).
  final double barOpacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final skin = ref.watch(skinControllerProvider).value;

    final bg = skin?.sidebarBackground ?? const Color(0xFF0A0E24);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final textSecondary = skin?.textSecondary ?? Colors.white70;
    final sidebarLogo = skin?.sidebarLogo;
    final navItems = skin?.topBarNavItems ??
        const [
          TopBarNavItem.search,
          TopBarNavItem.home,
          TopBarNavItem.shows,
          TopBarNavItem.movies,
          TopBarNavItem.books,
          TopBarNavItem.liveTv,
          TopBarNavItem.games,
          TopBarNavItem.seerr,
          TopBarNavItem.myNetflix,
        ];

    // Biblioteca activa según la ruta actual (/library/:viewId).
    final activeViewId = GoRouterState.of(context).pathParameters['viewId'];
    final loc = GoRouterState.of(context).matchedLocation;
    final onLibraries = loc == '/library' || activeViewId != null;
    final onHome = currentIndex == 0 && activeViewId == null && !onLibraries;
    final onMovies = loc.startsWith('/vod/movies');
    final onSeries = loc.startsWith('/vod/series');
    final onSeerr = loc == '/seerr';

    void goBranch(int index) => onNavigateBranch(index);

    return FocusScope(
      // Desde la barra ↓ al banner del slider (nivel intermedio sin dots).
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (tvSliderBannerFocusNode.context != null) {
            tvSliderBannerFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          if (tvSliderFirstActionFocusNode.context != null) {
            tvSliderFirstActionFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          final moved = node.focusInDirection(TraversalDirection.down);
          if (moved) return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: barOpacity),
        gradient: barOpacity < 1
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6 * (1 - barOpacity) + 0.2),
                  Colors.transparent,
                ],
              )
            : null,
      ),
      child: Row(
        children: [
          // Avatar con desplegable (izquierda, como la foto).
          UserAvatarMenu(
            auth: auth,
            compact: true,
            onSettings: () => onNavigateBranch(7),
          ),
          const Icon(
            Icons.arrow_drop_down,
            color: Colors.white70,
            size: 20,
          ),
          // Navegación centrada.
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in navItems)
                      switch (item) {
                        TopBarNavItem.search => TopBarIconButton(
                          icon: Icons.search,
                          tooltip: l10n.search,
                          onTap: () => goBranch(1),
                        ),
                        TopBarNavItem.home => _NetflixPill(
                          label: l10n.home,
                          selected: onHome,
                          autofocus: onHome,
                          focusNode: tvInicioFocusNode,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => goBranch(0),
                        ),
                        TopBarNavItem.shows => _NetflixPill(
                          label: l10n.shows,
                          selected: onSeries,
                          autofocus: onSeries,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => context.go('/vod/series'),
                        ),
                        TopBarNavItem.movies => _NetflixPill(
                          label: l10n.movies,
                          selected: onMovies,
                          autofocus: onMovies,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => context.go('/vod/movies'),
                        ),
                        TopBarNavItem.books => _NetflixPill(
                          label: l10n.eReader,
                          selected:
                              currentIndex == 5 && activeViewId == null,
                          autofocus:
                              currentIndex == 5 && activeViewId == null,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => goBranch(5),
                        ),
                        TopBarNavItem.liveTv => _NetflixPill(
                          label: l10n.liveTvRadio,
                          selected:
                              currentIndex == 3 && activeViewId == null,
                          autofocus:
                              currentIndex == 3 && activeViewId == null,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => goBranch(3),
                        ),
                        TopBarNavItem.games => _NetflixPill(
                          label: l10n.games,
                          selected: currentIndex == 6 && activeViewId == null,
                          autofocus:
                              currentIndex == 6 && activeViewId == null,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => goBranch(6),
                        ),
                        TopBarNavItem.seerr => _NetflixPill(
                          label: l10n.seerr,
                          selected: onSeerr,
                          autofocus: onSeerr,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => context.go('/seerr'),
                        ),
                        TopBarNavItem.myNetflix => _NetflixPill(
                          label: l10n.myNetflix,
                          selected: onLibraries,
                          autofocus: onLibraries,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => context.go('/library'),
                        ),
                      },
                  ],
                ),
              ),
            ),
          ),
          // Logo de marca (derecha, como la N roja de la foto).
          if (sidebarLogo != null)
            Image.asset(sidebarLogo, height: 30, fit: BoxFit.contain)
          else
            Text(
              'N',
              style: TextStyle(
                color: textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// Píldora del nav Netflix: blanca con texto negro en activo/hover/foco,
/// texto gris en reposo. Usa el [AppHover] universal (foco TV incluido).
class _NetflixPill extends StatelessWidget {
  const _NetflixPill({
    required this.label,
    required this.selected,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final bool selected;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AppHover(
        effect: AppHoverEffect.none,
        onTap: onTap,
        autofocus: autofocus,
        focusNode: focusNode,
        child: Builder(
          builder: (context) {
            final hovered =
                AppHoverScope.of(context)?.hovered ?? false;
            final active = selected || hovered;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active ? Colors.white : Colors.transparent,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.black : textSecondary,
                  fontSize: 15,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
