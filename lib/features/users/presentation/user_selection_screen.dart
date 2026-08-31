import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_hover_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../household/application/household_provider.dart';
import '../application/users_provider.dart';

/// Pantalla de selección de usuarios estilo Disney+: muestra los usuarios
/// públicos del servidor como perfiles en círculo para entrar de un toque.
class UserSelectionScreen extends ConsumerWidget {
  const UserSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final users = ref.watch(householdUsersProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFF0B1030), Color(0xFF1A2568)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                top: MediaQuery.of(context).size.height * 0.25,
                bottom: MediaQuery.of(context).size.height * 0.25,

                child: users.when(
                  loading: () => const Center(child: AppLoader()),
                  error: (e, _) => _ErrorView(
                    error: e.toString(),
                    onRetry: () => ref.invalidate(householdUsersProvider),
                  ),
                  data: (list) => _buildContent(context, ref, auth, list),
                ),
              ),
              // Overlay bloqueante mientras se autentica el usuario seleccionado.
              // Utiliza AppLoader como en el resto de la app (peticiones DIO).
              if (auth.isLoading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Center(child: AppLoader()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AuthState auth,
    List<UserDto> users,
  ) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)!.whoIsWatching,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 8,
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  spacing: 40,
                  runSpacing: 40,
                  children: [
                    for (final user in users)
                      _UserProfile(
                        user: user,
                        serverUrl: auth.serverUrl,
                        isLoading: auth.isLoading,
                        onTap: () => _selectUser(context, ref, user),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildFooter(context, ref, auth),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref, AuthState auth) {
    final l10n = AppLocalizations.of(context)!;
    if (auth.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          auth.error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    final household = ref.watch(householdProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppHoverButton.text(
          label: l10n.manageHome,
          icon: Icons.home_outlined,
          onPressed: () async {
            if (!await _requirePin(context, ref)) return;
            if (!context.mounted) return;
            await context.push('/setup', extra: household);
          },
        ),
        const SizedBox(width: 8),
        AppHoverButton.text(
          label: l10n.configureServer,
          icon: Icons.settings_outlined,
          onPressed: () async {
            if (!await _requirePin(context, ref)) return;
            await ref.read(authControllerProvider.notifier).logout();
          },
        ),
      ],
    );
  }

  /// Pide el PIN de la casa si está configurado. Devuelve true si se superó.
  Future<bool> _requirePin(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(authControllerProvider.notifier);
    if (!await controller.houseHasPin()) return true;
    if (!context.mounted) return false;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    for (var attempts = 0; attempts < 3; attempts++) {
      final entered = await _promptPin(context);
      if (entered == null) return false;
      if (await controller.verifyHousePin(entered)) return true;
      if (!context.mounted) return false;
      messenger.showSnackBar(SnackBar(content: Text(l10n.wrongPin)));
    }
    return false;
  }

  Future<String?> _promptPin(BuildContext context) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.housePinRequired),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: l10n.pin,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (value) => Navigator.of(context).pop(value),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.masterPinHint,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.enter),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectUser(
    BuildContext context,
    WidgetRef ref,
    UserDto user,
  ) async {
    final controller = ref.read(authControllerProvider.notifier);
    final userId = user.id ?? '';
    final username = user.name ?? '';

    // Intento de entrada: usa el token persistido si existe. Si el servidor lo
    // rechaza (token revocado o sin token y el usuario tiene contraseña),
    // pedimos la contraseña y reintentamos.
    var ok = await controller.loginAsUser(username, userId: userId);
    if (ok) return;
    if (!context.mounted) return;

    final password = await _promptPassword(context, username);
    if (password == null) return;
    ok = await controller.loginAsUser(
      username,
      userId: userId,
      password: password,
    );
    if (!ok && context.mounted) {
      final auth = ref.read(authControllerProvider);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? l10n.loginFailedFallback)),
      );
    }
  }

  Future<String?> _promptPassword(BuildContext context, String username) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.passwordFor(username)),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.password,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(l10n.enter),
            ),
          ],
        );
      },
    );
  }
}

class _UserProfile extends ConsumerStatefulWidget {
  const _UserProfile({
    required this.user,
    required this.serverUrl,
    required this.isLoading,
    required this.onTap,
  });

  final UserDto user;
  final String? serverUrl;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  ConsumerState<_UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends ConsumerState<_UserProfile> {
  bool? _hasValidToken;

  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    final userId = widget.user.id;
    if (userId == null) return;
    final valid = await ref
        .read(authControllerProvider.notifier)
        .hasValidToken(userId);
    if (mounted) setState(() => _hasValidToken = valid);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    return AppHover(
      effect: AppHoverEffect.scale,
      config: AppHoverConfig.scaleOnly(scale: 1.12),
      onTap: widget.isLoading ? () {} : widget.onTap,
      child: Builder(
        builder: (context) {
          final active = AppHoverScope.of(context)?.hovered ?? false;
          return AnimatedOpacity(
            opacity: active ? 1.0 : 0.85,
            duration: const Duration(milliseconds: 180),
            child: SizedBox(
              width: 140,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _Avatar(
                        user: user,
                        serverUrl: widget.serverUrl,
                        isActive: active,
                      ),
                      // Candado: sin token válido guardado (habrá que autenticarse).
                      // Tras resetear o la primera vez, todos los perfiles lo
                      // muestran; al entrar se guarda el token y desaparece.
                      if (_hasValidToken == false)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A2568),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name ?? AppLocalizations.of(context)!.username,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.serverUrl, this.isActive = false});

  final UserDto user;
  final String? serverUrl;
  final bool isActive;

  static const double _size = 110;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = (user.name ?? '?').substring(0, 1).toUpperCase();
    final url = _imageUrl();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
        ),
        border: Border.all(
          color: isActive ? Colors.white : Colors.transparent,
          width: isActive ? 3 : 0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: url != null
          ? ClipOval(
              child: Image.network(
                url,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Initials(initial: initial),
              ),
            )
          : _Initials(initial: initial),
    );
  }

  /// URL de la imagen primaria del usuario:
  /// {server}/Users/{id}/Images/Primary?tag={tag}
  String? _imageUrl() {
    if (serverUrl == null || user.id == null || user.primaryImageTag == null) {
      return null;
    }
    return '$serverUrl/Users/${user.id}/Images/Primary?tag=${user.primaryImageTag}';
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, this.onRetry});

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white70, size: 56),
            const SizedBox(height: 16),
            Text(
              l10n.couldNotConnect,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
