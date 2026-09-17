import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/radio_skin.dart';
import '../../../../core/skin/skin.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../music/application/soloud_music_provider.dart';
import '../../../../core/widgets/audio_waveform.dart';

/// Panel de efectos de la radio: selector de onda + visualización.
///
/// Mismos 7 efectos de onda que el Music player screen
/// (`player_screen.dart` `_buildEffectsLayout`) y misma fuente de estado
/// (`skinControllerProvider.audioWaveformEffect`). Los efectos que
/// requieren SoLoud (`audioFlux`, `frequency`) funcionan en radio gracias
/// a la señal sintética de `radioFakeSignalProvider` (la radio suele ir
/// por MediaKit y no tiene FFT real).
class RadioEffectsPanel extends ConsumerWidget {
  const RadioEffectsPanel({super.key, this.radioSkin});

  final RadioSkin? radioSkin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skinAsync = ref.watch(skinControllerProvider);
    final skin = skinAsync.value;
    final effect = skin?.audioWaveformEffect ?? AudioWaveformEffect.equalizer;

    final cardColor =
        radioSkin?.cardBackground ??
        skin?.sidebarBackground ??
        const Color(0xFF1E293B);
    final accent =
        radioSkin?.accent ?? skin?.accent ?? const Color(0xFF22D3EE);
    final textPrimary = radioSkin?.textPrimary ?? skin?.textPrimary;
    final textSecondary = radioSkin?.textSecondary ?? skin?.textSecondary;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.effects,
                    style: TextStyle(
                      color: textPrimary ?? Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.audioWaveformEffect,
                    style: TextStyle(
                      color: textSecondary ?? Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AudioWaveformEffect>(
                    value: effect,
                    isDense: true,
                    dropdownColor: const Color(0xFF1A2568),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    items: [
                      for (final entry in [
                        (
                          AudioWaveformEffect.equalizer,
                          l10n.effectEqualizer,
                        ),
                        (AudioWaveformEffect.wave, l10n.effectWave),
                        (AudioWaveformEffect.mirror, l10n.effectMirror),
                        (AudioWaveformEffect.bars, l10n.effectBars),
                        (AudioWaveformEffect.surfer, l10n.effectSurfer),
                        (
                          AudioWaveformEffect.audioFlux,
                          l10n.effectAudioFlux,
                        ),
                        (
                          AudioWaveformEffect.frequency,
                          l10n.effectFrequency,
                        ),
                        (
                          AudioWaveformEffect.ledSpectrum,
                          l10n.effectLedSpectrum,
                        ),
                        (
                          AudioWaveformEffect.soundEclipse,
                          l10n.effectSoundEclipse,
                        ),
                        (
                          AudioWaveformEffect.soundSinus,
                          l10n.effectSoundSinus,
                        ),
                        (
                          AudioWaveformEffect.raymarching,
                          l10n.effectRaymarching,
                        ),
                        (
                          AudioWaveformEffect.smokeRings,
                          l10n.effectSmokeRings,
                        ),
                        (
                          AudioWaveformEffect.circularSpectrum,
                          l10n.effectCircularSpectrum,
                        ),
                      ])
                        DropdownMenuItem(
                          value: entry.$1,
                          child: Text(
                            entry.$2,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null || skin == null) return;
                      ref
                          .read(skinControllerProvider.notifier)
                          .apply(skin.copyWith(audioWaveformEffect: v));
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Consumer(
                builder: (context, ref, _) {
                  final soloud = ref.watch(soloudMusicProvider);
                  final isPlaying =
                      soloud.playing && soloud.session?.itemId == 'radio';
                  return AudioWaveform(
                    playing: isPlaying,
                    effect: effect,
                    color: accent,
                    expanded: true,
                    isRadio: true,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
