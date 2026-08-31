import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../games/application/romm_providers.dart';
import '../../../games/domain/romm_config.dart';

/// Panel de configuración del servidor ROMM (juego online).
/// Soporta dos modos: usuario/contraseña y API key (Bearer directo).
class GamesPanel extends ConsumerStatefulWidget {
  const GamesPanel({super.key});

  @override
  ConsumerState<GamesPanel> createState() => _GamesPanelState();
}

class _GamesPanelState extends ConsumerState<GamesPanel> {
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _obscureApiKey = true;
  bool _saving = false;
  String? _message;

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _prefill(RommConfig? config) {
    if (config == null) return;
    _urlController.text = config.serverUrl;
    _apiKeyController.text = config.apiKey ?? '';
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final url = _urlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (url.isEmpty || apiKey.isEmpty) {
      setState(() => _message = apiKey.isEmpty ? l10n.enterApiKey : l10n.gamesConfigRequired);
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final ok = await ref.read(rommAuthProvider.notifier).login(
            serverUrl: url,
            username: 'api',
            password: '',
            apiKey: apiKey,
            useApiKey: true,
          );
      setState(() {
        _message = ok ? l10n.gamesConfigSaved : l10n.gamesConfigFailed;
      });
    } catch (e) {
      setState(() => _message = '${l10n.gamesConfigFailed}\n$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(rommAuthProvider.notifier).logout();
    if (mounted) {
      setState(() {
        _apiKeyController.clear();
        _message = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(rommAuthProvider);
    final config = ref.watch(rommConfigProvider);

    config.whenData(_prefill);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.games,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.rommApiKeyHelp,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),
              if (auth.authenticated && config.value != null) ...[
                _StatusCard(
                  config: config.value!,
                  onLogout: _logout,
                ),
                const SizedBox(height: 24),
              ],
              _configCard(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _configCard(AppLocalizations l10n) {
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
          Text(
            l10n.gamesConfigTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: l10n.gamesServerUrl,
              hintText: 'http://192.168.1.10:3000',
              labelStyle: const TextStyle(color: Colors.white54),
              hintStyle: const TextStyle(color: Colors.white24),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureApiKey,
            decoration: InputDecoration(
              labelText: l10n.apiKeyBearerLabel,
              hintText: 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...',
              labelStyle: const TextStyle(color: Colors.white54),
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureApiKey = !_obscureApiKey),
                icon: Icon(
                  _obscureApiKey ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white54,
                  size: 20,
                ),
              ),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.rommApiKeyHelp,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (_message != null) ...[
            SelectableText(
              _message!,
              style: TextStyle(
                color: _message == l10n.gamesConfigSaved
                    ? Colors.greenAccent
                    : Colors.red.shade300,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_done_outlined, size: 18),
              label: Text(l10n.gamesConfigSave),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.config, required this.onLogout});

  final RommConfig config;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isApiKey = config.isApiKeyMode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isApiKey
                      ? '${l10n.gamesConnected} · API Key'
                      : '${l10n.gamesConnected} · ${config.username}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
            label: Text(
              l10n.gamesDisconnect,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
