import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/skin/skin_presets.dart';
import '../../../../core/widgets/scale_button.dart';
import '../../../../l10n/app_localizations.dart';

/// Panel de Apariencia: presets + editor de skin.
class AppearancePanel extends ConsumerStatefulWidget {
  const AppearancePanel({super.key});

  @override
  ConsumerState<AppearancePanel> createState() => _AppearancePanelState();
}

/// Assets disponibles para usar como logotipo.
const _logoAssets = [
  'assets/images/Logo_letter_jellyfinitive.png',
  'assets/images/Logo_jellyfinitive.png',
];

class _AppearancePanelState extends ConsumerState<AppearancePanel> {
  late Skin _draft;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = ref.watch(skinControllerProvider).value;
    if (!_loaded && active != null) {
      _draft = active;
      _loaded = true;
    }
    if (active == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.appearance,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              // Presets.
              Text(
                l10n.presets,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in SkinPresets.all)
                    _PresetChip(
                      preset: preset,
                      selected: active.id == preset.id,
                      onTap: () => ref
                          .read(skinControllerProvider.notifier)
                          .apply(preset),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              // Editor de colores.
              Text(
                l10n.colors,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _ColorRow(
                label: l10n.primaryColor,
                color: _draft.primary,
                onChanged: (c) => setState(() => _draft = _draft.copyWith(primary: c)),
              ),
              _ColorRow(
                label: l10n.secondaryColor,
                color: _draft.secondary,
                onChanged: (c) => setState(() => _draft = _draft.copyWith(secondary: c)),
              ),
              _ColorRow(
                label: l10n.backgroundTopColor,
                color: _draft.backgroundTop,
                onChanged: (c) => setState(() => _draft = _draft.copyWith(backgroundTop: c)),
              ),
              _ColorRow(
                label: l10n.backgroundBottomColor,
                color: _draft.backgroundBottom,
                onChanged: (c) => setState(() => _draft = _draft.copyWith(backgroundBottom: c)),
              ),
              _ColorRow(
                label: l10n.sidebarColor,
                color: _draft.sidebarBackground,
                onChanged: (c) => setState(() => _draft = _draft.copyWith(sidebarBackground: c)),
              ),
              _ColorRow(
                label: l10n.accentColor,
                color: _draft.accent,
                onChanged: (c) => setState(() => _draft = _draft.copyWith(accent: c)),
              ),
              const SizedBox(height: 24),
              // Layout.
              Text(
                l10n.layout,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _OptionRow(
                label: l10n.sidebarPosition,
                child: SegmentedButton<SidebarPosition>(
                  segments: [
                    ButtonSegment(
                      value: SidebarPosition.left,
                      label: Text(l10n.left),
                    ),
                    ButtonSegment(
                      value: SidebarPosition.right,
                      label: Text(l10n.right),
                    ),
                  ],
                  selected: {_draft.sidebarPosition},
                  onSelectionChanged: (s) => setState(
                    () => _draft = _draft.copyWith(sidebarPosition: s.first),
                  ),
                ),
              ),
              _OptionRow(
                label: l10n.logoPosition,
                child: SegmentedButton<LogoPosition>(
                  segments: [
                    ButtonSegment(
                      value: LogoPosition.top,
                      label: Text(l10n.top),
                    ),
                    ButtonSegment(
                      value: LogoPosition.bottom,
                      label: Text(l10n.bottom),
                    ),
                  ],
                  selected: {_draft.logoPosition},
                  onSelectionChanged: (s) => setState(
                    () => _draft = _draft.copyWith(logoPosition: s.first),
                  ),
                ),
              ),
              _OptionRow(
                label: l10n.avatarPosition,
                child: SegmentedButton<AvatarPosition>(
                  segments: [
                    ButtonSegment(
                      value: AvatarPosition.top,
                      label: Text(l10n.top),
                    ),
                    ButtonSegment(
                      value: AvatarPosition.bottom,
                      label: Text(l10n.bottom),
                    ),
                  ],
                  selected: {_draft.avatarPosition},
                  onSelectionChanged: (s) => setState(
                    () => _draft = _draft.copyWith(avatarPosition: s.first),
                  ),
                ),
              ),
              _OptionRow(
                label: l10n.sidebarLogo,
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: Text(l10n.logoImage),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.logoText),
                    ),
                  ],
                  selected: {_draft.sidebarLogo != null},
                  onSelectionChanged: (s) => setState(
                    () => _draft = _draft.copyWith(
                      sidebarLogo: s.first
                          ? _draft.sidebarLogo ??
                              SkinPresets.jellyfinDefault.sidebarLogo
                          : null,
                      clearSidebarLogo: !s.first,
                    ),
                  ),
                ),
              ),
              if (_draft.sidebarLogo != null)
                _OptionRow(
                  label: l10n.chooseLogoImage,
                  child: DropdownButtonFormField<String>(
                    initialValue: _draft.sidebarLogo,
                    dropdownColor: const Color(0xFF1A2568),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      for (final asset in _logoAssets)
                        DropdownMenuItem(
                          value: asset,
                          child: Text(
                            asset.split('/').last,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(
                      () => _draft = _draft.copyWith(sidebarLogo: v),
                    ),
                  ),
                ),
              _OptionRow(
                label: l10n.cardRadius,
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _draft.cardBorderRadius,
                        min: 0,
                        max: 24,
                        divisions: 12,
                        label: '${_draft.cardBorderRadius.round()}',
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(cardBorderRadius: v),
                        ),
                      ),
                    ),
                    Text(
                      '${_draft.cardBorderRadius.round()}px',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              _SwitchRow(
                label: l10n.showContinueRow,
                value: _draft.showContinueRow,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(showContinueRow: v),
                ),
              ),
              _SwitchRow(
                label: l10n.showNewReleasesRow,
                value: _draft.showNewReleasesRow,
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(showNewReleasesRow: v),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.importExport,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _export(context, l10n),
                      icon: const Icon(Icons.ios_share, size: 18),
                      label: Text(l10n.exportSkin),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _import(context, l10n),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: Text(l10n.importSkin),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => ref
                        .read(skinControllerProvider.notifier)
                        .reset(),
                    child: Text(l10n.reset),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(skinControllerProvider.notifier)
                        .apply(_draft),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Copia el JSON del skin actual al portapapeles.
  Future<void> _export(BuildContext context, AppLocalizations l10n) async {
    final json = ref
        .read(skinControllerProvider.notifier)
        .exportToJson(_draft);
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.skinCopied)),
    );
  }

  /// Pide el JSON de un skin y lo aplica si es válido.
  Future<void> _import(BuildContext context, AppLocalizations l10n) async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<Skin>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(l10n.importSkin),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: '{ "id": "mi_skin", ... }',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    final skin = ref
                        .read(skinControllerProvider.notifier)
                        .importFromJson(controller.text);
                    Navigator.of(context).pop(skin);
                  } catch (e) {
                    setDialogState(() => error = '$e');
                  }
                },
                child: Text(l10n.importSkin),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (result != null && mounted) {
      setState(() => _draft = result);
      await ref.read(skinControllerProvider.notifier).apply(result);
    }
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final Skin preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      selected: selected,
      selectedScale: 1.05,
      borderRadius: BorderRadius.circular(12),
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [preset.primary, preset.accent],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              preset.name,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.label, required this.color, required this.onChanged});

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          _ColorDot(color: color, onTap: () => _pick(context)),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        initial: color,
        title: label,
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: Colors.white24),
        ),
      ),
    );
  }
}

/// Diálogo selector de color con sliders HSV.
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.title});

  final Color initial;
  final String title;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _color,
              ),
            ),
            const SizedBox(height: 16),
            _HsvSlider(
              label: 'H',
              value: _hsv.hue / 360,
              color: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
              onChanged: (v) => setState(() => _hsv = _hsv.withHue(v * 360)),
            ),
            _HsvSlider(
              label: 'S',
              value: _hsv.saturation,
              color: HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor(),
              onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            _HsvSlider(
              label: 'V',
              value: _hsv.value,
              color: HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
              onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

class _HsvSlider extends StatelessWidget {
  const _HsvSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Expanded(
          child: Slider(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
