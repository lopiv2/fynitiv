import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/hover_play_card.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../domain/romm_game.dart';

/// Tarjeta póster para un `RommGame`, reutiliza `HoverPlayCard` igual que
/// `PosterCard` en la app Jellyfin (fila horizontal con hover extension).
class GamePosterCard extends ConsumerStatefulWidget {
  const GamePosterCard({
    super.key,
    required this.game,
    this.headers,
    this.onTap,
    this.onImageTap,
    this.hoverExtension = true,
    this.onHoverChanged,
    this.onPointerSignal,
    this.overlayBelowEntry,
  });

  final RommGame game;
  final Map<String, String>? headers;
  final VoidCallback? onTap;
  final VoidCallback? onImageTap;
  final bool hoverExtension;
  final ValueChanged<bool>? onHoverChanged;
  final ValueChanged<PointerSignalEvent>? onPointerSignal;
  final OverlayEntry? Function()? overlayBelowEntry;

  @override
  ConsumerState<GamePosterCard> createState() => _GamePosterCardState();
}

class _GamePosterCardState extends ConsumerState<GamePosterCard> {
  bool _isHovered = false;

  void _setHovered(bool v) {
    if (_isHovered == v) return;
    setState(() => _isHovered = v);
  }

  @override
  Widget build(BuildContext context) {
    final skin = ref.watch(skinControllerProvider).value;
    final radius = skin?.cardBorderRadius ?? 10;
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final showExtension =
        widget.hoverExtension && (skin?.cardHoverExtension ?? false);
    final marqueeEnabled = skin?.titleMarqueeOnHover ?? false;

    final title = widget.game.name;
    final subtitle = widget.game.platformDisplayName.isNotEmpty
        ? widget.game.platformDisplayName
        : null;
    final cover = widget.game.coverSmallUrl ?? widget.game.coverLargeUrl;

    final cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: AspectRatio(
            aspectRatio: 2 / 2,
            child: HoverPlayRadius(
              radius: radius * 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null && cover.isNotEmpty)
                    Image.network(
                      cover,
                      fit: BoxFit.cover,
                      headers: widget.headers ?? const {},
                      errorBuilder: (_, _, _) => _GamePosterFallback(
                        game: widget.game,
                        color: fallbackColor,
                      ),
                    )
                  else
                    _GamePosterFallback(
                      game: widget.game,
                      color: fallbackColor,
                    ),
                  // Subtle border like platform cards
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius * 2),
                        border: Border.all(color: Colors.white12, width: 0.7),
                      ),
                    ),
                  ),
                  if (widget.game.lastPlayed != null)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!showExtension) ...[
          const SizedBox(height: 6),
          marqueeEnabled
              ? MarqueeText(
                  text: title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  isHovered: _isHovered,
                  enabled: true,
                )
              : Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: skin?.textSecondary ?? Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ],
    );

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: HoverPlayCard(
        title: title,
        subtitle: subtitle,
        onPlay: widget.onTap ?? () {},
        onImageTap: widget.onImageTap,
        showExtension: showExtension,
        onHoverChanged: (v) {
          _setHovered(v);
          widget.onHoverChanged?.call(v);
        },
        onPointerSignal: widget.onPointerSignal,
        overlayBelowEntry: widget.overlayBelowEntry,
        resume: widget.game.lastPlayed != null,
        year: null,
        overview: widget.game.summary,
        child: cardContent,
      ),
    );
  }
}

class _GamePosterFallback extends StatelessWidget {
  const _GamePosterFallback({required this.game, required this.color});
  final RommGame game;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        game.name.isEmpty ? '?' : game.name.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
