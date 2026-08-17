import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/live_state.dart';
import '../../application/live_tv_player_provider.dart';
import '../../application/live_tv_ui.dart';
import '../widgets/live_tv_utils.dart';

/// Panel superior: preview en directo del canal seleccionado + info del
/// programa. Si [ui.floating] o [ui.fullscreen] están activos, no pinta el
/// vídeo (solo hay un Video activo a la vez).
class LivePreview extends ConsumerStatefulWidget {
  const LivePreview({
    super.key,
    required this.now,
    required this.onFullscreen,
    required this.onClose,
  });

  final DateTime now;
  final VoidCallback onFullscreen;
  final VoidCallback onClose;

  @override
  ConsumerState<LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends ConsumerState<LivePreview> {
  bool _muted = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(liveTvStateProvider);
    final ui = ref.watch(liveTvUiProvider);
    final playerState = ref.watch(liveTvPlayerProvider);
    final controller = ref.read(liveTvPlayerProvider.notifier).videoController;
    final channel = state.selectedChannel;
    final program =
        channel != null ? state.currentProgramOf(channel.id, widget.now) : null;
    final hideVideo = ui.floating || ui.fullscreen;

    ref.listen<Object?>(
      liveTvStateProvider.select((s) => s.selectedChannelId),
      (_, _) {
        if (!mounted) return;
        setState(() => _muted = true);
      },
    );

    return Container(
      height: 178,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        border: const Border(bottom: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.all(12),
      child: channel == null
          ? Center(
              child: Text(
                l10n.liveTvSelectChannel,
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: hideVideo
                        ? Container(
                            color: Colors.black,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.live_tv,
                              color: Colors.white24,
                              size: 40,
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              Video(
                                controller: controller,
                                controls: NoVideoControls,
                              ),
                              if (playerState.buffering)
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white54,
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFFF5252)
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                            child: Text(
                              l10n.liveTvNow,
                              style: const TextStyle(
                                color: Color(0xFFFF7A7A),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        program?.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        formatProgramRange(program?.startTime, program?.endTime),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if ((program?.description ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            program!.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          IconButton(
                            tooltip: _muted
                                ? l10n.liveTvUnmute
                                : l10n.liveTvMute,
                            onPressed: () {
                              setState(() => _muted = !_muted);
                              ref
                                  .read(liveTvPlayerProvider.notifier)
                                  .setMuted(_muted);
                            },
                            icon: Icon(
                              _muted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.liveTvMinimize,
                            onPressed: () =>
                                ref.read(liveTvUiProvider.notifier).setFloating(true),
                            icon: const Icon(
                              Icons.picture_in_picture_alt_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.liveTvExpand,
                            onPressed: widget.onFullscreen,
                            icon: const Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.liveTvClose,
                            onPressed: widget.onClose,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
