import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/security/pin_hasher.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/household_provider.dart';
import '../domain/household.dart';

/// Asistente de configuración de la casa: conecta el servidor, permite agregar
/// usuarios validando usuario+contraseña (sin exponer usuarios públicos) y
/// le da nombre a la casa.
///
/// También se usa para gestionar una casa ya existente: si [initialHousehold]
/// viene informado, los miembros ya agregados aparecen listados.
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
  late List<HouseholdMember> _members;
  String? _masterPin;
  String? _pinError;
  String? _usersError;

  bool _stepCorrected = false;

  @override
  void initState() {
    super.initState();
    // Valor inicial provisorio; se corrige en build cuando la sesión ya cargó.
    _step = _serverConfigured ? 1 : 0;
    _members = List<HouseholdMember>.from(
      widget.initialHousehold?.members ?? const <HouseholdMember>[],
    );
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
    final needsServer = auth.serverUrl == null;

    // Corrige _step si se inicializó antes de que la sesión cargara (auth unknown).
    // Sin esto, al editar desde Ajustes (ya autenticado) el wizard arrancaba en
    // paso 0 y mostraba _nameStep en lugar de _usersStep, o quedaba en serverStep.
    if (!_stepCorrected && auth.status != AuthStatus.unknown) {
      _stepCorrected = true;
      if (!needsServer && _step == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _step = 1);
        });
      }
    }

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
    if (needsServer) {
      if (_step == 0) return _serverStep(theme);
      if (_step == 1) return _usersStep(theme);
      return _nameStep(theme);
    } else {
      // Sin servidor por configurar (edición desde Ajustes): paso 1 = usuarios, 2 = nombre
      // Maneja el caso donde _step aún es 0 por initState async.
      if (_step == 0 || _step == 1) return _usersStep(theme);
      return _nameStep(theme);
    }
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
          child: _members.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_outlined,
                          color: Colors.white38, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noHouseholdMembers,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _members.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ListTile(
                        leading: _MemberAvatar(member: member),
                        title: Text(
                          member.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          tooltip: l10n.removeUser,
                          onPressed: () => _removeMember(member),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_usersError != null) ...[
          const SizedBox(height: 12),
          Text(
            _usersError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _showAddUserDialog,
          icon: const Icon(Icons.person_add_outlined),
          label: Text(l10n.addUser),
        ),
      ],
    );
  }

  Future<void> _showAddUserDialog() async {
    final result = await showDialog<HouseholdMember>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddUserDialog(
        existingIds: _members.map((m) => m.id).toSet(),
      ),
    );
    if (result != null) {
      setState(() {
        _members.add(result);
        _usersError = null;
      });
    }
  }

  Future<void> _removeMember(HouseholdMember member) async {
    setState(() => _members.removeWhere((m) => m.id == member.id));
    // Limpia token persistido del usuario para no dejar credenciales huérfanas.
    try {
      await ref.read(sessionStorageProvider).deleteUserToken(member.id);
    } catch (_) {}
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
    // needsServer: pasos 0(server)->1(users)->2(home); sin server: 1(users)->2(home)
    final isFirst = needsServer ? _step == 0 : _step == 1 || _step == 0;
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
                    child: AppLoader(size: 18),
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
    // Avanza de usuarios → nombre. Maneja _step 0/1 cuando no hay server por el init async.
    if (_step == 1 || (!needsServer && _step == 0)) {
      if (_members.isEmpty) {
        setState(() => _usersError = AppLocalizations.of(context)!.addAtLeastOneUser);
        return;
      }
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

      String? pinHash = widget.initialHousehold?.pinHash;
      if (pin.isNotEmpty) {
        pinHash = PinHasher.hash(pin, salt: deviceId);
      }

      final masterPin = widget.initialHousehold != null ? null : _masterPin;

      await saveHousehold(
        ref,
        Household(
          name: name,
          members: List<HouseholdMember>.from(_members),
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

    final wasAuthenticated =
        ref.read(authControllerProvider).status == AuthStatus.authenticated;
    final isEditing = widget.initialHousehold != null;

    // Si se gestiona la casa estando ya autenticado (desde Ajustes),
    // no se hace enterApp (evita logout) y se vuelve a la pantalla anterior
    // para no sacar al usuario de Ajustes/Preferencias.
    if (isEditing && wasAuthenticated) {
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/settings');
        }
      }
      return;
    }

    await ref.read(authControllerProvider.notifier).enterApp();
    if (mounted) context.go('/users');
  }
}

class _AddUserDialog extends ConsumerStatefulWidget {
  const _AddUserDialog({required this.existingIds});

  final Set<String> existingIds;

  @override
  ConsumerState<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<_AddUserDialog> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _userController.text.trim();
    final password = _passController.text;
    if (username.isEmpty) {
      setState(() => _error = 'Ingresa el usuario');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final authController = ref.read(authControllerProvider);
    final serverUrl = authController.serverUrl;
    if (serverUrl == null) {
      setState(() {
        _loading = false;
        _error = 'Sin servidor configurado';
      });
      return;
    }

    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.authenticate(
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      final user = result.user;
      final token = result.accessToken;
      if (user == null || user.id == null || token == null) {
        throw DioException(
          requestOptions: RequestOptions(path: ''),
          error: 'Respuesta inválida del servidor',
        );
      }
      if (widget.existingIds.contains(user.id)) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = AppLocalizations.of(context)!.userAlreadyAdded;
          });
        }
        return;
      }

      // Persiste el token para que el perfil aparezca como desbloqueado.
      // Si falla el almacenamiento seguro (p. ej. Windows sin plugin), no
      // bloqueamos el agregado: el usuario podrá re-autenticar al entrar.
      try {
        final storage = ref.read(sessionStorageProvider);
        await storage.saveUserToken(
          user.id!,
          CachedUserToken(
            token: token,
            expiresAt: DateTime.now().add(
              const Duration(days: AppConstants.tokenValidityDays),
            ),
          ),
        );
      } catch (e) {
        // Log pero no falla el flujo; el token se regenerará al seleccionar perfil.
        // ignore: avoid_print
        print('Warning: no se pudo guardar token para ${user.id}: $e');
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        HouseholdMember(
          id: user.id!,
          name: user.name ?? username,
          primaryImageTag: user.primaryImageTag,
        ),
      );
    } on DioException catch (e, st) {
      // Log completo para diagnóstico: status, data, error, message
      // ignore: avoid_print
      print('authenticate DioException: status=${e.response?.statusCode} '
          'data=${e.response?.data} error=${e.error} message=${e.message} '
          'type=${e.type} stack=$st');
      final msg = _dioMessage(e);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = msg;
        });
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('authenticate error: $e stack=$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  String _dioMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 400) {
      return AppLocalizations.of(context)!.invalidCredentials;
    }
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map && data.isNotEmpty) {
      final msg = data['error'] ?? data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      return data.toString();
    }
    if (e.error != null) {
      final errStr = e.error.toString();
      if (errStr.isNotEmpty && errStr != 'null') return errStr;
    }
    final msg = e.message;
    // Dio a veces pone "Error processing request" como message genérico con
    // response.data vacío; en ese caso mostramos status + data si existe
    if (msg != null && msg.isNotEmpty) {
      if (msg == 'Error processing request' && status != null) {
        return '$status $msg';
      }
      return msg;
    }
    return '${status ?? ''} Error de conexión'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addUserTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _userController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.username,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            onSubmitted: (_) => _loading ? null : _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: l10n.password,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _loading ? null : _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: AppLoader(size: 18),
                )
              : Text(l10n.add),
        ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member});

  final HouseholdMember member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = (member.name.isNotEmpty ? member.name : '?')
        .substring(0, 1)
        .toUpperCase();
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
