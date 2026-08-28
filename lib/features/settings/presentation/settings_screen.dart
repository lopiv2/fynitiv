import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/security/pin_hasher.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/widgets/scale_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../household/application/household_provider.dart';
import '../../household/domain/household.dart';
import 'widgets/appearance_panel.dart';
import 'widgets/games_panel.dart';
import 'widgets/sounds_panel.dart';

enum SettingsSection { preferences, appearance, home, games, sounds, account, about }

class _SettingsSectionNotifier extends Notifier<SettingsSection> {
  @override
  SettingsSection build() => SettingsSection.preferences;

  void set(SettingsSection value) => state = value;
}

final _settingsSectionProvider =
    NotifierProvider<_SettingsSectionNotifier, SettingsSection>(
  _SettingsSectionNotifier.new,
);

/// Pantalla de ajustes de la app. Adaptativa: menú lateral en pantallas anchas
/// (TV/escritorio) y pestañas superiores en móvil.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  SettingsSection get _section => ref.watch(_settingsSectionProvider);
  set _section(SettingsSection v) =>
      ref.read(_settingsSectionProvider.notifier).set(v);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final useMenu = width >= 700;

    final sections = <(SettingsSection, IconData, String)>[
      (SettingsSection.preferences, Icons.tune, l10n.preferences),
      (SettingsSection.appearance, Icons.palette_outlined, l10n.appearance),
      (SettingsSection.home, Icons.home_outlined, l10n.currentHome),
      (SettingsSection.games, Icons.sports_esports, l10n.games),
      (SettingsSection.sounds, Icons.volume_up_outlined, l10n.sounds),
      (SettingsSection.account, Icons.person_outline, l10n.account),
      (SettingsSection.about, Icons.info_outline, l10n.about),
    ];

    return Scaffold(
      body: DashboardBackground(
        child: useMenu
            ? Row(
                children: [
                  _buildMenu(sections),
                  const VerticalDivider(
                    width: 1,
                    color: Color(0xFF1A2568),
                  ),
                  Expanded(child: _buildPanel()),
                ],
              )
            : Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    onTap: (i) => _section = sections[i].$1,
                    tabs: [
                      for (final s in sections)
                        Tab(
                          icon: Icon(s.$2),
                          text: s.$3,
                        ),
                    ],
                  ),
                  Expanded(child: _buildPanel()),
                ],
              ),
      ),
    );
  }

  Widget _buildMenu(List<(SettingsSection, IconData, String)> sections) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          for (final s in sections)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: ScaleButton(
                selected: _section == s.$1,
                selectedScale: 1.04,
                borderRadius: BorderRadius.circular(10),
                onPressed: () => _section = s.$1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _section == s.$1
                        ? const Color(0xFF1A2568)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        s.$2,
                        color: _section == s.$1
                            ? Colors.white
                            : Colors.white60,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        s.$3,
                        style: TextStyle(
                          color: _section == s.$1
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 15,
                          fontWeight: _section == s.$1
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPanel() {
    switch (_section) {
      case SettingsSection.preferences:
        return _PreferencesPanel();
      case SettingsSection.appearance:
        return const AppearancePanel();
      case SettingsSection.home:
        return _HomePanel();
      case SettingsSection.games:
        return const GamesPanel();
      case SettingsSection.sounds:
        return const SoundsPanel();
      case SettingsSection.account:
        return _AccountPanel();
      case SettingsSection.about:
        return _AboutPanel();
    }
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return _SettingsPanel(
      title: l10n.preferences,
      children: [
        _buildLanguage(context, l10n),
        const SizedBox(height: 24),
        _buildTheme(context, ref, l10n),
      ],
    );
  }

  Widget _buildLanguage(BuildContext context, AppLocalizations l10n) {
    return _SettingsCard(
      title: l10n.language,
      child: const Align(
        alignment: Alignment.centerLeft,
        child: LanguageSelector(),
      ),
    );
  }

  Widget _buildTheme(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    final mode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final setMode = ref.read(themeModeProvider.notifier).setThemeMode;
    final options = <(ThemeMode, String)>[
      (ThemeMode.system, l10n.themeSystem),
      (ThemeMode.light, l10n.themeLight),
      (ThemeMode.dark, l10n.themeDark),
    ];
    return _SettingsCard(
      title: l10n.theme,
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o.$2),
                selected: mode == o.$1,
                onSelected: (_) => setMode(o.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomePanel extends ConsumerStatefulWidget {
  @override
  ConsumerState<_HomePanel> createState() => _HomePanelState();
}

class _HomePanelState extends ConsumerState<_HomePanel> {
  bool _editing = false;
  bool _saving = false;
  String? _pinError;
  String? _saveError;
  String? _usersError;
  late TextEditingController _nameController;
  late TextEditingController _pinController;
  late TextEditingController _pinConfirmController;
  late List<HouseholdMember> _members;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _pinController = TextEditingController();
    _pinConfirmController = TextEditingController();
    _members = [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    super.dispose();
  }

  void _enterEdit(Household household) {
    _nameController.text = household.name;
    _pinController.clear();
    _pinConfirmController.clear();
    _members = List<HouseholdMember>.from(household.members);
    setState(() {
      _editing = true;
      _pinError = null;
      _saveError = null;
      _usersError = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _pinError = null;
      _saveError = null;
      _usersError = null;
    });
  }

  Future<void> _addUser() async {
    final existingIds = _members.map((m) => m.id).toSet();
    final result = await showDialog<HouseholdMember>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddMemberDialog(existingIds: existingIds),
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
    try {
      await ref.read(sessionStorageProvider).deleteUserToken(member.id);
    } catch (_) {}
  }

  Future<void> _save(Household original) async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _saveError = 'El nombre no puede estar vacío');
      return;
    }
    if (_members.isEmpty) {
      setState(() => _usersError = l10n.addAtLeastOneUser);
      return;
    }
    final pin = _pinController.text;
    final pinConfirm = _pinConfirmController.text;
    if (pin.isNotEmpty || pinConfirm.isNotEmpty) {
      if (pin.length < 4 || pinConfirm.length < 4) {
        setState(() => _pinError = 'El PIN debe tener al menos 4 dígitos');
        return;
      }
      if (pin != pinConfirm) {
        setState(() => _pinError = 'Los PIN no coinciden');
        return;
      }
    }
    setState(() {
      _saving = true;
      _pinError = null;
      _saveError = null;
    });
    try {
      final storage = ref.read(sessionStorageProvider);
      final deviceId = await storage.getOrCreateDeviceId();
      String? pinHash = original.pinHash;
      if (pin.isNotEmpty) pinHash = PinHasher.hash(pin, salt: deviceId);
      await saveHousehold(
        ref,
        Household(
          name: name,
          members: List<HouseholdMember>.from(_members),
          serverId: original.serverId,
          pinHash: pinHash,
          masterPinHash: original.masterPinHash,
        ),
      );
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.save)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'No se pudo guardar la casa: $e';
        });
      }
    }
  }

  Future<bool> _requirePin() async {
    final controller = ref.read(authControllerProvider.notifier);
    if (!await controller.houseHasPin()) return true;
    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    for (var attempts = 0; attempts < 3; attempts++) {
      final entered = await _promptPin();
      if (entered == null) return false;
      if (await controller.verifyHousePin(entered)) return true;
      if (!mounted) return false;
      messenger.showSnackBar(SnackBar(content: Text(l10n.wrongPin)));
    }
    return false;
  }

  Future<String?> _promptPin() {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.watch(householdProvider);

    if (household == null) {
      return _SettingsPanel(
        title: l10n.currentHome,
        children: [
          Text(l10n.noHouseholdMembers,
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          ScaleButton(
            selectedScale: 1.03,
            borderRadius: BorderRadius.circular(12),
            onPressed: () => context.go('/setup'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF1A2568),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_home_outlined, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(l10n.manageHome,
                      style: const TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final name = household.name;
    final members = household.members;

    if (!_editing) {
      return _SettingsPanel(
        title: l10n.currentHome,
        children: [
          _SettingsCard(title: l10n.currentHome, subtitle: name),
          if (members.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SettingsCard(
              title: l10n.users,
              subtitle: '${members.length} ${members.length == 1 ? 'usuario' : 'usuarios'}',
              child: Column(
                children: [
                  for (final m in members)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 18, child: Text(m.name.substring(0, 1).toUpperCase())),
                          const SizedBox(width: 12),
                          Expanded(child: Text(m.name, style: const TextStyle(color: Colors.white70))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ScaleButton(
            selectedScale: 1.03,
            borderRadius: BorderRadius.circular(12),
            onPressed: () async {
              if (!await _requirePin()) return;
              if (!mounted) return;
              _enterEdit(household);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF1A2568),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(l10n.manageHome, style: const TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.selectHouseholdUsers, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      );
    }

    // Modo edición inline (sin wizard, sin bucle)
    return _SettingsPanel(
      title: l10n.manageHome,
      children: [
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: l10n.homeNameLabel,
            labelStyle: const TextStyle(color: Colors.white70),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.home_outlined, color: Colors.white70),
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.users, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(l10n.noHouseholdMembers, style: const TextStyle(color: Colors.white54)),
          )
        else
          for (final m in _members)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: ListTile(
                leading: CircleAvatar(child: Text(m.name.substring(0, 1).toUpperCase())),
                title: Text(m.name, style: const TextStyle(color: Colors.white)),
                trailing: IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => _removeMember(m)),
              ),
            ),
        if (_usersError != null) ...[
          const SizedBox(height: 4),
          Text(_usersError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _addUser, icon: const Icon(Icons.person_add_outlined), label: Text(l10n.addUser)),
        const SizedBox(height: 16),
        Text(l10n.changeHousePin, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(l10n.leavePinBlank, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 12),
        TextField(
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: l10n.pin, labelStyle: const TextStyle(color: Colors.white70), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pinConfirmController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: l10n.confirmPin, labelStyle: const TextStyle(color: Colors.white70), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70)),
        ),
        if (_pinError != null) ...[
          const SizedBox(height: 8),
          Text(_pinError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: 8),
          Text(_saveError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(onPressed: _saving ? null : _cancelEdit, child: Text(l10n.cancel)),
            const Spacer(),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(household),
              icon: _saving ? const SizedBox(width: 16, height: 16, child: AppLoader(size: 16)) : const Icon(Icons.check),
              label: Text(l10n.save),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddMemberDialog extends ConsumerStatefulWidget {
  const _AddMemberDialog({required this.existingIds});
  final Set<String> existingIds;
  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
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
    final serverUrl = ref.read(authControllerProvider).serverUrl;
    if (serverUrl == null) {
      setState(() {
        _loading = false;
        _error = 'Sin servidor configurado';
      });
      return;
    }
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.authenticate(serverUrl: serverUrl, username: username, password: password);
      final user = result.user;
      final token = result.accessToken;
      if (user == null || user.id == null || token == null) {
        throw DioException(requestOptions: RequestOptions(path: ''), error: 'Respuesta inválida del servidor');
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
      try {
        final storage = ref.read(sessionStorageProvider);
        await storage.saveUserToken(user.id!, CachedUserToken(token: token, expiresAt: DateTime.now().add(const Duration(days: AppConstants.tokenValidityDays))));
      } catch (e) {
        debugPrint('Warning: no se pudo guardar token para ${user.id}: $e');
      }
      if (!mounted) return;
      Navigator.of(context).pop(HouseholdMember(id: user.id!, name: user.name ?? username, primaryImageTag: user.primaryImageTag));
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } on DioException catch (e) {
      debugPrint('authenticate DioException: status=${e.response?.statusCode} data=${e.response?.data} error=${e.error} message=${e.message}');
      final msg = _dioMessage(e);
      if (mounted) {
        setState(() {
        _loading = false;
        _error = msg;
      });
      }
    } catch (e, st) {
      debugPrint('authenticate error: $e stack=$st');
      if (mounted) {
        setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('FormatException: ', '');
      });
      }
    }
  }

  String _dioMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 400) {
      return AppLocalizations.of(context)!.invalidCredentials;
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.error.toString().contains('SocketException') ||
        e.error.toString().contains('Failed host lookup') ||
        (e.message?.contains('Failed host lookup') ?? false)) {
      final host = e.requestOptions.uri.host;
      final hint = host.isNotEmpty && host != 'https' && host != 'http'
          ? ' ($host)'
          : '';
      return 'No se pudo conectar al servidor$hint. Revisa la URL (ej. https://jellyfin.ejemplo.com) y tu conexión.';
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
      if (errStr.isNotEmpty && errStr != 'null') {
        if (errStr.contains('SocketException') ||
            errStr.contains('Failed host lookup')) {
          return 'No se pudo conectar al servidor. Revisa la URL y tu conexión.';
        }
        return errStr;
      }
    }
    final msg = e.message;
    if (msg != null && msg.isNotEmpty) {
      if (msg.contains('Failed host lookup')) {
        return 'No se pudo conectar al servidor. Revisa la URL y tu conexión.';
      }
      if (msg == 'Error processing request' && status != null) return '$status $msg';
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
          TextField(controller: _userController, autofocus: true, decoration: InputDecoration(labelText: l10n.username, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.person_outline)), onSubmitted: (_) => _loading ? null : _submit()),
          const SizedBox(height: 12),
          TextField(controller: _passController, obscureText: _obscure, decoration: InputDecoration(labelText: l10n.password, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure))), onSubmitted: (_) => _loading ? null : _submit()),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
        ],
      ),
      actions: [
        TextButton(onPressed: _loading ? null : () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 18, height: 18, child: AppLoader(size: 18)) : Text(l10n.add)),
      ],
    );
  }
}

class _AccountPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final name = auth.user?.name ?? auth.userId ?? '—';
    return _SettingsPanel(
      title: l10n.account,
      children: [
        _SettingsCard(
          title: l10n.currentUser,
          subtitle: name,
          leading: CircleAvatar(
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ScaleButton(
          selectedScale: 1.03,
          borderRadius: BorderRadius.circular(12),
          onPressed: () => controller.logout(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.red.withValues(alpha: 0.15),
            ),
            child: Row(
              children: [
                Icon(Icons.logout, color: Colors.red.shade300),
                const SizedBox(width: 12),
                Text(
                  l10n.signOut,
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SettingsPanel(
      title: l10n.about,
      children: [
        const Icon(Icons.play_circle_fill, color: Colors.white, size: 56),
        const SizedBox(height: 12),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${l10n.version} ${AppConstants.appVersion}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.aboutDescription,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    this.subtitle,
    this.child,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? child;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null || title.isNotEmpty)
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          if (child != null) ...[
            if (title.isNotEmpty || leading != null)
              const SizedBox(height: 12),
            child!,
          ],
        ],
      ),
    );
  }
}
