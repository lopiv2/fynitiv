import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    final logo = _logo(sidebarLogo, textPrimary);
    final avatar = _UserAvatar(auth: auth);
    final navItems = <Widget>[
      _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n.home,
        selected: currentIndex == 0,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        onTap: () => _goBranch(context, ref, 0),
      ),
      _NavItem(
        icon: Icons.search,
        label: l10n.search,
        selected: currentIndex == 1,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        accent: accent,
        onTap: () => _goBranch(context, ref, 1),
      ),
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
      for (var i = 0; i < views.length; i++)
        _NavItem(
          icon: _viewIcon(views[i]),
          label: views[i].name ?? '',
          selected: false,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          accent: accent,
          onTap: () => context.go('/library/${views[i].id}'),
        ),
    ];
    final settings = _NavItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: l10n.settings,
      selected: currentIndex == 2,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      accent: accent,
      onTap: () => _goBranch(context, ref, 2),
    );

    return Container(
      width: skin?.sidebarWidth ?? 260,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (logoPosition == LogoPosition.top) logo,
          if (avatarPosition == AvatarPosition.top) ...[
            const SizedBox(height: 8),
            avatar,
          ],
          const SizedBox(height: 8),
          ...navItems,
          const Spacer(),
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

  Widget _logo(String? sidebarLogo, Color textPrimary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: sidebarLogo != null
          ? Image.asset(sidebarLogo, height: 80, fit: BoxFit.contain)
          : Text(
              AppConstants.appName,
              style: TextStyle(
                color: textPrimary,
                fontSize: 22,
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
      case CollectionType.movies:
        return Icons.movie_outlined;
      case CollectionType.tvshows:
        return Icons.tv_outlined;
      case CollectionType.music:
        return Icons.music_note_outlined;
      default:
        return Icons.video_library_outlined;
    }
  }
}

/// Avatar del usuario con menú desplegable (cerrar sesión).
class _UserAvatar extends ConsumerWidget {
  const _UserAvatar({required this.auth});

  final AuthState auth;

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              onBackgroundImageError: (_, _) {},
              child: photoUrl != null
                  ? null
                  : Text(initial, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 20),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    this.selected = false,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ScaleButton(
        selected: selected,
        selectedScale: 1.05,
        borderRadius: BorderRadius.circular(10),
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected
                ? accent.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                selected ? (selectedIcon ?? icon) : icon,
                color: selected ? textPrimary : textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: selected ? textPrimary : textSecondary,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
