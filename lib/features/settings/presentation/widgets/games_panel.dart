import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_loader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../games/application/bios_sync_controller.dart';
import '../../../games/application/romm_providers.dart';
import '../../../games/application/romm_sync_controller.dart';
import '../../../games/data/romm_repository.dart';
import '../../../games/domain/romm_config.dart';

/// Panel de configuración del servidor ROMM (juego online).
/// El emparejamiento es por QR (device authorization flow de RomM).
class GamesPanel extends ConsumerStatefulWidget {
  const GamesPanel({super.key});

  @override
  ConsumerState<GamesPanel> createState() => _GamesPanelState();
}

class _GamesPanelState extends ConsumerState<GamesPanel> {
  final _urlController = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _prefill(RommConfig? config) {
    if (config == null) return;
    _urlController.text = config.serverUrl;
  }

  Future<void> _pairWithQr() async {
    final l10n = AppLocalizations.of(context)!;
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _message = l10n.gamesConfigRequired);
      return;
    }
    setState(() => _message = null);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RommQrPairingDialog(serverUrl: url),
    );
    if (ok == true && mounted) {
      setState(() => _message = l10n.rommPairSuccess);
      unawaited(EasyLoading.showSuccess(l10n.rommPairSuccess));
    }
  }

  Future<void> _logout() async {
    await ref.read(rommAuthProvider.notifier).logout();
    if (mounted) {
      setState(() => _message = null);
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
                l10n.rommPairHelp,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 24),
              if (auth.authenticated && config.value != null) ...[
                _StatusCard(
                  config: config.value!,
                  onLogout: _logout,
                ),
                const SizedBox(height: 16),
                const _BiosSyncCard(),
                const SizedBox(height: 16),
                const _SavesSyncCard(),
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
          const SizedBox(height: 20),
          Text(
            l10n.rommPairTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.rommPairHelp,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 10),
          if (_message != null) ...[
            Text(
              _message!,
              style: TextStyle(
                color: _message == l10n.rommPairSuccess
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
              onPressed: _pairWithQr,
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: Text(l10n.rommPairButton),
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
                  '${l10n.gamesConnected} · ${l10n.rommPairTitle}',
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

/// Tarjeta de sincronización de BIOS/firmware (RomM → cliente).
class _BiosSyncCard extends ConsumerWidget {
  const _BiosSyncCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final s = ref.watch(biosSyncProvider);
    final subtitle = s.running
        ? l10n.rommBiosSyncRunning('${s.done}', '${s.total}')
        : l10n.rommBiosSyncHelp;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.memory, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.rommBiosSyncTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (s.running)
            const Padding(
              padding: EdgeInsets.all(8),
              child: AppLoader(size: 22),
            )
          else
            FilledButton.tonalIcon(
              onPressed: () => _run(ref, l10n),
              icon: const Icon(Icons.download, size: 18),
              label: Text(l10n.rommBiosSyncButton),
            ),
        ],
      ),
    );
  }

  Future<void> _run(WidgetRef ref, AppLocalizations l10n) async {
    final result = await ref.read(biosSyncProvider.notifier).sync();
    if (result == null) {
      unawaited(EasyLoading.showError(l10n.rommBiosSyncLogin));
      return;
    }
    if (result.downloaded > 0) {
      unawaited(EasyLoading.showSuccess(l10n.rommBiosSyncDone(result.downloaded)));
    } else if (result.failed > 0) {
      unawaited(EasyLoading.showError(l10n.rommBiosSyncError));
    } else {
      unawaited(EasyLoading.showInfo(l10n.rommBiosSyncUpToDate));
    }
  }
}

/// Tarjeta de sincronización bidireccional de partidas/estados.
class _SavesSyncCard extends ConsumerWidget {
  const _SavesSyncCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final s = ref.watch(rommSyncProvider);
    final subtitle = s.running
        ? l10n.rommSyncRunning('${s.done}', '${s.total}')
        : l10n.rommSyncHelp;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.save_alt, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.rommSyncTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (s.running)
            const Padding(
              padding: EdgeInsets.all(8),
              child: AppLoader(size: 22),
            )
          else
            FilledButton.tonalIcon(
              onPressed: () => _run(ref, l10n),
              icon: const Icon(Icons.sync, size: 18),
              label: Text(l10n.rommSyncButton),
            ),
        ],
      ),
    );
  }

  Future<void> _run(WidgetRef ref, AppLocalizations l10n) async {
    final result = await ref.read(rommSyncProvider.notifier).sync();
    if (result == null) {
      unawaited(EasyLoading.showError(l10n.rommSyncLogin));
      return;
    }
    final changed = result.uploaded + result.downloaded;
    if (result.failed > 0 && changed == 0 && result.conflicts == 0) {
      unawaited(EasyLoading.showError(l10n.rommSyncError));
    } else if (changed == 0 && result.conflicts == 0) {
      unawaited(EasyLoading.showInfo(l10n.rommSyncUpToDate));
    } else {
      unawaited(
        EasyLoading.showSuccess(
          l10n.rommSyncDone(result.uploaded, result.downloaded),
        ),
      );
    }
  }
}

/// Diálogo de emparejamiento por QR (device authorization flow de RomM).
class _RommQrPairingDialog extends ConsumerStatefulWidget {
  const _RommQrPairingDialog({required this.serverUrl});

  final String serverUrl;

  @override
  ConsumerState<_RommQrPairingDialog> createState() =>
      _RommQrPairingDialogState();
}

class _RommQrPairingDialogState extends ConsumerState<_RommQrPairingDialog> {
  RommDeviceAuthStart? _start;
  Object? _error;
  RommPairOutcome? _outcome;
  Timer? _ticker;
  int _secondsLeft = 0;

  String get _qrData {
    final base = widget.serverUrl.replaceAll(RegExp(r'/$'), '');
    return '$base${_start!.verificationPathComplete}';
  }

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_outcome != RommPairOutcome.approved) {
      ref.read(rommAuthProvider.notifier).cancelQrPairing();
    }
    super.dispose();
  }

  Future<void> _begin() async {
    try {
      final start = await ref
          .read(rommAuthProvider.notifier)
          .beginQrPairing(serverUrl: widget.serverUrl, deviceName: 'fynitiv');
      if (!mounted) return;
      setState(() {
        _start = start;
        _secondsLeft = start.expiresIn;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _secondsLeft = _secondsLeft - 1);
      });
      final outcome = await ref
          .read(rommAuthProvider.notifier)
          .pollQrPairing(start);
      _ticker?.cancel();
      if (!mounted) return;
      if (outcome == RommPairOutcome.approved) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _outcome = outcome);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _cancel() {
    ref.read(rommAuthProvider.notifier).cancelQrPairing();
    Navigator.of(context).pop(false);
  }

  Future<void> _openBrowser() async {
    final start = _start;
    if (start == null) return;
    final l10n = AppLocalizations.of(context)!;
    final ok = await launchUrl(
      Uri.parse(_qrData),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      unawaited(EasyLoading.showError(l10n.rommPairFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF0B1220),
      title: Text(
        l10n.rommPairTitle,
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      content: SizedBox(width: 320, child: _content(l10n)),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: Text(
            _outcome == null ? l10n.rommQrCancel : l10n.gamesDisconnect,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _content(AppLocalizations l10n) {
    if (_error != null) {
      return Text(
        '${l10n.rommPairFailed}\n$_error',
        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
      );
    }
    final start = _start;
    if (start == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final outcome = _outcome;
    if (outcome != null) {
      final msg = switch (outcome) {
        RommPairOutcome.denied => l10n.rommQrDenied,
        RommPairOutcome.expired => l10n.rommQrExpired,
        RommPairOutcome.cancelled => l10n.rommQrCancel,
        RommPairOutcome.approved => l10n.rommPairSuccess,
      };
      return Text(
        msg,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: QrImageView(
            data: _qrData,
            version: QrVersions.auto,
            size: 220,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${l10n.rommPairCodeLabel}: ${start.userCode}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.rommQrScanHint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${l10n.rommQrWaiting}  ${_secondsLeft}s',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _openBrowser,
          icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white70),
          label: Text(
            l10n.rommQrOpenBrowser,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

