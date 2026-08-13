import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/di/providers.dart';
import '../../../core/security/pin_hasher.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../users/application/users_provider.dart';
import '../application/household_provider.dart';
import '../domain/household.dart';

/// Asistente de configuración de la casa: conecta el servidor, marca los
/// usuarios que pertenecen a este hogar y le da nombre.
///
/// También se usa para gestionar una casa ya existente: si [initialHousehold]
/// viene informado, los usuarios ya seleccionados aparecen marcados.
class HouseholdWizardScreen extends ConsumerStatefulWidget {
  const HouseholdWizardScreen({super.key, this.initialHousehold});

  final Household? initialHousehold;

  @override
  ConsumerState<HouseholdWizardScreen> createState() =>
      _HouseholdWizardScreenState();
}

class _HouseholdWizardScreenState extends ConsumerState<HouseholdWizardScreen> {
  final _serverController = TextEditingController();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  late int _step;
  bool _saving = false;
  late final Set<String> _selected;
  String? _masterPin;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    // Si ya hay servidor configurado, empezamos en la selección de usuarios.
    _step = _serverConfigured ? 1 : 0;
    _selected = {...?widget.initialHousehold?.userIds};
    _nameController.text = widget.initialHousehold?.name ?? '';
    _masterPin = ref.read(authControllerProvider.notifier).generateMasterPin();
  }

  bool get _serverConfigured =>
      ref.read(authControllerProvider).serverUrl != null;

  @override
  void dispose() {
    _serverController.dispose();
    _nameController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    // Si ya hay servidor configurado, saltamos al paso de usuarios.
    final needsServer = auth.serverUrl == null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1030), Color(0xFF1A2568)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStepper(theme, needsServer),
                    const SizedBox(height: 32),
                    Expanded(child: _buildStep(theme, needsServer)),
                    const SizedBox(height: 24),
                    _buildNav(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(ThemeData theme, bool needsServer) {
    final l10n = AppLocalizations.of(context)!;
    final steps = [l10n.server, l10n.users, l10n.home];
    final offset = needsServer ? 0 : 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < steps.length; i++)
          Row(
            children: [
              _StepDot(
                label: steps[i],
                index: i,
                offset: offset,
                active: _step == i,
              ),
              if (i != steps.length - 1) const SizedBox(width: 24),
            ],
          ),
      ],
    );
  }

  Widget _buildStep(ThemeData theme, bool needsServer) {
    if (needsServer && _step == 0) return _serverStep(theme);
    if (_step == 1) return _usersStep(theme);
    return _nameStep(theme);
  }

  Widget _serverStep(ThemeData theme) {
    final auth = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.whichServer,
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _serverController,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: l10n.serverUrl,
            hintText: l10n.serverUrlHint,
            labelStyle: const TextStyle(color: Colors.white70),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.dns_outlined, color: Colors.white70),
          ),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 16),
          Text(
            auth.error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _usersStep(ThemeData theme) {
    final users = ref.watch(publicUsersProvider);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.whoIsFromThisHome,
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.selectHouseholdUsers,
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: users.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _WizardError(
              error: e.toString(),
              onRetry: () => ref.invalidate(publicUsersProvider),
            ),
            data: (list) => list.isEmpty
                ? Center(
                    child: Text(
                      l10n.noPublicUsers,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView(
                    children: [
                      for (final user in list)
                        CheckboxListTile(
                          value: _selected.contains(user.id),
                          onChanged: (checked) {
                            setState(() {
                              if (checked ?? false) {
                                _selected.add(user.id!);
                              } else {
                                _selected.remove(user.id);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          secondary: _Avatar(user: user),
                          title: Text(
                            user.name ?? l10n.username,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _nameStep(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final editing = widget.initialHousehold != null;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.homeName,
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: l10n.homeNameLabel,
              hintText: l10n.homeNameHint,
              labelStyle: const TextStyle(color: Colors.white70),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(
                Icons.home_outlined,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            editing ? l10n.changeHousePin : l10n.chooseHousePin,
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            editing ? l10n.leavePinBlank : l10n.pinProtectsHouse,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: l10n.pin,
              labelStyle: const TextStyle(color: Colors.white70),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinConfirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: l10n.confirmPin,
              labelStyle: const TextStyle(color: Colors.white70),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
            ),
            onSubmitted: (_) => _finish(),
          ),
          if (_pinError != null) ...[
            const SizedBox(height: 8),
            Text(_pinError!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (!editing) ...[
            const SizedBox(height: 16),
            _MasterPinCard(pin: _masterPin ?? ''),
          ],
        ],
      ),
    );
  }

  Widget _buildNav(ThemeData theme) {
    final needsServer = ref.watch(authControllerProvider).serverUrl == null;
    final isFirst = needsServer ? _step == 0 : _step == 0;
    final isLast = _step == 2;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        if (!isFirst)
          OutlinedButton(
            onPressed: _saving ? null : () => setState(() => _step--),
            child: Text(l10n.back),
          ),
        const Spacer(),
        if (isLast)
          FilledButton.icon(
            onPressed: _saving ? null : _finish,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(l10n.save),
          )
        else
          FilledButton(
            onPressed: _saving ? null : _next,
            child: Text(l10n.next),
          ),
      ],
    );
  }

  Future<void> _next() async {
    final needsServer = ref.read(authControllerProvider).serverUrl == null;
    if (needsServer && _step == 0) {
      final url = _serverController.text.trim();
      if (url.isEmpty) return;
      setState(() => _saving = true);
      await ref.read(authControllerProvider.notifier).saveServerUrl(url);
      setState(() => _saving = false);
      if (mounted) setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_selected.isEmpty) return;
      setState(() => _step = 2);
      return;
    }
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final pin = _pinController.text;
    final pinConfirm = _pinConfirmController.text;
    final editing = widget.initialHousehold != null;

    // Si se introduce PIN, debe coincidir y tener al menos 4 dígitos.
    if (pin.isNotEmpty || pinConfirm.isNotEmpty) {
      if (pin.length < 4 || pinConfirm.length < 4) {
        setState(() => _pinError = 'El PIN debe tener al menos 4 dígitos');
        return;
      }
      if (pin != pinConfirm) {
        setState(() => _pinError = 'Los PIN no coinciden');
        return;
      }
    } else if (!editing) {
      setState(() => _pinError = 'Debes elegir un PIN para la casa');
      return;
    }

    setState(() {
      _saving = true;
      _pinError = null;
    });

    try {
      final storage = ref.read(sessionStorageProvider);
      final deviceId = await storage.getOrCreateDeviceId();

      // Mantiene el PIN actual si se gestiona la casa sin cambiarlo.
      String? pinHash = widget.initialHousehold?.pinHash;
      if (pin.isNotEmpty) {
        pinHash = PinHasher.hash(pin, salt: deviceId);
      }

      // El PIN maestro se fija en la creación de la casa.
      final masterPin = widget.initialHousehold != null ? null : _masterPin;

      await saveHousehold(
        ref,
        Household(
          name: name,
          userIds: _selected.toList(),
          pinHash: pinHash,
          masterPinHash: masterPin != null
              ? PinHasher.hash(masterPin, salt: deviceId)
              : widget.initialHousehold?.masterPinHash,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _pinError = 'No se pudo guardar la casa: $e';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);

    // Recalcula el estado de sesión (serverUrl/serverId) para que el redirect
    // permita /users tras guardar la casa. Se hace siempre, tanto en creación
    // como en gestión.
    await ref.read(authControllerProvider.notifier).enterApp();
    if (mounted) context.go('/users');
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.index,
    required this.offset,
    required this.active,
  });

  final String label;
  final int index;
  final int offset;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final effective = index + offset;
    final color = active ? Colors.white : Colors.white38;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.white : Colors.transparent,
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(
              '$effective',
              style: TextStyle(
                color: active ? const Color(0xFF0B1030) : color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});

  final UserDto user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = (user.name ?? '?').substring(0, 1).toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con el PIN maestro de recuperación (se muestra una vez).
class _MasterPinCard extends StatelessWidget {
  const _MasterPinCard({required this.pin});

  final String pin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.key, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'PIN maestro de recuperación',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            pin,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pin));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN copiado al portapapeles')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiar'),
          ),
          const SizedBox(height: 4),
          const Text(
            'Guárdalo aparte: sirve para recuperar el acceso a esta casa '
            'si se olvida el PIN.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WizardError extends StatelessWidget {
  const _WizardError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}
