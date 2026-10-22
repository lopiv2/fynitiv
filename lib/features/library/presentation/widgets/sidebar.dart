// ignore: unnecessary_import - PointerDeviceKind usado en _HorizontalScrollBehavior
import 'package:flutter/gestures.dart';
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
import '../../../../core/skin/skin_enums.dart';
import '../../../../core/widgets/scale_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/library_providers.dart';
import 'desktop_library_dialog.dart';
import 'floating_island_bar.dart';
import 'netflix_top_bar.dart';
import 'top_bar_icon_button.dart';
import 'tv_library_modal.dart';
import 'user_avatar_menu.dart';

/// Barra lateral del dashboard (estilo Prime/Disney).
class Sidebar extends ConsumerWidget {
  const Sidebar({
    super.key,
    required this.currentIndex,
    required this.onNavigateBranch,
    this.barOpacity = 1.0,
  });

  final int currentIndex;

  /// Navega a una rama del [StatefulNavigationShell].
  final void Function(int index) onNavigateBranch;

  /// Opacidad de la barra superior anclada Prime (0 transparente arriba, 1 al scrollear).
  final double barOpacity;

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
    final loc = GoRouterState.of(context).matchedLocation;
    // En Disney la sidebar no lista cada biblioteca: un único item
    // Biblioteca (/library) y el item Seerr entre Juegos y Biblioteca.
    final isDisney = skin?.id == 'disney_plus';
    final onLibraries = loc == '/library' || activeViewId != null;
    final onSeerr = loc == '/seerr';
    final horizontal =
        position == SidebarPosition.top || position == SidebarPosition.bottom;
    // Estilo Prime: navegación solo-texto (sin iconos) y Buscar como lupa
    // a la derecha, pegada a Ajustes.
    final isPrimeBar = skin?.topBarStyle == TopBarStyle.prime;
    // VOD dividido en Películas/Series (Disney/Prime).
    final splitVod = skin?.splitVod ?? false;
    final onMovies = loc.startsWith('/vod/movies');
    final onSeries = loc.startsWith('/vod/series');

    final mainItems = <Widget>[
      _NavItem(
        icon: isPrimeBar ? null : Icons.home_outlined,
        selectedIcon: isPrimeBar ? null : Icons.home,
        label: l10n.home,
        selected: currentIndex == 0 && activeViewId == null,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        emphasized: isPrimeBar,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 0 && activeViewId == null,
        // Nodo global para que el featured slider pueda subir a la barra
        // superior desde Inicio o VOD (no solo cuando Inicio está activo).
        focusNode: tvInicioFocusNode,
        onTap: () => _goBranch(context, ref, 0),
      ),
      _NavItem(
        icon: isPrimeBar ? null : Icons.search,
        label: l10n.search,
        selected: currentIndex == 1,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        emphasized: isPrimeBar,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 1,
        onTap: () => _goBranch(context, ref, 1),
      ),
      _NavItem(
        faIcon: isPrimeBar ? null : FontAwesomeIcons.circlePlay,
        label: l10n.vod,
        selected: currentIndex == 2 && !(splitVod && (onMovies || onSeries)),
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        emphasized: isPrimeBar,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 2,
        onTap: () => _goBranch(context, ref, 2),
      ),
      _NavItem(
        faIcon: isPrimeBar ? null : FontAwesomeIcons.tv,
        label: l10n.liveTvRadio,
        selected: currentIndex == 3,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        emphasized: isPrimeBar,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 3,
        onTap: () => _goBranch(context, ref, 3),
      ),
      _NavItem(
        faIcon: isPrimeBar ? null : FontAwesomeIcons.music,
        label: l10n.music,
        selected: currentIndex == 4,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        emphasized: isPrimeBar,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 4,
        onTap: () => _goBranch(context, ref, 4),
      ),
      _NavItem(
        icon: isPrimeBar ? null : Icons.menu_book_outlined,
        selectedIcon: isPrimeBar ? null : Icons.menu_book,
        label: l10n.eReader,
        selected: currentIndex == 5,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        emphasized: isPrimeBar,
        selectedColor: selectedColor,
        autofocus: isTv && currentIndex == 5,
        onTap: () => _goBranch(context, ref, 5),
      ),
      _NavItem(
        icon: isPrimeBar ? null : Icons.sports_esports,
        selectedIcon: isPrimeBar ? null : Icons.sports_esports_rounded,
        label: l10n.games,
        selected: currentIndex == 6,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        emphasized: isPrimeBar,
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
      icon: isPrimeBar ? null : Icons.settings_outlined,
      selectedIcon: isPrimeBar ? null : Icons.settings,
      label: l10n.settings,
      selected: currentIndex == 7,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      iconSpacing: iconSpacing,
      emphasized: isPrimeBar,
      selectedColor: selectedColor,
      autofocus: isTv && currentIndex == 7,
      onTap: () => _goBranch(context, ref, 7),
    );
    // Disney: Biblioteca tras Buscar (posición 3) y Seerr tras Juegos.
    final libraryItem = _NavItem(
      icon: isPrimeBar ? null : Icons.video_library_outlined,
      selectedIcon: isPrimeBar ? null : Icons.video_library,
      label: l10n.library,
      selected: onLibraries,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      iconSpacing: iconSpacing,
      emphasized: isPrimeBar,
      selectedColor: selectedColor,
      autofocus: isTv && onLibraries && !onSeerr,
      onTap: () => context.go('/library'),
    );
    final seerrItem = _NavItem(
      faIcon: isPrimeBar ? null : FontAwesomeIcons.cloudArrowDown,
      label: l10n.seerr,
      selected: onSeerr,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      iconSpacing: iconSpacing,
      emphasized: isPrimeBar,
      selectedColor: selectedColor,
      autofocus: isTv && onSeerr,
      onTap: () => context.go('/seerr'),
    );
    // VOD dividido: Películas y Series tras VOD (Disney/Prime).
    final splitItems = <Widget>[
      _NavItem(
        icon: isPrimeBar ? null : Icons.movie_outlined,
        selectedIcon: isPrimeBar ? null : Icons.movie,
        label: l10n.movies,
        selected: onMovies,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        emphasized: isPrimeBar,
        selectedColor: selectedColor,
        autofocus: isTv && onMovies,
        onTap: () => context.go('/vod/movies'),
      ),
      _NavItem(
        icon: isPrimeBar ? null : Icons.tv_outlined,
        selectedIcon: isPrimeBar ? null : Icons.tv,
        label: l10n.shows,
        selected: onSeries,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        iconSpacing: iconSpacing,
        emphasized: isPrimeBar,
        selectedColor: selectedColor,
        autofocus: isTv && onSeries,
        onTap: () => context.go('/vod/series'),
      ),
    ];
    // Con split, el item VOD se sustituye por Películas/Series en su sitio.
    final vodItems = splitVod ? splitItems : <Widget>[mainItems[2]];
    final verticalItems = isDisney
        ? <Widget>[
            ...mainItems.sublist(0, 2),
            libraryItem,
            ...vodItems,
            ...mainItems.sublist(3),
            seerrItem,
          ]
        : <Widget>[
            ...mainItems.sublist(0, 2),
            ...vodItems,
            ...mainItems.sublist(3),
          ];

    // Flujo de la topbar classic/prime: con split, Películas/Series en
    // el sitio de VOD.
    final flowItems = <Widget>[
      ...mainItems.sublist(0, 2),
      ...vodItems,
      ...mainItems.sublist(3),
    ];
    final logo = _logo(sidebarLogo, textPrimary);
    final avatar = UserAvatarMenu(
      auth: auth,
      onSettings: () => _goBranch(context, ref, 7),
    );

      if (horizontal) {
      final isIsland =
          position == SidebarPosition.top && (skin?.topBarFloating ?? false);
      if (isIsland) {
        return FloatingIslandBar(
          currentIndex: currentIndex,
          onNavigateBranch: onNavigateBranch,
        );
      }
      // Topbar modular por skin: estilo Netflix (avatar izq., nav centrada
      // con píldora, logo dcha.) en lugar de la barra classic.
      if (skin?.topBarStyle == TopBarStyle.netflix) {
        return NetflixTopBar(
          currentIndex: currentIndex,
          onNavigateBranch: (index) => _goBranch(context, ref, index),
          barOpacity: barOpacity,
        );
      }
      // Barra superior fija (Prime sin isla): misma estructura que [Image 1]
      // los extremos no tocan los bordes, solo esquinas inferiores redondeadas en Prime.
      final isAnyLibrarySelected = views.any((v) => v.id == activeViewId);
      final isPrime = skin?.id == 'amazon_prime';
      final effectiveBg = bg.withValues(alpha: barOpacity);
      final effectiveBorder = border.withValues(alpha: 0.6 * barOpacity);
      final effectiveShadow = Colors.black.withValues(alpha: 0.18 * barOpacity);
      final effectiveRadius = isPrime
          ? (position == SidebarPosition.bottom
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : const BorderRadius.vertical(bottom: Radius.circular(12)))
          : BorderRadius.circular(12);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: effectiveBg,
          borderRadius: effectiveRadius,
          border: Border.all(color: effectiveBorder),
          boxShadow: [
            BoxShadow(
              color: effectiveShadow,
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
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // En Prime, Buscar sale del flujo: va como lupa a la
                    // derecha, pegada a Ajustes.
                    ...isPrimeBar
                        ? [flowItems[0], ...flowItems.sublist(2)]
                        : flowItems,
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
                        textOnly: isPrimeBar,
                        emphasized: isPrimeBar,
                      ),
                    seerrItem,
                  ],
                ),
              ),
            ),
            // Lupa de Buscar a la derecha en Prime (sin texto).
            if (isPrimeBar)
              TopBarIconButton(
                icon: Icons.search,
                tooltip: l10n.search,
                onTap: () => _goBranch(context, ref, 1),
              ),
            // En Prime no hay Ajustes en la barra: ya está en el avatar.
            if (!isPrimeBar) settings,
            UserAvatarMenu(
              auth: auth,
              compact: true,
              onSettings: () => _goBranch(context, ref, 7),
            ),
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
                ...verticalItems,
                if (!isDisney) ...[
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

class _NavItem extends ConsumerStatefulWidget {
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
    this.emphasized = false,
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

  /// Resalta el texto: blanco siempre y más peso (estilo Prime).
  final bool emphasized;

  @override
  ConsumerState<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends ConsumerState<_NavItem> {
  bool _hovered = false;

  IconData? get _icon =>
      widget.selected ? (widget.selectedIcon ?? widget.icon) : widget.icon;

  Widget _buildRow({required Color color, required FontWeight weight}) {
    final isTv = (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) == PlatformMode.tv;
    final iconSize = isTv ? 18.0 : 22.0;
    final fontSize = isTv ? 13.0 : 15.0;
    final hasIcon = widget.faIcon != null || widget.icon != null;
    return Row(
      children: [
        if (widget.faIcon != null)
          FaIcon(widget.faIcon, color: color, size: iconSize)
        else if (widget.icon != null)
          Icon(_icon, color: color, size: iconSize),
        if (hasIcon) SizedBox(width: isTv ? 6.0 : widget.iconSpacing),
        Text(
          widget.label,
          style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
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
    final isTv = (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) == PlatformMode.tv;
    final hPad = isTv ? 6.0 : 12.0;
    final vPad = isTv ? 6.0 : 12.0;
    final outerHPad = isTv ? 6.0 : 12.0;

    // Hover/foco: se invierten los colores (fondo blanco, contenido oscuro).
    final Widget content;
    if (_hovered) {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
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
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
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
        child: _buildRow(
          color: textPrimary,
          weight:
              widget.emphasized ? FontWeight.w800 : FontWeight.w600,
        ),
      );
    } else {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? selectedColor ?? widget.accent.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
        child: _buildRow(
          color: widget.emphasized
              ? textPrimary
              : (selected ? textPrimary : textSecondary),
          weight: selected
              ? (widget.emphasized ? FontWeight.w800 : FontWeight.w600)
              : (widget.emphasized ? FontWeight.w700 : FontWeight.w400),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: outerHPad, vertical: 2),
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
    this.textOnly = false,
    this.emphasized = false,
  });

  final List<BaseItemDto> views;
  final String? activeViewId;
  final bool isAnyLibrarySelected;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final double iconSpacing;
  final Color? selectedColor;

  /// Si es `true` no muestra el icono (estilo Prime: solo texto).
  final bool textOnly;

  /// Resalta el texto: blanco siempre y más peso (estilo Prime).
  final bool emphasized;

  @override
  ConsumerState<_TopBarLibraryMenu> createState() => _TopBarLibraryMenuState();
}

class _TopBarLibraryMenuState extends ConsumerState<_TopBarLibraryMenu> {
  bool _hovered = false;

  Widget _buildRow(Color color, FontWeight weight) {
    final l10n = AppLocalizations.of(context)!;
    final isTvRow = (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) == PlatformMode.tv;
    final iconS = isTvRow ? 18.0 : 22.0;
    final fontS = isTvRow ? 13.0 : 15.0;
    final hasIcon = !widget.textOnly;
    return Row(
      children: [
        if (hasIcon) Icon(Icons.video_library_outlined, color: Colors.white, size: iconS),
        if (hasIcon) SizedBox(width: isTvRow ? 6.0 : widget.iconSpacing),
        Text(l10n.library, style: TextStyle(color: color, fontSize: fontS, fontWeight: weight)),
        const SizedBox(width: 4),
        Icon(Icons.arrow_drop_down, color: color.withValues(alpha: 0.85), size: iconS - 2),
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
    final isTvContent = (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) == PlatformMode.tv;
    final hPad = isTvContent ? 6.0 : 12.0;
    final vPad = isTvContent ? 6.0 : 12.0;
    Widget content;
    if (_hovered) {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white),
        child: _buildRow(Colors.black, FontWeight.w600),
      );
    } else if (selected && selectedColor != null) {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [selectedColor, Color.lerp(selectedColor, Colors.black, 0.5)!],
          ),
        ),
        child: _buildRow(
          widget.textPrimary,
          widget.emphasized ? FontWeight.w800 : FontWeight.w600,
        ),
      );
    } else {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? widget.accent.withValues(alpha: 0.35) : Colors.transparent,
        ),
        child: _buildRow(
          widget.emphasized
              ? widget.textPrimary
              : (selected ? widget.textPrimary : widget.textSecondary),
          selected
              ? (widget.emphasized ? FontWeight.w800 : FontWeight.w600)
              : (widget.emphasized ? FontWeight.w700 : FontWeight.w400),
        ),
      );
    }

    final platformMode = ref.watch(platformModeProvider).value ?? PlatformMode.mobile;
    final isTv = platformMode == PlatformMode.tv;
    final isDesktop = platformMode == PlatformMode.desktop;
    final l10n = AppLocalizations.of(context)!;
    if (isTv) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 2),
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
    if (isDesktop) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 2),
        child: GestureDetector(
          onTap: () => showDesktopLibraryDialog(context, widget.views, widget.activeViewId),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: content,
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 2),
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
