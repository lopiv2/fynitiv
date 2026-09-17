import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_flux/audio_flux.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/music/application/soloud_music_provider.dart';
import '../../features/radio/application/radio_fake_signal_provider.dart';
import '../audio/soloud_initializer.dart';
import '../skin/skin.dart';
import 'circular_spectrum.dart';
import 'led_spectrum.dart';
import 'raymarch.dart';
import 'smoke_rings.dart';
import 'sound_eclipse.dart';
import 'sound_sinus.dart';

/// Widget compartido para ondas de audio — reutilizado por PlayerScreen y Radio.
///
/// Misma lógica que `_AudioWaveform` original de `player_screen.dart`,
/// extraído a `core/widgets` para evitar dependencia circular radio → player.
class AudioWaveform extends ConsumerStatefulWidget {
  const AudioWaveform({
    super.key,
    required this.playing,
    required this.effect,
    required this.color,
    this.progress = 0,
    this.expanded = false,
    this.trackColor,
    this.isRadio = false,
  });

  final bool playing;
  final double progress;
  final AudioWaveformEffect effect;
  final Color color;
  final bool expanded;
  final Color? trackColor;
  final bool isRadio;

  @override
  ConsumerState<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends ConsumerState<AudioWaveform>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _explosionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress < 1.0 && widget.progress >= 1.0) {
      _explosionController.forward(from: 0);
    }
    _sync();
  }

  void _sync() {
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _explosionController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackColor =
        widget.trackColor ?? widget.color.withValues(alpha: 0.18);
    if (widget.expanded) {
      if (widget.effect == AudioWaveformEffect.frequency) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          if (widget.isRadio && widget.playing) {
            return const SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: FakeFrequencyVisualizer(),
              ),
            );
          }
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: WaveformPainter(
                  effect: widget.effect,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: trackColor,
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
          child: Center(
            child: SizedBox(
              height: 540,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const FrequencyVisualizer(),
              ),
            ),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.audioFlux) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          if (widget.isRadio && widget.playing) {
            return SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FakeWaveformVisualizer(
                  color: widget.color,
                  expanded: true,
                ),
              ),
            );
          }
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: WaveformPainter(
                  effect: widget.effect,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: trackColor,
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AudioFlux(
              dataSource: DataSources.soloud,
              fluxType: FluxType.waveform,
              modelParams: ModelParams(
                backgroundColor: Colors.transparent,
                barColor: widget.color,
                barGradient: LinearGradient(
                  colors: [widget.color, widget.color.withValues(alpha: 0.6)],
                ),
                audioScale: 1.6,
                fftParams: const FftParams(
                  minBinIndex: 1,
                  maxBinIndex: 120,
                  fftSmoothing: 0.85,
                ),
                waveformParams: const WaveformPainterParams(
                  barsWidth: 3,
                  barSpacingScale: 0.5,
                  chunkSize: 1,
                ),
              ),
            ),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.ledSpectrum) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          if (widget.isRadio && widget.playing) {
            return const SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: FakeLedSpectrumVisualizer(),
              ),
            );
          }
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: WaveformPainter(
                  effect: widget.effect,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: trackColor,
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: LedSpectrumVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.soundEclipse) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          if (widget.isRadio && widget.playing) {
            return const SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: FakeSoundEclipseVisualizer(),
              ),
            );
          }
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: WaveformPainter(
                  effect: widget.effect,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: trackColor,
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: SoundEclipseVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.soundSinus) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          if (widget.isRadio && widget.playing) {
            return const SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: FakeSoundSinusVisualizer(),
              ),
            );
          }
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: WaveformPainter(
                  effect: widget.effect,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: trackColor,
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: SoundSinusVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.raymarching) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          if (widget.isRadio && widget.playing) {
            return const SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: FakeRaymarchVisualizer(),
              ),
            );
          }
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: WaveformPainter(
                  effect: widget.effect,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: trackColor,
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: RaymarchVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.smokeRings) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          if (widget.isRadio && widget.playing) {
            return const SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: FakeSmokeRingsVisualizer(),
              ),
            );
          }
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: WaveformPainter(
                  effect: widget.effect,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: trackColor,
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: SmokeRingsVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.circularSpectrum) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          if (widget.isRadio && widget.playing) {
            return const SizedBox.expand(
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                child: FakeCircularSpectrumVisualizer(),
              ),
            );
          }
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: WaveformPainter(
                  effect: widget.effect,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: trackColor,
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: CircularSpectrumVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.surfer) {
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox.expand(
            child: SurferWave(
              phase: _controller.value,
              progress: widget.progress,
              color: widget.color,
              trackColor: trackColor,
              explosion: _explosionController.value,
            ),
          ),
        );
      }
      return AnimatedBuilder(
        animation: Listenable.merge([_controller, _explosionController]),
        builder: (context, _) => SizedBox.expand(
          child: CustomPaint(
            painter: WaveformPainter(
              effect: widget.effect,
              phase: _controller.value,
              progress: widget.progress,
              color: widget.color,
              trackColor: trackColor,
              explosion: _explosionController.value,
            ),
          ),
        ),
      );
    }
    if (widget.effect == AudioWaveformEffect.audioFlux) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        if (widget.isRadio && widget.playing) {
          return SizedBox(
            height: 52,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: FakeWaveformVisualizer(color: widget.color),
            ),
          );
        }
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 52,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                effect: widget.effect,
                phase: _controller.value,
                progress: widget.progress,
                color: widget.color,
                trackColor: trackColor,
                explosion: _explosionController.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      }
      return SizedBox(
        height: 52,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AudioFlux(
            dataSource: DataSources.soloud,
            fluxType: FluxType.waveform,
            modelParams: ModelParams(
              backgroundColor: Colors.transparent,
              barColor: widget.color,
              barGradient: LinearGradient(
                colors: [widget.color, widget.color.withValues(alpha: 0.6)],
              ),
              audioScale: 1.4,
              fftParams: const FftParams(
                minBinIndex: 1,
                maxBinIndex: 120,
                fftSmoothing: 0.85,
              ),
              waveformParams: const WaveformPainterParams(
                barsWidth: 3,
                barSpacingScale: 0.5,
                chunkSize: 1,
              ),
            ),
          ),
        ),
      );
    }
    if (widget.effect == AudioWaveformEffect.frequency) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        if (widget.isRadio && widget.playing) {
          return const SizedBox(
            height: 52,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              child: FakeFrequencyVisualizer(),
            ),
          );
        }
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                effect: widget.effect,
                phase: _controller.value,
                progress: widget.progress,
                color: widget.color,
                trackColor: trackColor,
                explosion: _explosionController.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      }
      return SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: const FrequencyVisualizer(),
        ),
      );
    }
    if (widget.effect == AudioWaveformEffect.ledSpectrum) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        if (widget.isRadio && widget.playing) {
          return const SizedBox(
            height: 130,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              child: FakeLedSpectrumVisualizer(),
            ),
          );
        }
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                effect: widget.effect,
                phase: _controller.value,
                progress: widget.progress,
                color: widget.color,
                trackColor: trackColor,
                explosion: _explosionController.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      }
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: LedSpectrumVisualizer(),
        ),
      );
    }
    if (widget.effect == AudioWaveformEffect.soundEclipse) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        if (widget.isRadio && widget.playing) {
          return const SizedBox(
            height: 130,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              child: FakeSoundEclipseVisualizer(),
            ),
          );
        }
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                effect: widget.effect,
                phase: _controller.value,
                progress: widget.progress,
                color: widget.color,
                trackColor: trackColor,
                explosion: _explosionController.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      }
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: SoundEclipseVisualizer(),
        ),
      );
    }
    if (widget.effect == AudioWaveformEffect.soundSinus) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        if (widget.isRadio && widget.playing) {
          return const SizedBox(
            height: 130,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              child: FakeSoundSinusVisualizer(),
            ),
          );
        }
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                effect: widget.effect,
                phase: _controller.value,
                progress: widget.progress,
                color: widget.color,
                trackColor: trackColor,
                explosion: _explosionController.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      }
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: SoundSinusVisualizer(),
        ),
      );
    }
    if (widget.effect == AudioWaveformEffect.raymarching) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        if (widget.isRadio && widget.playing) {
          return const SizedBox(
            height: 130,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              child: FakeRaymarchVisualizer(),
            ),
          );
        }
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                effect: widget.effect,
                phase: _controller.value,
                progress: widget.progress,
                color: widget.color,
                trackColor: trackColor,
                explosion: _explosionController.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      }
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: RaymarchVisualizer(),
        ),
      );
    }
    if (widget.effect == AudioWaveformEffect.smokeRings) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        if (widget.isRadio && widget.playing) {
          return const SizedBox(
            height: 130,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              child: FakeSmokeRingsVisualizer(),
            ),
          );
        }
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                effect: widget.effect,
                phase: _controller.value,
                progress: widget.progress,
                color: widget.color,
                trackColor: trackColor,
                explosion: _explosionController.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      }
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: SmokeRingsVisualizer(),
        ),
      );
    }
    if (widget.effect == AudioWaveformEffect.circularSpectrum) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        if (widget.isRadio && widget.playing) {
          return const SizedBox(
            height: 130,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              child: FakeCircularSpectrumVisualizer(),
            ),
          );
        }
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                effect: widget.effect,
                phase: _controller.value,
                progress: widget.progress,
                color: widget.color,
                trackColor: trackColor,
                explosion: _explosionController.value,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      }
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: CircularSpectrumVisualizer(),
        ),
      );
    }
    if (widget.effect == AudioWaveformEffect.surfer) {
      return AnimatedBuilder(
        animation: Listenable.merge([_controller, _explosionController]),
        builder: (context, _) => SizedBox(
          height: 72,
          width: double.infinity,
          child: SurferWave(
            phase: _controller.value,
            progress: widget.progress,
            color: widget.color,
            trackColor: trackColor,
            explosion: _explosionController.value,
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _explosionController]),
      builder: (context, _) => SizedBox(
        height: 52,
        width: double.infinity,
        child: CustomPaint(
          painter: WaveformPainter(
            effect: widget.effect,
            phase: _controller.value,
            progress: widget.progress,
            color: widget.color,
            trackColor: trackColor,
            explosion: _explosionController.value,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class FrequencyVisualizer extends StatefulWidget {
  const FrequencyVisualizer({super.key});
  @override
  State<FrequencyVisualizer> createState() => _FrequencyVisualizerState();
}

class _FrequencyVisualizerState extends State<FrequencyVisualizer> {
  StreamSubscription? _sub;
  Float32List _fft = Float32List(256);
  @override
  void initState() {
    super.initState();
    try {
      SoLoud.instance.setVisualizationEnabled(true);
    } catch (_) {}
    _sub = SoLoud.instance.audioVisualizationEvents.listen((data) {
      if (data.fftData != null && mounted) setState(() => _fft = data.fftData!);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: SymmetricFftPainter(fft: _fft, audioScale: 1),
    );
  }
}

class SymmetricFftPainter extends CustomPainter {
  SymmetricFftPainter({required this.fft, this.audioScale = 2.2});
  final Float32List fft;
  final double audioScale;
  static const int barCount = 64;
  static const double barSpacingScale = 0.28;
  static const double barRadius = 2.0;
  static const List<Color> rainbow = [
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF8BC34A),
    Color(0xFF26C6DA),
    Color(0xFF42A5F5),
    Color(0xFF7E57C2),
    Color(0xFFEC407A),
  ];
  Color _colorAt(double t) {
    final scaled = t * (rainbow.length - 1);
    final idx = scaled.floor().clamp(0, rainbow.length - 2);
    final frac = scaled - idx;
    return Color.lerp(rainbow[idx], rainbow[idx + 1], frac)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final half = barCount ~/ 2;
    final range = fft.length.clamp(1, 256);
    final chunkSize = range / half;
    final halfValues = List<double>.filled(half, 0.0);
    for (var j = 0; j < half; j++) {
      final start = (j * chunkSize).floor().clamp(0, range - 1);
      final end = ((j + 1) * chunkSize).ceil().clamp(0, range);
      double sum = 0;
      int cnt = 0;
      for (var k = start; k < end && k < fft.length; k++) {
        sum += fft[k];
        cnt++;
      }
      halfValues[j] = cnt > 0 ? sum / cnt : 0.0;
    }
    final barWidth = size.width / barCount;
    final barInnerWidth = barWidth * (1.0 - barSpacingScale);
    final baseline = size.height * 0.58;
    for (var i = 0; i < barCount; i++) {
      final mirroredIdx = i < half ? (half - 1 - i) : (i - half);
      final value = halfValues[mirroredIdx.clamp(0, half - 1)];
      final clamped = value.clamp(0.0, 1.0);
      final barH = (size.height * 0.58 * clamped * audioScale).clamp(
        2.0,
        size.height * 0.58,
      );
      final x = i * barWidth + (barWidth - barInnerWidth) / 2;
      final color = _colorAt(i / (barCount - 1));
      final topRect = Rect.fromLTWH(x, baseline - barH, barInnerWidth, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(topRect, Radius.circular(barRadius)),
        Paint()..color = color,
      );
      final reflH = barH * 0.55;
      final reflRect = Rect.fromLTWH(x, baseline + 2, barInnerWidth, reflH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(reflRect, Radius.circular(barRadius)),
        Paint()..color = color.withValues(alpha: 0.32),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, baseline, size.width, 1),
      Paint()..color = Colors.white10,
    );
  }

  @override
  bool shouldRepaint(covariant SymmetricFftPainter oldDelegate) => true;
}

/// Visualizador de frecuencia con señal sintética para la radio.
///
/// Consume [radioFakeSignalProvider] (FFT falsa suavizada con beat) en lugar
/// de `SoLoud.instance.audioVisualizationEvents`, que no existe cuando la
/// radio suena vía MediaKit. Se congela en pausa porque el provider deja
/// de emitir.
class FakeFrequencyVisualizer extends ConsumerWidget {
  const FakeFrequencyVisualizer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fft = ref.watch(radioFakeSignalProvider);
    return CustomPaint(
      size: Size.infinite,
      painter: SymmetricFftPainter(fft: fft, audioScale: 1.8),
    );
  }
}

/// Espectro LED con señal sintética para la radio.
///
/// Mismo [LedSpectrumPainter] que en música, alimentado con la FFT falsa
/// de [radioFakeSignalProvider] (la radio suele ir por MediaKit sin FFT
/// real de SoLoud). Se congela en pausa porque el provider deja de emitir.
class FakeLedSpectrumVisualizer extends ConsumerWidget {
  const FakeLedSpectrumVisualizer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fft = ref.watch(radioFakeSignalProvider);
    return CustomPaint(
      size: Size.infinite,
      painter: LedSpectrumPainter(fft: fft),
    );
  }
}

/// Eclipse sonoro con señal sintética para la radio.
///
/// Mismo [SoundEclipsePainter] que en música (con rotación continua),
/// alimentado con la FFT falsa de [radioFakeSignalProvider]. La rotación
/// se congela en pausa junto con la señal, porque el provider deja de
/// emitir y el ticker solo avanza cuando hay reproducción.
class FakeSoundEclipseVisualizer extends ConsumerStatefulWidget {
  const FakeSoundEclipseVisualizer({super.key});
  @override
  ConsumerState<FakeSoundEclipseVisualizer> createState() =>
      _FakeSoundEclipseVisualizerState();
}

/// Onda sinus con señal sintética para la radio.
///
/// Mismo [SoundSinusPainter] que en música (con tiempo continuo),
/// alimentado con la FFT falsa de [radioFakeSignalProvider]. El tiempo
/// se congela en pausa junto con la señal.
class FakeSoundSinusVisualizer extends ConsumerStatefulWidget {
  const FakeSoundSinusVisualizer({super.key});
  @override
  ConsumerState<FakeSoundSinusVisualizer> createState() =>
      _FakeSoundSinusVisualizerState();
}

/// Sala raymarcheada con señal sintética para la radio.
///
/// Mismo [RaymarchPainter] que en música, alimentado con la FFT falsa de
/// [radioFakeSignalProvider] y la onda falsa de [radioFakeWaveProvider].
/// Se congela en pausa porque los providers dejan de emitir.
class FakeRaymarchVisualizer extends ConsumerWidget {
  const FakeRaymarchVisualizer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fft = ref.watch(radioFakeSignalProvider);
    final wave = ref.watch(radioFakeWaveProvider);
    return CustomPaint(
      size: Size.infinite,
      painter: RaymarchPainter(fft: fft, wave: wave),
    );
  }
}

/// Anillos de humo con señal sintética para la radio.
///
/// Mismo [SmokeRingsPainter] que en música (con tiempo continuo),
/// alimentado con la FFT falsa de [radioFakeSignalProvider]. El tiempo
/// se congela en pausa junto con la señal.
class FakeSmokeRingsVisualizer extends ConsumerStatefulWidget {
  const FakeSmokeRingsVisualizer({super.key});
  @override
  ConsumerState<FakeSmokeRingsVisualizer> createState() =>
      _FakeSmokeRingsVisualizerState();
}

/// Espectro circular con señal sintética para la radio.
///
/// Mismo [CircularSpectrumPainter] que en música, alimentado con la FFT
/// falsa de [radioFakeSignalProvider]. Se congela en pausa porque el
/// provider deja de emitir.
class FakeCircularSpectrumVisualizer extends ConsumerWidget {
  const FakeCircularSpectrumVisualizer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fft = ref.watch(radioFakeSignalProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          size: Size.infinite,
          painter: CircularSpectrumPainter(fft: fft),
        ),
        CircularFlare(fft: fft),
      ],
    );
  }
}

class _FakeSmokeRingsVisualizerState
    extends ConsumerState<FakeSmokeRingsVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0;
  double _pending = 0;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    // Repintado limitado a ~30fps para no saturar la CPU/GPU.
    _ticker = createTicker((elapsed) {
      final dt = _lastTick == null
          ? 0.016
          : (elapsed - _lastTick!).inMicroseconds / 1e6;
      _lastTick = elapsed;
      final playing = ref.read(
        soloudMusicProvider.select(
          (s) => s.playing && s.session?.itemId == 'radio',
        ),
      );
      if (!playing) {
        _pending = 0;
        return;
      }
      _pending += dt;
      if (_pending < 1 / 30 || !mounted) return;
      setState(() {
        _time += _pending;
        _pending = 0;
      });
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fft = ref.watch(radioFakeSignalProvider);
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: SmokeRingsPainter(fft: fft, time: _time),
      ),
    );
  }
}

class _FakeSoundSinusVisualizerState
    extends ConsumerState<FakeSoundSinusVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = _lastTick == null
          ? 0.016
          : (elapsed - _lastTick!).inMicroseconds / 1e6;
      _lastTick = elapsed;
      final playing = ref.read(
        soloudMusicProvider.select(
          (s) => s.playing && s.session?.itemId == 'radio',
        ),
      );
      if (playing && mounted) {
        setState(() => _time += dt);
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fft = ref.watch(radioFakeSignalProvider);
    return CustomPaint(
      size: Size.infinite,
      painter: SoundSinusPainter(fft: fft, time: _time),
    );
  }
}

class _FakeSoundEclipseVisualizerState
    extends ConsumerState<FakeSoundEclipseVisualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _rotation = 0;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = _lastTick == null
          ? 0.016
          : (elapsed - _lastTick!).inMicroseconds / 1e6;
      _lastTick = elapsed;
      final playing = ref.read(
        soloudMusicProvider.select(
          (s) => s.playing && s.session?.itemId == 'radio',
        ),
      );
      if (playing && mounted) {
        setState(() => _rotation += dt * 0.10);
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fft = ref.watch(radioFakeSignalProvider);
    return CustomPaint(
      size: Size.infinite,
      painter: SoundEclipsePainter(fft: fft, rotation: _rotation),
    );
  }
}

/// Visualizador AudioFlux con señal sintética para la radio.
///
/// Usa el MISMO pintor `Waveform` de audio_flux y los MISMOS `ModelParams`
/// que el Music player (`FluxType.waveform`: barras de 3px, spacing 0.5,
/// chunk 1, gradiente del color del skin), pero alimentado con la onda
/// falsa de [radioFakeWaveProvider] en lugar de `DataSources.soloud`
/// (no disponible cuando la radio va por MediaKit). El resultado es
/// pixel-idéntico al del reproductor de música.
class FakeWaveformVisualizer extends ConsumerWidget {
  const FakeWaveformVisualizer({
    super.key,
    required this.color,
    this.expanded = false,
  });
  final Color color;
  final bool expanded;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wave = ref.watch(radioFakeWaveProvider);
    return Waveform(
      dataCallback: ({bool alwaysReturnData = false}) => wave,
      params: ModelParams(
        backgroundColor: Colors.transparent,
        barColor: color,
        barGradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.6)],
        ),
        audioScale: expanded ? 1.6 : 1.4,
        fftParams: const FftParams(
          minBinIndex: 1,
          maxBinIndex: 120,
          fftSmoothing: 0.85,
        ),
        waveformParams: const WaveformPainterParams(
          barsWidth: 3,
          barSpacingScale: 0.5,
          chunkSize: 1,
        ),
      ),
    );
  }
}

class SurferWave extends StatelessWidget {
  const SurferWave({
    super.key,
    required this.phase,
    required this.progress,
    required this.color,
    required this.trackColor,
    this.explosion = 0,
  });
  final double phase;
  final double progress;
  final Color color;
  final Color trackColor;
  final double explosion;
  static double waveY(double x, Size size, double phase) {
    final center = size.height * 0.58;
    final amp = size.height * 0.22;
    final t = phase * 2 * math.pi;
    final u = (x / size.width).clamp(0.0, 1.0);
    return center +
        amp *
            (math.sin(u * math.pi * 2.6 + t) * 0.55 +
                math.sin(u * math.pi * 5.2 - 2 * t) * 0.28 +
                math.sin(u * math.pi * 8 + t) * 0.17);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 72);
        final w = size.width;
        final h = size.height;
        final p = progress.clamp(0.0, 1.0);
        final bx = (p * w).clamp(0.0, w);
        final by = waveY(bx, size, phase);
        const dx = 8.0;
        final y1 = waveY((bx - dx).clamp(0.0, w), size, phase);
        final y2 = waveY((bx + dx).clamp(0.0, w), size, phase);
        final slope = (y2 - y1) / (dx * 2);
        final angle = math.atan(slope) * 0.85;
        final bob = math.sin(phase * 2 * math.pi * 2 + p * math.pi * 4) * 2.5;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: SurferWavePainter(
                  phase: phase,
                  progress: p,
                  color: color,
                  trackColor: trackColor,
                  explosion: explosion,
                ),
              ),
            ),
            Positioned(
              left: (bx - 22).clamp(-6.0, w - 38),
              top: (by - 28 + bob).clamp(-2.0, h - 40),
              child: Transform.rotate(
                angle: angle,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/images/icons/surfer.svg',
                  width: 38,
                  height: 38,
                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
            Positioned(
              left: (bx - 16).clamp(0.0, w - 28),
              top: (by + 6 + bob * 0.3).clamp(0.0, h - 8),
              child: Transform.rotate(
                angle: angle,
                child: Container(
                  width: 28,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SurferWavePainter extends CustomPainter {
  SurferWavePainter({
    required this.phase,
    required this.progress,
    required this.color,
    required this.trackColor,
    this.explosion = 0,
  });
  final double phase;
  final double progress;
  final Color color;
  final Color trackColor;
  final double explosion;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height * 0.58;
    final amp = size.height * 0.22;
    final t = phase * 2 * math.pi;
    const points = 120;
    double yAt(double x) {
      final u = (x / size.width).clamp(0.0, 1.0);
      return center +
          amp *
              (math.sin(u * math.pi * 2.6 + t) * 0.55 +
                  math.sin(u * math.pi * 5.2 - 2 * t) * 0.28 +
                  math.sin(u * math.pi * 8 + t) * 0.17);
    }

    final fill = Path()..moveTo(0, yAt(0));
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      fill.lineTo(x, yAt(x));
    }
    fill
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.12),
          ],
        ).createShader(Offset.zero & size),
    );
    final wave = Path();
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      final y = yAt(x);
      if (i == 0) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    final progressX = (progress * size.width).clamp(0.0, size.width);
    canvas.drawPath(
      wave,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, progressX, size.height));
    canvas.drawPath(
      wave,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
    final foam = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final foamPath = Path();
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      if (x > progressX) break;
      if (i % 3 == 0) {
        final y = yAt(x) - 1.2;
        if (i == 0) {
          foamPath.moveTo(x, y);
        } else {
          foamPath.lineTo(x, y);
        }
      }
    }
    canvas.drawPath(foamPath, foam);
    final bx = progressX;
    final tailLen = (size.width * 0.18).clamp(40.0, 120.0);
    const sprayCount = 14;
    for (var i = 0; i < sprayCount; i++) {
      final em = ((i / sprayCount) + phase) % 1.0;
      final x = bx - em * tailLen;
      if (x < 0) continue;
      final scatterY =
          (math.sin(em * math.pi * 6 + i * 1.7) * 3.5 +
              math.sin(phase * 2 * math.pi * 2 + i) * 2) *
          (0.5 + em * 0.7);
      final y = yAt(x.clamp(0.0, size.width)) + scatterY - 2;
      final fade = 1 - em;
      final alpha = fade * fade * 0.65;
      final r = 1.2 + fade * 2.2;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
    if (explosion > 0 && explosion < 1) {
      final by = yAt(bx);
      const n = 20;
      for (var i = 0; i < n; i++) {
        final a = (i / n) * 2 * math.pi + math.sin(i * 5.3) * 0.3;
        final dist = (22 + (i % 4) * 10) * explosion;
        final px = bx + math.cos(a) * dist;
        final py = by + math.sin(a) * dist;
        final fade = 1 - explosion;
        final r = (1.8 + (i % 3) * 1.2) * (0.7 + 0.3 * explosion);
        canvas.drawCircle(
          Offset(px, py),
          r,
          Paint()
            ..color = Colors.white.withValues(
              alpha: fade.clamp(0.0, 1.0) * 0.9,
            ),
        );
      }
      canvas.drawCircle(
        Offset(bx, by),
        5 + explosion * 26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1 - explosion) * 2.5 + 0.6
          ..color = Colors.white.withValues(alpha: (1 - explosion) * 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SurferWavePainter oldDelegate) => true;
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.effect,
    required this.phase,
    required this.progress,
    required this.color,
    required this.trackColor,
    this.explosion = 0,
  });
  final AudioWaveformEffect effect;
  final double phase;
  final double progress;
  final Color color;
  final Color trackColor;
  final double explosion;
  static const int _bars = 30;
  @override
  void paint(Canvas canvas, Size size) {
    switch (effect) {
      case AudioWaveformEffect.equalizer:
        _paintBars(canvas, size, mirrored: false, animated: true);
        break;
      case AudioWaveformEffect.mirror:
        _paintBars(canvas, size, mirrored: true, animated: true);
        break;
      case AudioWaveformEffect.bars:
        _paintBars(canvas, size, mirrored: false, animated: false);
        break;
      case AudioWaveformEffect.wave:
        _paintWave(canvas, size);
        break;
      case AudioWaveformEffect.surfer:
        _paintWave(canvas, size);
        break;
      case AudioWaveformEffect.audioFlux:
        _paintBars(canvas, size, mirrored: false, animated: true);
        break;
      case AudioWaveformEffect.frequency:
        _paintBars(canvas, size, mirrored: true, animated: true);
        break;
      case AudioWaveformEffect.ledSpectrum:
        _paintBars(canvas, size, mirrored: false, animated: true);
        break;
      case AudioWaveformEffect.soundEclipse:
        _paintBars(canvas, size, mirrored: false, animated: true);
        break;
      case AudioWaveformEffect.soundSinus:
        _paintBars(canvas, size, mirrored: false, animated: true);
        break;
      case AudioWaveformEffect.raymarching:
        _paintBars(canvas, size, mirrored: false, animated: true);
        break;
      case AudioWaveformEffect.smokeRings:
        _paintBars(canvas, size, mirrored: false, animated: true);
        break;
      case AudioWaveformEffect.circularSpectrum:
        _paintBars(canvas, size, mirrored: false, animated: true);
        break;
    }
  }

  double _barHeight(int index, bool animated) {
    if (!animated) {
      final x = index / _bars;
      return 0.4 +
          0.6 *
              (0.5 +
                  0.5 *
                      math.sin(
                        x * math.pi * 5 + math.sin(x * math.pi * 9) * 1.2,
                      ));
    }
    final t = phase * 2 * math.pi;
    final noise =
        math.sin(t + index * 0.9) * 0.5 +
        math.sin(2 * t + index * 0.5) * 0.3 +
        math.sin(3 * t + index * 1.3) * 0.2;
    return (0.5 + noise * 0.5).clamp(0.0, 1.0);
  }

  void _paintBars(
    Canvas canvas,
    Size size, {
    required bool mirrored,
    required bool animated,
  }) {
    const gap = 3.0;
    final bw = (size.width - gap * (_bars - 1)) / _bars;
    final center = size.height / 2;
    final amplitude = size.height * (mirrored ? 0.42 : 0.48);
    for (var i = 0; i < _bars; i++) {
      final h = _barHeight(i, animated);
      final barH = amplitude * (0.10 + h * 0.90);
      final isActive = progress >= (i + 0.5) / _bars;
      final paint = Paint()..color = isActive ? color : trackColor;
      final double top, bottom;
      if (mirrored) {
        top = center - barH / 2;
        bottom = center + barH / 2;
      } else {
        top = center + amplitude * 0.10 - barH;
        bottom = center + amplitude * 0.10;
      }
      final rect = Rect.fromLTRB(
        i * (bw + gap),
        top,
        i * (bw + gap) + bw,
        bottom,
      );
      final radius = Radius.circular(bw / 2);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: radius,
          topRight: radius,
          bottomLeft: mirrored ? radius : Radius.zero,
          bottomRight: mirrored ? radius : Radius.zero,
        ),
        paint,
      );
    }
  }

  void _paintWave(Canvas canvas, Size size) {
    final center = size.height * 0.5;
    final amp = size.height * 0.36;
    final t = phase * 2 * math.pi;
    const points = 100;
    double yAt(double x) {
      final u = x / size.width;
      return center +
          amp *
              (math.sin(u * math.pi * 3 + t) * 0.6 +
                  math.sin(u * math.pi * 5 - 2 * t) * 0.25 +
                  math.sin(u * math.pi * 7 + t) * 0.15);
    }

    final fill = Path()..moveTo(0, center);
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      fill.lineTo(x, yAt(x));
    }
    fill
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    final stroke = Path();
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      final y = yAt(x);
      if (i == 0) {
        stroke.moveTo(x, y);
      } else {
        stroke.lineTo(x, y);
      }
    }
    canvas.drawPath(
      stroke,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    final bx = (progress * size.width).clamp(0.0, size.width);
    double bobAt(double x) =>
        math.sin(x / size.width * math.pi * 4 + phase * 2 * math.pi * 2) * 8 +
        2;
    final by = yAt(bx) + bobAt(bx);
    final tailLen = (size.width * 0.5).clamp(70.0, 240.0);
    const trailCount = 30;
    for (var i = 0; i < trailCount; i++) {
      final em = ((i / trailCount) + phase) % 1.0;
      final x = bx - em * tailLen;
      if (x < -6) continue;
      final scatter =
          (math.sin(em * math.pi * 5 + i * 1.9) * 2.5 +
              math.sin(phase * 2 * math.pi * 2 + i * 2.7) * 2.0) *
          (0.4 + em * 0.9);
      final y = yAt(x.clamp(0.0, size.width)) + bobAt(x) + scatter;
      final fade = 1 - em;
      final alpha = fade * fade * 0.7;
      final radius = 1.4 + fade * 2.6;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }
    canvas.drawCircle(
      Offset(bx, by),
      7,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(bx, by), 4.5, Paint()..color = Colors.white);
    if (explosion > 0 && explosion < 1) {
      const n = 24;
      for (var i = 0; i < n; i++) {
        final angle = (i / n) * 2 * math.pi + math.sin(i * 7.3) * 0.25;
        final dist = (28 + (i % 5) * 8) * explosion;
        final px = bx + math.cos(angle) * dist;
        final py = by + math.sin(angle) * dist;
        final fade = 1 - explosion;
        final radius = (2.2 + (i % 3) * 1.3) * (0.6 + 0.4 * explosion);
        canvas.drawCircle(
          Offset(px, py),
          radius,
          Paint()..color = color.withValues(alpha: fade.clamp(0.0, 1.0) * 0.95),
        );
      }
      canvas.drawCircle(
        Offset(bx, by),
        6 + explosion * 30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1 - explosion) * 3 + 0.5
          ..color = Colors.white.withValues(alpha: (1 - explosion) * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}
