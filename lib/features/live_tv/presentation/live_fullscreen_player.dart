import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/window/app_window.dart';
import '../../../l10n/app_localizations.dart';
import '../application/live_state.dart';
import '../application/live_tv_player_provider.dart';
import '../application/live_tv_ui.dart';
import 'widgets/live_tv_utils.dart';

/// Reproductor a pantalla completa que adopta el MISMO motor compartido.
class LiveTvFullscreenPlayer extends ConsumerStatefulWidget {
  const LiveTvFullscreenPlayer({super.key});

  @override
  ConsumerState<LiveTvFullscreenPlayer> createState() =>
      _LiveTvFullscreenPlayerState();
}

class _LiveTvFullscreenPlayerState
    extends ConsumerState<LiveTvFullscreenPlayer> {
  double _volume = 100;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    AppWindow.setFullscreen(true);
    ref.read(liveTvUiProvider.notifier).setFullscreen(true);
    ref.read(liveTvPlayerProvider.notifier).setMuted(false);
    _volume = 100;
  }

  @override
  void dispose() {
    AppWindow.setFullscreen(false);
    ref.read(liveTvUiProvider.notifier).setFullscreen(false);
    ref.read(liveTvPlayerProvider.notifier).setMuted(true);
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    ref.read(liveTvPlayerProvider.notifier).setMuted(_muted);
  }

  void _setVolume(double v) {
    setState(() => _volume = v);
    ref.read(liveTvPlayerProvider.notifier).setMuted(v == 0);
    ref.read(liveTvPlayerProvider.notifier).player.setVolume(v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(liveTvStateProvider);
    final channel = state.selectedChannel;
    final program = channel != null
        ? state.currentProgramOf(channel.id, DateTime.now())
        : null;
    final controller = ref.read(liveTvPlayerProvider.notifier).videoController;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          context.pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Video(controller: controller, controls: NoVideoControls),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: l10n.back,
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                channel?.name ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                program?.title ?? '',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFF5252)),
                          ),
                          child: Text(
                            l10n.liveTvNow,
                            style: const TextStyle(
                              color: Color(0xFFFF7A7A),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: _muted ? l10n.liveTvUnmute : l10n.liveTvMute,
                            onPressed: _toggleMute,
                            icon: Icon(
                              _muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _volume,
                              onChanged: _setVolume,
                              activeColor: Colors.white,
                              inactiveColor: Colors.white24,
                            ),
                          ),
                          Text(
                            formatProgramRange(
                              program?.startTime,
                              program?.endTime,
                            ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
