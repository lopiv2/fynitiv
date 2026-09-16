import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:audio_flux/audio_flux.dart';

import '../../../../core/skin/skin.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../music/application/soloud_music_provider.dart';
import '../../../../core/widgets/audio_waveform.dart';

class RadioEffectsPanel extends ConsumerWidget {
  const RadioEffectsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skinAsync = ref.watch(skinControllerProvider);
    final skin = skinAsync.value;
    final effect = skin?.audioWaveformEffect ?? AudioWaveformEffect.equalizer;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: skin?.sidebarBackground ?? const Color(0xFF1E293B),
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
                      color: skin?.textPrimary ?? Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.audioWaveformEffect,
                    style: TextStyle(
                      color: skin?.textSecondary ?? Colors.white70,
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
                      for (final e in AudioWaveformEffect.values)
                        DropdownMenuItem(
                          value: e,
                          child: Text(
                            _label(l10n, e),
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
                    color: skin?.accent ?? const Color(0xFF22D3EE),
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

  String _label(AppLocalizations l10n, AudioWaveformEffect e) {
    switch (e) {
      case AudioWaveformEffect.equalizer:
        return l10n.effectEqualizer;
      case AudioWaveformEffect.wave:
        return l10n.effectWave;
      case AudioWaveformEffect.mirror:
        return l10n.effectMirror;
      case AudioWaveformEffect.bars:
        return l10n.effectBars;
      case AudioWaveformEffect.surfer:
        return l10n.effectSurfer;
      case AudioWaveformEffect.audioFlux:
        return l10n.effectAudioFlux;
      case AudioWaveformEffect.frequency:
        return l10n.effectFrequency;
    }
  }
}

class _AnimatedMiniWave extends StatefulWidget {
  const _AnimatedMiniWave({required this.color, required this.effect});
  final Color color;
  final AudioWaveformEffect effect;
  @override
  State<_AnimatedMiniWave> createState() => _AnimatedMiniWaveState();
}

class _AnimatedMiniWaveState extends State<_AnimatedMiniWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        painter: _MiniWavePainter(
          color: widget.color,
          effect: widget.effect,
          phase: _c.value,
        ),
      ),
    );
  }
}

class _MiniWavePainter extends CustomPainter {
  _MiniWavePainter({required this.color, required this.effect, this.phase = 0});
  final Color color;
  final AudioWaveformEffect effect;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final paintDim = Paint()
      ..color = color.withValues(alpha: 0.32)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final anim = phase;
    switch (effect) {
      case AudioWaveformEffect.bars:
        final count = 10;
        final gap = size.width / count;
        for (var i = 0; i < count; i++) {
          final base = (i % 2 == 0 ? size.height * 0.38 : size.height * 0.22);
          final h =
              base * (phase == 0 ? 1 : (0.6 + 0.4 * (1 + (i + anim * 10) % 2)));
          final x = i * gap + gap / 2;
          canvas.drawLine(
            Offset(x, size.height / 2 - h / 2),
            Offset(x, size.height / 2 + h / 2),
            paint,
          );
        }
        break;
      case AudioWaveformEffect.wave:
      case AudioWaveformEffect.mirror:
        final path = Path();
        for (var i = 0; i < size.width; i++) {
          final wave =
              size.height *
              0.18 *
              ((i % 2 == 0 ? 1 : -1) *
                  (phase == 0 ? 1 : (0.8 + 0.2 * (anim * 6 + i * 0.12) % 1)));
          final y = size.height / 2 + wave;
          if (i == 0) path.moveTo(i.toDouble(), y);
          path.lineTo(i.toDouble(), y);
        }
        canvas.drawPath(path, paint);
        break;
      case AudioWaveformEffect.surfer:
        final path2 = Path();
        path2.moveTo(0, size.height * 0.6);
        for (var i = 0; i < size.width; i++) {
          path2.lineTo(
            i.toDouble(),
            size.height * 0.6 + 10 * ((i / 10 + anim) % 1),
          );
        }
        canvas.drawPath(path2, paint);
        break;
      default:
        final count = 12;
        final gap = size.width / count;
        for (var i = 0; i < count; i++) {
          final base = size.height * (0.15 + (i % 4) * 0.07);
          final h = phase == 0
              ? base
              : base * (0.65 + 0.7 * ((i * 0.7 + anim * 12) % 1));
          final x = i * gap + gap / 2;
          canvas.drawLine(
            Offset(x, size.height / 2 - h / 2),
            Offset(x, size.height / 2 + h / 2),
            i % 3 == 0 ? paint : paintDim,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniWavePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.color != color ||
      oldDelegate.effect != effect;
}
