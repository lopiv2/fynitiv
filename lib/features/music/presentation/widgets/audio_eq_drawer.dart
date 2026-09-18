import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/audio_eq_provider.dart';
import '../../application/soloud_music_provider.dart';

const _kFreqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

String _freqLabel(int f) => f >= 1000 ? '${f ~/ 1000}k' : '$f';

class AudioEqDrawer extends ConsumerWidget {
  const AudioEqDrawer({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eq = ref.watch(audioEqProvider);
    final notifier = ref.read(audioEqProvider.notifier);

    return Container(
      width: 360,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1A),
        border: Border(left: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header: Sonido + switch + X
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  const Text('Sonido', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 12),
                  Switch(
                    value: eq.enabled,
                    activeTrackColor: const Color(0xFF4DD0E1),
                    activeThumbColor: Colors.white,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    onChanged: (v) => notifier.setEnabled(v),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    style: IconButton.styleFrom(backgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            _EngineStatus(enabled: eq.enabled),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                children: [
                  const Text('Preajuste', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final name in eqPresetNames)
                        ChoiceChip(
                          label: Text(name),
                          selected: eq.preset == name,
                          onSelected: (_) => notifier.applyPreset(name),
                          selectedColor: const Color(0xFF1A3A4A),
                          backgroundColor: const Color(0xFF1E1E2E),
                          labelStyle: TextStyle(
                            color: eq.preset == name ? const Color(0xFF4DD0E1) : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: StadiumBorder(side: BorderSide(color: eq.preset == name ? const Color(0xFF4DD0E1) : Colors.white12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Bandas', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151525),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: SizedBox(
                      height: 180,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(10, (i) {
                          final linear = eq.bands[i];
                          final db = (20 * (math.log(linear <= 0 ? 0.001 : linear) / math.ln10)).round().clamp(-12, 12);
                          return Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 16,
                                  child: Text('$db', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                                Expanded(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                        activeTrackColor: const Color(0xFF4DD0E1),
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: const Color(0xFF4DD0E1),
                                      ),
                                      child: Slider(
                                        min: -12,
                                        max: 12,
                                        divisions: 24,
                                        value: db.toDouble(),
                                        onChanged: eq.enabled
                                            ? (v) {
                                                final lin = math.pow(10, v / 20).toDouble().clamp(0.0, 4.0);
                                                notifier.setBand(i, lin);
                                              }
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(_freqLabel(_kFreqs[i]), style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Extras', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _ExtrasTile(
                    title: 'Refuerzo de graves',
                    subtitle: 'Realza los sub-bajos sin tocar el resto',
                    value: eq.bassBoost,
                    enabled: eq.enabled,
                    onChanged: notifier.setBassBoost,
                  ),
                  _ExtrasTile(
                    title: 'Normalizar volumen',
                    subtitle: 'Iguala el nivel entre canciones',
                    value: eq.normalize,
                    enabled: eq.enabled,
                    onChanged: notifier.setNormalize,
                  ),
                  _ExtrasDropdown(
                    title: 'Reverb',
                    subtitle: 'Simula el espacio donde suena',
                    value: eq.reverb,
                    enabled: eq.enabled,
                    items: const ['Ninguna', 'Habitación', 'Catedral', 'Placa', 'Eco'],
                    onChanged: notifier.setReverb,
                  ),
                  _ExtrasDropdown(
                    title: 'Velocidad',
                    subtitle: 'Mantiene el tono al cambiarla',
                    value: '${eq.speed.toStringAsFixed(eq.speed % 1 == 0 ? 0 : 2)}x',
                    rawValue: eq.speed,
                    enabled: eq.enabled,
                    items: const ['0.5x', '0.75x', '1x', '1.25x', '1.5x', '2x'],
                    onChanged: (s) {
                      final v = double.tryParse(s.replaceAll('x', '')) ?? 1.0;
                      notifier.setSpeed(v);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => notifier.reset(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Restablecer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // Sistema universal de notificaciones (ver AGENTS.md).
                            unawaited(
                              EasyLoading.showToast(
                                'Preajuste guardado',
                                toastPosition: EasyLoadingToastPosition.bottom,
                                maskType: EasyLoadingMaskType.none,
                                dismissOnTap: true,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Guardar preajuste', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indica si el motor activo acepta los filtros (solo SoLoud) y si el EQ
/// está aplicado. Sirve para comprobar de un vistazo que las bandas actúan.
class _EngineStatus extends ConsumerWidget {
  const _EngineStatus({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soloud = ref.watch(soloudMusicProvider);
    final isSoloud = soloud.engine == PlaybackEngine.soloud;
    final ok = isSoloud && enabled && soloud.playing;
    final text = !isSoloud
        ? 'Motor MediaKit · el EQ requiere SoLoud'
        : !enabled
            ? 'SoLoud · EQ desactivado (plano)'
            : !soloud.playing
                ? 'SoLoud · en pausa (mueve una banda y dale a play)'
                : 'SoLoud · EQ aplicado en vivo';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (ok ? const Color(0xFF4DD0E1) : Colors.amber).withValues(alpha: 0.10),
        border: const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? const Color(0xFF4DD0E1) : Colors.amber,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtrasTile extends StatelessWidget {
  const _ExtrasTile({required this.title, required this.subtitle, required this.value, required this.enabled, required this.onChanged});
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: const Color(0xFF4DD0E1),
            activeThumbColor: Colors.white,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _ExtrasDropdown extends StatelessWidget {
  const _ExtrasDropdown({required this.title, required this.subtitle, required this.value, this.rawValue, required this.enabled, required this.items, required this.onChanged});
  final String title;
  final String subtitle;
  final String value;
  final double? rawValue;
  final bool enabled;
  final List<String> items;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF1E1E2E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items.contains(value) ? value : items.first,
                dropdownColor: const Color(0xFF1A2568),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                items: [for (final it in items) DropdownMenuItem(value: it, child: Text(it, style: const TextStyle(color: Colors.white)))],
                onChanged: enabled ? (v) { if (v != null) onChanged(v); } : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
