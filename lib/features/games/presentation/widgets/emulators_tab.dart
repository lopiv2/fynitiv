import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../core/widgets/app_hover_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/romm_providers.dart';
import '../../data/emulator_catalog.dart';
import '../../data/platform_machine_asset_resolver.dart';
import '../../domain/emulator_profile.dart';
import '../../domain/romm_platform.dart';

/// Pestaña "Emuladores": por plataforma, emulador recomendado, descarga,
/// asociación y estado de instalación.
class EmulatorsTab extends ConsumerWidget {
  const EmulatorsTab({super.key, required this.platforms, this.headers});

  final List<RommPlatform> platforms;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(emulatorCatalogProvider);
    return catalog.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('$e', style: const TextStyle(color: Colors.white54)),
      ),
      data: (cat) {
        final isWindows = !kIsWeb && Platform.isWindows;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(
                  l10n.emulatorsTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 460,
                  mainAxisExtent: isWindows ? 250 : 196,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: platforms.length,
                itemBuilder: (_, i) =>
                    _PlatformEmulatorCard(catalog: cat, platform: platforms[i]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlatformEmulatorCard extends ConsumerStatefulWidget {
  const _PlatformEmulatorCard({required this.catalog, required this.platform});

  final EmulatorCatalog catalog;
  final RommPlatform platform;

  @override
  ConsumerState<_PlatformEmulatorCard> createState() =>
      _PlatformEmulatorCardState();
}

class _PlatformEmulatorCardState extends ConsumerState<_PlatformEmulatorCard> {
  String? _selectedId;
  bool _installed = false;
  bool _configured = false;
  bool _loaded = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  PlatformEmulators? get _entry =>
      widget.catalog.forPlatform(widget.platform.slug);

  EmulatorOsSpec? _specFor(Emulator e) {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return e.android ?? e.windows;
    if (Platform.isWindows) return e.windows;
    return null;
  }

  Emulator? get _selected => widget.catalog.emulatorById(_selectedId);

  EmulatorOsSpec? get _selectedSpec =>
      _selected == null ? null : _specFor(_selected!);

  bool get _isCore => _selectedSpec?.retroarchCore != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = ref.read(emulatorPreferencesProvider);
    final entry = _entry;
    final assoc = await prefs.association(widget.platform.slug);
    final recommended = _isAndroid
        ? entry?.recommendedAndroid
        : entry?.recommendedWindows;
    _selectedId = widget.catalog.emulatorById(assoc) != null
        ? assoc
        : (recommended ??
              (entry != null && entry.emulators.isNotEmpty
                  ? entry.emulators.first
                  : null));
    await _checkInstalled();
    await _refreshConfigured();
    if (mounted) setState(() => _loaded = true);
  }

  /// Marca si el emulador seleccionado está listo (instalado en Android,
  /// `.exe` guardado en Windows).
  Future<void> _refreshConfigured() async {
    var configured = false;
    final id = _selectedId;
    if (id != null) {
      if (_isAndroid) {
        configured = _installed;
      } else if (!kIsWeb && Platform.isWindows) {
        final targetId = _isCore ? 'retroarch' : id;
        final exe =
            await ref.read(emulatorPreferencesProvider).windowsExe(targetId);
        configured = exe != null && exe.isNotEmpty;
      }
    }
    if (mounted) setState(() => _configured = configured);
  }

  Future<void> _checkInstalled() async {
    if (!_isAndroid) return;
    final pkg = _isCore ? 'com.retroarch' : _selectedSpec?.package;
    if (pkg == null || pkg.isEmpty) {
      _installed = false;
      return;
    }
    try {
      final result = await InstalledApps.isAppInstalled(pkg);
      _installed = result ?? false;
    } catch (_) {
      _installed = false;
    }
  }

  Future<void> _select(String? id) async {
    if (id == null) return;
    setState(() => _selectedId = id);
    await ref
        .read(emulatorPreferencesProvider)
        .setAssociation(widget.platform.slug, id);
    await _checkInstalled();
    await _refreshConfigured();
    ref.invalidate(platformPlayReadinessProvider);
    if (mounted) setState(() {});
  }

  Future<void> _download() async {
    final l10n = AppLocalizations.of(context)!;
    final emulator = _selected;
    final spec = emulator == null ? null : _specFor(emulator);
    final url = (spec?.retroarchCore != null)
        ? widget.catalog.emulatorById('retroarch')?.windows?.downloadUrl
        : spec?.downloadUrl;
    if (url == null || url.isEmpty) {
      unawaited(EasyLoading.showError(l10n.emulatorsNoDownload));
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _pickWindowsExe() async {
    final emulator = _selected;
    if (emulator == null) return;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['exe'],
      dialogTitle: emulator.name,
    );
    final path = picked?.path;
    if (path == null) return;
    await ref
        .read(emulatorPreferencesProvider)
        .setWindowsExe(_isCore ? 'retroarch' : emulator.id, path);
    await _refreshConfigured();
    ref.invalidate(platformPlayReadinessProvider);
    if (mounted) {
      unawaited(
        EasyLoading.showSuccess(
          AppLocalizations.of(context)!.emulatorsPathSaved,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entry = _entry;
    final machine = PlatformMachineAssetResolver.resolve(widget.platform);
    final emulators = (entry?.emulators ?? const <String>[])
        .map(widget.catalog.emulatorById)
        .whereType<Emulator>()
        .toList();
    final showWindowsPath = !kIsWeb && Platform.isWindows;
    final skin = ref.watch(skinControllerProvider).value;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final highlightText = skin?.textPrimary ?? Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (machine != null) ...[
                Image.asset(
                  machine,
                  width: 84,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  widget.platform.displayName.isEmpty
                      ? widget.platform.name
                      : widget.platform.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isAndroid && _loaded)
                _InstalledBadge(
                  installed: _installed,
                  label: _installed
                      ? l10n.emulatorsInstalled
                      : l10n.emulatorsNotInstalled,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (emulators.isEmpty)
            Text(
              l10n.emulatorsNone,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF131A24),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: [
                      for (final e in emulators)
                        DropdownMenuItem(value: e.id, child: Text(e.name)),
                    ],
                    onChanged: _loaded ? _select : null,
                  ),
                ),
                const SizedBox(width: 12),
                AppHoverButton.filled(
                  label: l10n.emulatorsDownload,
                  icon: Icons.download_outlined,
                  onPressed: _download,
                  textColor: highlightText,
                  config: AppHoverConfig(
                    highlightNormal: accent,
                    highlightHovered:
                        Color.lerp(accent, Colors.white, 0.18) ?? accent,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    scale: 1.05,
                  ),
                ),
              ],
            ),
            if (showWindowsPath) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppHoverButton.outlined(
                    label: l10n.emulatorsSelectExe,
                    icon: Icons.folder_open,
                    onPressed: _pickWindowsExe,
                    textColor: highlightText,
                    borderColor: accent,
                    config: AppHoverConfig(
                      highlightNormal: Colors.transparent,
                      highlightHovered: accent.withValues(alpha: 0.16),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                      scale: 1.05,
                    ),
                  ),
                  if (_configured) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: l10n.emulatorsConfigured,
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF2ED9A3),
                        size: 22,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InstalledBadge extends StatelessWidget {
  const _InstalledBadge({required this.installed, required this.label});

  final bool installed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = installed ? const Color(0xFF2ED9A3) : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            installed ? Icons.check_circle : Icons.cancel_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
