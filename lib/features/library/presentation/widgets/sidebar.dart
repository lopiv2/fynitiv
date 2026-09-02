// ignore: unnecessary_import - PointerDeviceKind usado en _HorizontalScrollBehavior
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/platform_mode.dart';
import '../../../../core/navigation/sidebar_controller.dart';
import '../../../../core/navigation/tv_focus_nodes.dart';
import '../../../../core/skin/skin.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/scale_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../application/library_providers.dart';
import 'floating_island_bar.dart';
import 'tv_library_modal.dart';

/// Barra lateral del dashboard (estilo Prime/Disney).
class Sidebar extends ConsumerWidget {
  const Sidebar({
    super.key,
    required this.currentIndex,
    required this.onNavigateBranch,
  });

  final int currentIndex;

  /// Navega a una rama del [StatefulNavigationShell].
  final void Function(int index) onNavigateBranch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final views = ref.watch(userViewsProvider).value ?? const <BaseItemDto>[];
    final auth = ref.watch(authControllerProvider);
    final skin = ref.watch(skinControllerProvider).value;

    final bg = skin?.sidebarBackground ?? const Color(0xFF0A0E24);
    final border = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final textSecondary = skin?.textSecondary ?? Colors.white70;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final sidebarLogo = skin?.sidebarLogo;
    final logoPosition = skin?.logoPosition ?? LogoPosition.top;
    final avatarPosition = skin?.avatarPosition ?? AvatarPosition.top;
    final headerSpacing = skin?.sidebarHeaderSpacing ?? 8;
    final iconSpacing = skin?.navItemIconSpacing ?? 12;
    final position = skin?.sidebarPosition ?? SidebarPosition.left;
    final selectedColor = skin?.sidebarSelectedColor;
    final isTv = (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) == PlatformMode.tv;
    // Bibliotecta activa según la ruta actual (/library/:viewId).
    final activeViewId = GoRouterState.of(context).pathParameters['viewId'];
    final horizontal =
        position == SidebarPosition.top || position == SidebarPosition.bottom;

    final mainItems = <Widget>[
      _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n.home,
        selected: currentIndex == 0 && activeViewId == null,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 0 && activeViewId == null,
        focusNode: isTv && currentIndex == 0 && activeViewId == null ? tvInicioFocusNode : null,
        onTap: () => _goBranch(context, ref, 0),
      ),
      _NavItem(
        icon: Icons.search,
        label: l10n.search,
        selected: currentIndex == 1,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 1,
        onTap: () => _goBranch(context, ref, 1),
      ),
      _NavItem(
        faIcon: FontAwesomeIcons.circlePlay,
        label: l10n.vod,
        selected: currentIndex == 2,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 2,
        onTap: () => _goBranch(context, ref, 2),
      ),
      _NavItem(
        faIcon: FontAwesomeIcons.tv,
        label: l10n.liveTv,
        selected: currentIndex == 3,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 3,
        onTap: () => _goBranch(context, ref, 3),
      ),
      _NavItem(
        faIcon: FontAwesomeIcons.music,
        label: l10n.music,
        selected: currentIndex == 4,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 4,
        onTap: () => _goBranch(context, ref, 4),
      ),
      _NavItem(
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
        label: l10n.eReader,
        selected: currentIndex == 5,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 5,
        onTap: () => _goBranch(context, ref, 5),
      ),
      _NavItem(
        icon: Icons.sports_esports,
        selectedIcon: Icons.sports_esports_rounded,
        label: l10n.games,
        selected: currentIndex == 6,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 6,
        onTap: () => _goBranch(context, ref, 6),
      ),
    ];
    final viewItems = <Widget>[
      for (var i = 0; i < views.length; i++)
        _NavItem(
          icon: _viewIcon(views[i]),
          label: views[i].name ?? '',
          selected: activeViewId == views[i].id,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          accent: accent,
          iconSpacing: iconSpacing,
          selectedColor: selectedColor,
          onTap: () => context.go('/library/${views[i].id}'),
        ),
    ];
    final settings = _NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: l10n.settings,
      selected: currentIndex == 7,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      iconSpacing: iconSpacing,
      selectedColor: selectedColor,
      autofocus: isTv && currentIndex == 7,
      onTap: () => _goBranch(context, ref, 7),
    );

    final logo = _logo(sidebarLogo, textPrimary);
    final avatar = _UserAvatar(auth: auth);

      if (horizontal) {
      final isIsland =
          position == SidebarPosition.top && (skin?.topBarFloating ?? false);
      if (isIsland) {
        return FloatingIslandBar(
          currentIndex: currentIndex,
          onNavigateBranch: onNavigateBranch,
        );
      }
      // Barra superior fija (Prime sin isla): misma estructura que [Image 1]
      // los extremos no tocan los bordes de la pantalla (como la isla).
      final isAnyLibrarySelected = views.any((v) => v.id == activeViewId);
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _logo(sidebarLogo, textPrimary, height: 36, compact: true),
            ),
            ...mainItems,
            if (views.isNotEmpty)
              _TopBarLibraryMenu(
                views: views,
                activeViewId: activeViewId,
                isAnyLibrarySelected: isAnyLibrarySelected,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent,
                iconSpacing: iconSpacing,
                selectedColor: selectedColor,
              ),
            const Spacer(),
            settings,
            _UserAvatar(auth: auth, compact: true),
          ],
        ),
      );
    }

    return Container(
      width: skin?.sidebarWidth ?? 260,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          right: position == SidebarPosition.left
              ? BorderSide(color: border)
              : BorderSide.none,
          left: position == SidebarPosition.right
              ? BorderSide(color: border)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (logoPosition == LogoPosition.top) logo,
          if (avatarPosition == AvatarPosition.top) ...[
            SizedBox(height: headerSpacing),
            avatar,
          ],
          SizedBox(height: headerSpacing),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...mainItems,
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l10n.library.toUpperCase(),
                    style: TextStyle(
                      color: textSecondary.withValues(alpha: 0.5),
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...viewItems,
              ],
            ),
          ),
          settings,
          if (avatarPosition == AvatarPosition.bottom) ...[
            Divider(color: border),
            avatar,
          ],
          if (logoPosition == LogoPosition.bottom) ...[
            Divider(color: border),
            logo,
          ],
        ],
      ),
    );
  }

  Widget _logo(
    String? sidebarLogo,
    Color textPrimary, {
    double height = 80,
    bool compact = false,
  }) {
    return Padding(
      padding: compact
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: sidebarLogo != null
          ? Image.asset(sidebarLogo, height: height, fit: BoxFit.contain)
          : Text(
              AppConstants.appName,
              style: TextStyle(
                color: textPrimary,
                fontSize: compact ? 18 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
    );
  }

  void _goBranch(BuildContext context, WidgetRef ref, int index) {
    onNavigateBranch(index);
    ref.read(sidebarControllerProvider.notifier).expand();
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
}

/// Comportamiento de scroll para la barra horizontal: permite arrastrar con el
/// ratón y usar la rueda sin necesidad de Shift, para que todos los items sean
/// accesibles.
class _HorizontalScrollBehavior extends MaterialScrollBehavior {
  const _HorizontalScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers =>
      const <LogicalKeyboardKey>{};
}

/// Separador vertical entre grupos de la barra horizontal.
class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: VerticalDivider(width: 1, color: Colors.white24),
    );
  }
}

/// Avatar del usuario con menú desplegable (cerrar sesión).
class _UserAvatar extends ConsumerWidget {
  const _UserAvatar({required this.auth, this.compact = false});

  final AuthState auth;

  /// En la barra horizontal se muestra solo el círculo del avatar.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final name = auth.user?.name ?? auth.userId ?? '';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    // URL de la imagen primaria del usuario si está disponible.
    String? photoUrl;
    final serverUrl = auth.serverUrl;
    final userId = auth.userId;
    final tag = auth.user?.primaryImageTag;
    if (serverUrl != null && userId != null && tag != null) {
      photoUrl = '$serverUrl/Users/$userId/Images/Primary?tag=$tag';
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16, vertical: 8),
      child: PopupMenuButton<String>(
        tooltip: name.isEmpty ? null : name,
        position: PopupMenuPosition.under,
        color: const Color(0xFF1A2568),
        onSelected: (value) {
          if (value == 'logout') {
            ref.read(authControllerProvider.notifier).logout();
          }
        },
        itemBuilder: (context) => [
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
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            CircleAvatar(
              radius: compact ? 18 : 28,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              onBackgroundImageError: photoUrl != null ? (_, _) {} : null,
              child: photoUrl != null
                  ? null
                  : Text(initial, style: const TextStyle(fontSize: 16)),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                color: Colors.white54,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
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
  });

  final IconData? icon;
  final IconData? selectedIcon;

  /// Icono de Font Awesome (renderizado con [FaIcon]). Si se aporta, sustituye
  /// a [icon] en el dibujado del item.
  final FaIconData? faIcon;

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final double iconSpacing;

  /// Color del item seleccionado. Si no es nulo, se muestra con degradado
  /// vertical y un pequeño flash blanco en la parte superior.
  final Color? selectedColor;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  IconData? get _icon =>
      widget.selected ? (widget.selectedIcon ?? widget.icon) : widget.icon;

  Widget _buildRow({required Color color, required FontWeight weight}) {
    return Row(
      children: [
        if (widget.faIcon != null)
          FaIcon(widget.faIcon, color: color, size: 22)
        else if (widget.icon != null)
          Icon(_icon, color: color, size: 22),
        SizedBox(width: widget.iconSpacing),
        Text(
          widget.label,
          style: TextStyle(color: color, fontSize: 15, fontWeight: weight),
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

    // Hover/foco: se invierten los colores (fondo blanco, contenido oscuro).
    final Widget content;
    if (_hovered) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: _buildRow(color: Colors.black, weight: FontWeight.w600),
      );
    } else if (selected && selectedColor != null) {
      // Mismo tamaño que el hover: contenedor con degradado vertical.
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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

/// Dropdown de bibliotecas para la barra superior fija (no isla).
/// Mismo comportamiento que la isla: en TV abre modal, en desktop popup hacia abajo.
class _TopBarLibraryMenu extends ConsumerStatefulWidget {
  const _TopBarLibraryMenu({
    required this.views,
    required this.activeViewId,
    required this.isAnyLibrarySelected,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.iconSpacing,
    this.selectedColor,
  });

  final List<BaseItemDto> views;
  final String? activeViewId;
  final bool isAnyLibrarySelected;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final double iconSpacing;
  final Color? selectedColor;

  @override
  ConsumerState<_TopBarLibraryMenu> createState() => _TopBarLibraryMenuState();
}

class _TopBarLibraryMenuState extends ConsumerState<_TopBarLibraryMenu> {
  bool _hovered = false;

  Widget _buildRow(Color color, FontWeight weight) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        const Icon(Icons.video_library_outlined, color: Colors.white, size: 22),
        SizedBox(width: widget.iconSpacing),
        Text(l10n.library, style: TextStyle(color: color, fontSize: 15, fontWeight: weight)),
        const SizedBox(width: 4),
        Icon(Icons.arrow_drop_down, color: color.withValues(alpha: 0.85), size: 20),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white),
        child: _buildRow(Colors.black, FontWeight.w600),
      );
    } else if (selected && selectedColor != null) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [selectedColor, Color.lerp(selectedColor, Colors.black, 0.5)!],
          ),
        ),
        child: _buildRow(widget.textPrimary, FontWeight.w600),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? widget.accent.withValues(alpha: 0.35) : Colors.transparent,
        ),
        child: _buildRow(selected ? widget.textPrimary : widget.textSecondary, selected ? FontWeight.w600 : FontWeight.w400),
      );
    }

    final isTv = (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) == PlatformMode.tv;
    final l10n = AppLocalizations.of(context)!;
    if (isTv) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ScaleButton(
          selected: selected,
          selectedScale: 1.05,
          borderRadius: BorderRadius.circular(10),
          onPressed: () => showTvLibraryModal(context, widget.views, widget.activeViewId),
          onFocusChange: (f) => setState(() => _hovered = f),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: content,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                    child: Text(v.name ?? '',
                        style: TextStyle(
                            color: widget.activeViewId == v.id ? Colors.white : Colors.white70,
                            fontWeight: widget.activeViewId == v.id ? FontWeight.w700 : FontWeight.w400)),
                  ),
                  if (widget.activeViewId == v.id) const Icon(Icons.check, color: Colors.white, size: 16),
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
