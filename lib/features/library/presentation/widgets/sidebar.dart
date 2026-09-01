import 'dart:ui';

// ignore: unnecessary_import - PointerDeviceKind usado en _HorizontalScrollBehavior
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/sidebar_controller.dart';
import '../../../../core/skin/skin.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/scale_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../application/library_providers.dart';

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
        onTap: () => _goBranch(context, ref, 4),
      ),
      _NavItem(
        icon: Icons.sports_esports,
        selectedIcon: Icons.sports_esports_rounded,
        label: l10n.games,
        selected: currentIndex == 5,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        selectedColor: selectedColor,
        onTap: () => _goBranch(context, ref, 5),
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
      selected: currentIndex == 6,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      iconSpacing: iconSpacing,
      selectedColor: selectedColor,
      onTap: () => _goBranch(context, ref, 6),
    );

    final logo = _logo(sidebarLogo, textPrimary);
    final avatar = _UserAvatar(auth: auth);

    if (horizontal) {
      final isIsland =
          position == SidebarPosition.top && (skin?.topBarFloating ?? false);
      if (isIsland) {
        // Isla flotante pill con glass blur, radio fijo 28, altura aumentada.
        // En modo isla no se hace scroll horizontal infinito: las bibliotecas
        // de Jellyfin se agrupan bajo un único botón "Biblioteca" con menú
        // desplegable debajo. Así la píldora abraza el contenido como en
        // [Image 1] sin desbordar.
        const islandRadius = 28.0;
        final isAnyLibrarySelected = views.any((v) => v.id == activeViewId);
        final libraryMenu = _IslandLibraryMenu(
          views: views,
          activeViewId: activeViewId,
          isAnyLibrarySelected: isAnyLibrarySelected,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          accent: accent,
          iconSpacing: iconSpacing,
          selectedColor: selectedColor,
        );
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(islandRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 60,
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: bg.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(islandRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.38),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...mainItems,
                    if (views.isNotEmpty) libraryMenu,
                    settings,
                    const SizedBox(width: 4),
                    _UserAvatar(auth: auth, compact: true),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return Container(
        height: 68,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            bottom: position == SidebarPosition.top
                ? BorderSide(color: border)
                : BorderSide.none,
            top: position == SidebarPosition.bottom
                ? BorderSide(color: border)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _logo(sidebarLogo, textPrimary, height: 36, compact: true),
            ),
            // Inicio y Buscar quedan fijos a la izquierda; solo los elementos
            // de la biblioteca hacen scroll en la barra superior.
            ...mainItems,
            Expanded(
              child: ScrollConfiguration(
                behavior: const _HorizontalScrollBehavior(),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    if (viewItems.isNotEmpty) ...[
                      const _SidebarDivider(),
                      ...viewItems,
                    ],
                  ],
                ),
              ),
            ),
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

/// En modo isla la lista de bibliotecas de Jellyfin se colapsa en un único
/// botón "Biblioteca" que despliega hacia abajo (debajo de la píldora) todas
/// las bibliotecas. En barra anclada se mantiene el scroll horizontal.
class _IslandLibraryMenu extends StatefulWidget {
  const _IslandLibraryMenu({
    required this.views,
    required this.activeViewId,
    required this.isAnyLibrarySelected,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.iconSpacing,
    required this.selectedColor,
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
  State<_IslandLibraryMenu> createState() => _IslandLibraryMenuState();
}

class _IslandLibraryMenuState extends State<_IslandLibraryMenu> {
  bool _hovered = false;

  Widget _buildRow(Color color, FontWeight weight) {
    return Row(
      children: [
        const Icon(Icons.video_library_outlined, color: Colors.white, size: 22),
        SizedBox(width: widget.iconSpacing),
        Text(
          'Biblioteca',
          style: TextStyle(color: color, fontSize: 15, fontWeight: weight),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.arrow_drop_down,
          color: color.withValues(alpha: 0.85),
          size: 20,
        ),
      ],
    );
  }

  // Trick: el _LibraryIcon se reutiliza del mixin superior; duplicamos lógica
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
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
        child: _buildRow(
          selected ? widget.textPrimary : widget.textSecondary,
          selected ? FontWeight.w600 : FontWeight.w400,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 48),
        color: const Color(0xFF1A2568),
        tooltip: 'Biblioteca',
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
                        color: widget.activeViewId == v.id ? Colors.white : Colors.white70,
                        fontWeight: widget.activeViewId == v.id ? FontWeight.w700 : FontWeight.w400,
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
        onPressed: widget.onTap,
        onFocusChange: (focused) {
          if (_hovered != focused) setState(() => _hovered = focused);
        },
        child: content,
      ),
    );
  }
}
