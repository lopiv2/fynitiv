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
  double _volume = 1.0;
  bool _muted = false;
  late final LiveTvUiController _ui;
  late final LiveTvPlayerController _player;

  @override
  void initState() {
    super.initState();
    AppWindow.setFullscreen(true);
    _volume = 1.0;
    // Se capturan los notifiers en initState (lectura segura) para poder
    // usarlos en dispose, donde `ref` ya no es seguro.
    _ui = ref.read(liveTvUiProvider.notifier);
    _player = ref.read(liveTvPlayerProvider.notifier);
    // No se puede modificar providers durante initState (build); se difiere
    // al primer frame para que la transición de ruta no reviente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ui.setFullscreen(true);
      _player.setMuted(false);
    });
  }

  @override
  void dispose() {
    AppWindow.setFullscreen(false);
    // Dispose ocurre durante el desmontaje; las notificaciones a providers se
    // difieren para no modificarlos en pleno build/teardown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ui.setFullscreen(false);
      _player.setMuted(true);
    });
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    ref.read(liveTvPlayerProvider.notifier).setMuted(_muted);
  }

  void _setVolume(double v) {
    setState(() => _volume = v);
    ref.read(liveTvPlayerProvider.notifier).setMuted(v == 0);
    ref.read(liveTvPlayerProvider.notifier).player.setVolume(v * 100);
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
              child: Video(
                controller: controller,
                controls: NoVideoControls,
                fit: BoxFit.contain,
                fill: const Color(0xFF000000),
              ),
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
                        if (channel?.logoUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 88,
                                height: 38,
                                child: Image.network(
                                  channel!.logoUrl!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
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
