import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/navigation/platform_mode.dart';
import '../../../../core/navigation/sidebar_controller.dart';
import '../../../../core/navigation/tv_focus_nodes.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../core/widgets/scale_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../application/library_providers.dart';
import 'tv_library_modal.dart';

/// Barra superior en modo isla flotante (pill con glass blur, radio 28).
///
/// Extraída de `Sidebar` para separar la variante flotante de la barra
/// superior normal (`height: 68` con scroll) y de la lateral (`width: 260`).
/// La isla agrupa las bibliotecas de Jellyfin en un único botón "Biblioteca"
/// y abraza el contenido como en la maqueta de referencia.
class FloatingIslandBar extends ConsumerWidget {
  const FloatingIslandBar({
    super.key,
    required this.currentIndex,
    required this.onNavigateBranch,
  });

  final int currentIndex;
  final void Function(int index) onNavigateBranch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final views = ref.watch(userViewsProvider).value ?? const <BaseItemDto>[];
    final auth = ref.watch(authControllerProvider);
    final skin = ref.watch(skinControllerProvider).value;

    final bg = skin?.sidebarBackground ?? const Color(0xFF0A0E24);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final textSecondary = skin?.textSecondary ?? Colors.white70;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final iconSpacing = skin?.navItemIconSpacing ?? 12;
    final selectedColor = skin?.sidebarSelectedColor;
    final activeViewId = GoRouterState.of(context).pathParameters['viewId'];
    final isTv =
        (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) ==
        PlatformMode.tv;
    // En TV la isla tiene 8 destinos (Home..E-Reader..Games..Settings) y desborda
    // en 720p / pantallas estrechas. Se reduce espaciado y tipografía solo en TV
    // para evitar RenderFlex overflow 74px sin afectar desktop/tablet.
    final tvIconSpacing = isTv ? 6.0 : iconSpacing;
    final tvFontSize = isTv ? 15.0 : 15.0;
    final tvIconSize = isTv ? 20.0 : 22.0;
    final tvItemHPad = isTv ? 8.0 : 9.0;
    final tvItemVPad = isTv ? 2.0 : 12.0;

    final mainItems = <Widget>[
      _FloatingNavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n.home,
        selected: currentIndex == 0 && activeViewId == null,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: tvIconSpacing,
        fontSize: tvFontSize,
        iconSize: tvIconSize,
        hPad: tvItemHPad,
        vPad: tvItemVPad,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 0 && activeViewId == null,
        focusNode: tvInicioFocusNode,
        onTap: () => _goBranch(context, ref, 0),
      ),
      _FloatingNavItem(
        icon: Icons.search,
        label: l10n.search,
        selected: currentIndex == 1,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: tvIconSpacing,
        fontSize: tvFontSize,
        iconSize: tvIconSize,
        hPad: tvItemHPad,
        vPad: tvItemVPad,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 1,
        onTap: () => _goBranch(context, ref, 1),
      ),
      _FloatingNavItem(
        faIcon: FontAwesomeIcons.circlePlay,
        label: l10n.vod,
        selected: currentIndex == 2,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: tvIconSpacing,
        fontSize: tvFontSize,
        iconSize: tvIconSize,
        hPad: tvItemHPad,
        vPad: tvItemVPad,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 2,
        onTap: () => _goBranch(context, ref, 2),
      ),
      _FloatingNavItem(
        faIcon: FontAwesomeIcons.tv,
        label: l10n.liveTv,
        selected: currentIndex == 3,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: tvIconSpacing,
        fontSize: tvFontSize,
        iconSize: tvIconSize,
        hPad: tvItemHPad,
        vPad: tvItemVPad,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 3,
        onTap: () => _goBranch(context, ref, 3),
      ),
      _FloatingNavItem(
        faIcon: FontAwesomeIcons.music,
        label: l10n.music,
        selected: currentIndex == 4,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: tvIconSpacing,
        fontSize: tvFontSize,
        iconSize: tvIconSize,
        hPad: tvItemHPad,
        vPad: tvItemVPad,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 4,
        onTap: () => _goBranch(context, ref, 4),
      ),
      _FloatingNavItem(
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
        label: l10n.eReader,
        selected: currentIndex == 5,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: tvIconSpacing,
        fontSize: tvFontSize,
        iconSize: tvIconSize,
        hPad: tvItemHPad,
        vPad: tvItemVPad,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 5,
        onTap: () => _goBranch(context, ref, 5),
      ),
      _FloatingNavItem(
        icon: Icons.sports_esports,
        selectedIcon: Icons.sports_esports_rounded,
        label: l10n.games,
        selected: currentIndex == 6,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: tvIconSpacing,
        fontSize: tvFontSize,
        iconSize: tvIconSize,
        hPad: tvItemHPad,
        vPad: tvItemVPad,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 6,
        onTap: () => _goBranch(context, ref, 6),
      ),
    ];

    final settings = _FloatingNavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: l10n.settings,
      selected: currentIndex == 7,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      iconSpacing: tvIconSpacing,
      fontSize: tvFontSize,
      iconSize: tvIconSize,
      hPad: tvItemHPad,
      vPad: tvItemVPad,
      selectedColor: selectedColor,
      autofocus: isTv && currentIndex == 7,
        onTap: () => _goBranch(context, ref, 7),
      );

    const islandRadius = 28.0;
    final isAnyLibrarySelected = views.any((v) => v.id == activeViewId);
    final libraryMenu = _FloatingLibraryMenu(
      views: views,
      activeViewId: activeViewId,
      isAnyLibrarySelected: isAnyLibrarySelected,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      iconSpacing: tvIconSpacing,
      fontSize: tvFontSize,
      iconSize: tvIconSize,
      hPad: tvItemHPad,
      vPad: tvItemVPad,
      selectedColor: selectedColor,
    );

    return FocusScope(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          // Desde cualquier elemento de la isla ↓ siempre a Ver ahora
          if (tvSliderFirstActionFocusNode.context != null) {
            tvSliderFirstActionFocusNode.requestFocus();
            return KeyEventResult.handled;
          }
          // Fallback: intentar foco direccional abajo
          final moved = node.focusInDirection(TraversalDirection.down);
          if (moved) return KeyEventResult.handled;
          // Último fallback: root down
          final root = FocusManager.instance.rootScope;
          if (root.focusInDirection(TraversalDirection.down)) {
            return KeyEventResult.handled;
          }
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          // Desde isla ↑ no hace nada (arriba no hay)
          return KeyEventResult.ignored;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(islandRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
              height: 60,
              constraints: const BoxConstraints(maxWidth: 1280),
              padding: EdgeInsets.symmetric(horizontal: isTv ? 4 : 8),
              decoration: BoxDecoration(
                color: bg.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(islandRadius),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.38),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Para modo normal también había overflow de 74px tras añadir E-Reader.
                    // Se envuelve en scroll horizontal para que nunca de Layout overflow,
                    // manteniendo el tamaño compacto en TV ya aplicado arriba.
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...mainItems,
                          if (views.isNotEmpty) libraryMenu,
                          settings,
                          const SizedBox(width: 4),
                          _FloatingUserAvatar(auth: auth, compact: true),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _goBranch(BuildContext context, WidgetRef ref, int index) {
    onNavigateBranch(index);
    ref.read(sidebarControllerProvider.notifier).expand();
  }
}

/// Botón de bibliotecas colapsado para la isla.
class _FloatingLibraryMenu extends ConsumerStatefulWidget {
  const _FloatingLibraryMenu({
    required this.views,
    required this.activeViewId,
    required this.isAnyLibrarySelected,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.iconSpacing,
    required this.selectedColor,
    this.fontSize = 15,
    this.iconSize = 22,
    this.hPad = 12,
    this.vPad = 12,
  });

  final List<BaseItemDto> views;
  final String? activeViewId;
  final bool isAnyLibrarySelected;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final double iconSpacing;
  final Color? selectedColor;
  final double fontSize;
  final double iconSize;
  final double hPad;
  final double vPad;

  @override
  ConsumerState<_FloatingLibraryMenu> createState() =>
      _FloatingLibraryMenuState();
}

class _FloatingLibraryMenuState extends ConsumerState<_FloatingLibraryMenu> {
  bool _hovered = false;

  Widget _buildRow(Color color, FontWeight weight) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Icon(Icons.video_library_outlined, color: Colors.white, size: widget.iconSize),
        SizedBox(width: widget.iconSpacing),
        Text(
          l10n.library,
          style: TextStyle(color: color, fontSize: widget.fontSize, fontWeight: weight),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.arrow_drop_down,
          color: color.withValues(alpha: 0.85),
          size: widget.iconSize - 2,
        ),
      ],
    );
  }

  IconData _viewIcon(BaseItemDto view) {
    switch (view.collectionType) {
      case CollectionType.books:
        return Icons.menu_book_outlined;
      case CollectionType.playlists:
        return Icons.queue_music_outlined;
      case CollectionType.boxsets:
        return Icons.collections_bookmark_outlined;
      case CollectionType.movies:
        return Icons.movie_outlined;
      case CollectionType.tvshows:
        return Icons.tv_outlined;
      case CollectionType.music:
        return Icons.music_note_outlined;
      case CollectionType.livetv:
        return Icons.live_tv_outlined;
      default:
        return Icons.video_library_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.isAnyLibrarySelected;
    final selectedColor = widget.selectedColor;
    Widget content;
    if (_hovered) {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: widget.vPad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: _buildRow(Colors.black, FontWeight.w600),
      );
    } else if (selected && selectedColor != null) {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: widget.vPad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              selectedColor,
              Color.lerp(selectedColor, Colors.black, 0.5)!,
            ],
          ),
        ),
        child: _buildRow(widget.textPrimary, FontWeight.w600),
      );
    } else {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: widget.vPad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? widget.accent.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
        child: _buildRow(
          selected ? widget.textPrimary : widget.textSecondary,
          selected ? FontWeight.w600 : FontWeight.w400,
        ),
      );
    }

    final platformMode =
        ref.watch(platformModeProvider).value ?? PlatformMode.mobile;
    final isTv = platformMode == PlatformMode.tv;
    final l10n = AppLocalizations.of(context)!;

    if (isTv) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: 2),
        child: ScaleButton(
          selected: selected,
          selectedScale: 1.05,
          borderRadius: BorderRadius.circular(10),
          onPressed: () =>
              showTvLibraryModal(context, widget.views, widget.activeViewId),
          onFocusChange: (focused) {
            if (_hovered != focused) setState(() => _hovered = focused);
          },
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: 2),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 48),
        color: const Color(0xFF1A2568),
        tooltip: l10n.library,
        onSelected: (id) => context.go('/library/$id'),
        itemBuilder: (context) => [
          for (final v in widget.views)
            PopupMenuItem<String>(
              value: v.id ?? '',
              child: Row(
                children: [
                  Icon(_viewIcon(v), color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      v.name ?? '',
                      style: TextStyle(
                        color: widget.activeViewId == v.id
                            ? Colors.white
                            : Colors.white70,
                        fontWeight: widget.activeViewId == v.id
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (widget.activeViewId == v.id)
                    const Icon(Icons.check, color: Colors.white, size: 16),
                ],
              ),
            ),
        ],
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: content,
        ),
      ),
    );
  }
}

class _FloatingNavItem extends StatefulWidget {
  const _FloatingNavItem({
    this.icon,
    required this.label,
    required this.onTap,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.iconSpacing,
    this.selected = false,
    this.selectedIcon,
    this.selectedColor,
    this.faIcon,
    this.autofocus = false,
    this.focusNode,
    this.fontSize = 15,
    this.iconSize = 22,
    this.hPad = 12,
    this.vPad = 12,
  });

  final IconData? icon;
  final IconData? selectedIcon;
  final FaIconData? faIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final double iconSpacing;
  final double fontSize;
  final double iconSize;
  final double hPad;
  final double vPad;
  final Color? selectedColor;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<_FloatingNavItem> createState() => _FloatingNavItemState();
}

class _FloatingNavItemState extends State<_FloatingNavItem> {
  bool _hovered = false;
  IconData? get _icon =>
      widget.selected ? (widget.selectedIcon ?? widget.icon) : widget.icon;
  Widget _buildRow({required Color color, required FontWeight weight}) {
    return Row(
      children: [
        if (widget.faIcon != null)
          FaIcon(widget.faIcon, color: color, size: widget.iconSize)
        else if (widget.icon != null)
          Icon(_icon, color: color, size: widget.iconSize),
        SizedBox(width: widget.iconSpacing),
        Text(
          widget.label,
          style: TextStyle(color: color, fontSize: widget.fontSize, fontWeight: weight),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final selectedColor = widget.selectedColor;
    final textPrimary = widget.textPrimary;
    final textSecondary = widget.textSecondary;
    final Widget content;
    if (_hovered) {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: widget.vPad),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: _buildRow(color: Colors.black, weight: FontWeight.w600),
      );
    } else if (selected && selectedColor != null) {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: widget.vPad),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              selectedColor,
              Color.lerp(selectedColor, Colors.black, 0.5)!,
            ],
          ),
        ),
        child: _buildRow(color: textPrimary, weight: FontWeight.w600),
      );
    } else {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: widget.vPad),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? selectedColor ?? widget.accent.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
        child: _buildRow(
          color: selected ? textPrimary : textSecondary,
          weight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.hPad, vertical: 2),
      child: ScaleButton(
        selected: selected,
        selectedScale: 1.05,
        borderRadius: BorderRadius.circular(10),
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        onPressed: widget.onTap,
        onFocusChange: (focused) {
          if (_hovered != focused) setState(() => _hovered = focused);
        },
        child: content,
      ),
    );
  }
}

class _FloatingUserAvatar extends ConsumerWidget {
  const _FloatingUserAvatar({required this.auth, this.compact = false});
  final AuthState auth;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final name = auth.user?.name ?? auth.userId ?? '';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    String? photoUrl;
    final serverUrl = auth.serverUrl;
    final userId = auth.userId;
    final tag = auth.user?.primaryImageTag;
    if (serverUrl != null && userId != null && tag != null) {
      photoUrl = '$serverUrl/Users/$userId/Images/Primary?tag=$tag';
    }

    Future<void> showLogoutMenu(BuildContext btnContext) async {
      final overlay =
          Overlay.of(btnContext).context.findRenderObject() as RenderBox;
      final box = btnContext.findRenderObject() as RenderBox?;
      RelativeRect position;
      if (box != null && box.hasSize) {
        final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
        position = RelativeRect.fromLTRB(
          topLeft.dx,
          topLeft.dy + box.size.height + 8,
          overlay.size.width - topLeft.dx - box.size.width,
          overlay.size.height - topLeft.dy,
        );
      } else {
        position = const RelativeRect.fromLTRB(100, 100, 100, 100);
      }
      final result = await showMenu<String>(
        context: btnContext,
        position: position,
        color: const Color(0xFF1A2568),
        items: [
          PopupMenuItem(
            value: 'logout',
            child: Row(
              children: [
                const Icon(Icons.logout, color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                Text(l10n.logout, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      );
      if (result == 'logout') {
        ref.read(authControllerProvider.notifier).logout();
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16, vertical: 8),
      child: Builder(
        builder: (btnContext) {
          return AppHover(
            effect: AppHoverEffect.scale,
            config: AppHoverConfig.scaleOnly(scale: 1.12),
            onTap: () => showLogoutMenu(btnContext),
            child: Builder(
              builder: (innerContext) {
                final active = AppHoverScope.of(innerContext)?.hovered ?? false;
                return Row(
                  mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.all(active ? 0 : 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? Colors.white : Colors.transparent,
                          width: active ? 3 : 0,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: compact ? 18 : 28,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        onBackgroundImageError: photoUrl != null
                            ? (_, _) {}
                            : null,
                        child: photoUrl != null
                            ? null
                            : Text(
                                initial,
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
