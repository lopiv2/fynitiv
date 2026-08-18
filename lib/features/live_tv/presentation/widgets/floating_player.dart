import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/live_state.dart';
import '../../application/live_tv_player_provider.dart';
import '../../application/live_tv_ui.dart';

/// Reproductor flotante: ventana arrastrable y redimensionable que muestra el
/// MISMO motor de vídeo compartido, sobre la EPG.
class FloatingPlayer extends ConsumerStatefulWidget {
  const FloatingPlayer({
    super.key,
    required this.now,
    required this.onExpand,
  });

  final DateTime now;
  final VoidCallback onExpand;

  @override
  ConsumerState<FloatingPlayer> createState() => _FloatingPlayerState();
}

class _FloatingPlayerState extends ConsumerState<FloatingPlayer> {
  Offset _position = const Offset(24, 24);
  Size _size = const Size(340, 192);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(liveTvStateProvider);
    final controller = ref.read(liveTvPlayerProvider.notifier).videoController;
    final channel = state.selectedChannel;
    final program =
        channel != null ? state.currentProgramOf(channel.id, widget.now) : null;
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _position += d.delta),
        child: Container(
          width: _size.width,
          height: _size.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Video(
                    controller: controller,
                    controls: NoVideoControls,
                    fit: BoxFit.contain,
                    fill: const Color(0xFF000000),
                  ),
                ),
                // Barra superior con la info del programa (también arrastra).
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                channel?.name ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                program?.title ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.liveTvExpand,
                          onPressed: widget.onExpand,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.liveTvClose,
                          onPressed: () => ref
                              .read(liveTvUiProvider.notifier)
                              .setFloating(false),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Asa de redimensionado abajo a la derecha.
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onPanUpdate: (d) => setState(() {
                      _size = Size(
                        (_size.width + d.delta.dx).clamp(200, 900),
                        (_size.height + d.delta.dy).clamp(120, 600),
                      );
                    }),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
