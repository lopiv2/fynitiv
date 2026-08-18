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
      height: 240,
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vídeo limitado en ancho, pegado a la izquierda. Sin Expanded:
                // no empuja el panel de info hacia el borde derecho.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
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
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              // media_kit necesita un tamaño TIGHT y
                              // explícito para redimensionar su textura
                              // Direct3D correctamente. Sin esto, en
                              // ciertas cadenas de layout (Row sin
                              // stretch + Stack expand) el resize interno
                              // se queda "pegado" a 0x0 y la textura nunca
                              // recibe contenido visible, aunque el player
                              // siga reproduciendo.
                              return SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Video(
                                      controller: controller,
                                      controls: NoVideoControls,
                                      fit: BoxFit.contain,
                                      fill: const Color(0xFF000000),
                                    ),
                                    if (playerState.buffering)
                                      const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white54,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    if (playerState.error != null)
                                      Center(
                                        child: Text(
                                          '${playerState.error}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 620,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (channel.logoUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  width: 64,
                                  height: 28,
                                  child: Image.network(
                                    channel.logoUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
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
                const Spacer(),
              ],
            ),
    );
  }
}