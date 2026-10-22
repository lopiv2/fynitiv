import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';

/// Avatar del usuario con menú desplegable (ajustes y cerrar sesión).
/// Widget genérico reutilizable en la sidebar lateral, la topbar classic
/// y la topbar estilo Netflix.
class UserAvatarMenu extends ConsumerWidget {
  const UserAvatarMenu({
    super.key,
    required this.auth,
    this.compact = false,
    this.onSettings,
  });

  final AuthState auth;

  /// En las barras horizontales se muestra solo el círculo del avatar.
  final bool compact;

  /// Abre la pantalla de Ajustes (sección Preferencias).
  final VoidCallback? onSettings;

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
          } else if (value == 'settings') {
            onSettings?.call();
          }
        },
        itemBuilder: (context) => [
          if (onSettings != null)
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 10),
                  Text(l10n.settings,
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          if (onSettings != null) const PopupMenuDivider(),
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
