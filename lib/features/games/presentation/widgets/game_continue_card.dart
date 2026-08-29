import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/app_hover.dart';
import '../../data/platform_asset_resolver.dart';
import '../../data/platform_led_color.dart';
import '../../domain/romm_game.dart';
import '../../domain/romm_platform.dart';

/// Card para “Continuar jugando” estilo foto (hover/relajado) usando `AppHover` universal.
class GameContinueCard extends ConsumerWidget {
  const GameContinueCard({
    super.key,
    required this.game,
    this.headers,
    this.onTap,
    this.onHoverChanged,
    this.onPointerSignal,
    this.overlayBelowEntry,
  });

  final RommGame game;
  final Map<String, String>? headers;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onHoverChanged;
  final ValueChanged<PointerSignalEvent>? onPointerSignal;
  final OverlayEntry? Function()? overlayBelowEntry;

  String _formatLastPlayed(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd/MM HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = game.coverLargeUrl?.isNotEmpty == true
        ? game.coverLargeUrl!
        : (game.coverSmallUrl ?? '');
    final platformLabel = game.platformDisplayName.isNotEmpty
        ? game.platformDisplayName.toUpperCase()
        : game.platformSlug.toUpperCase();
    final fakePlatform = RommPlatform(
      id: game.platformId,
      slug: game.platformSlug,
      name: game.platformDisplayName,
      romCount: 0,
    );
    final ledColor = platformLedColor(
      fakePlatform,
      fallback: const Color(0xFF2ED9A3),
    );
    final lastPlayedStr = _formatLastPlayed(game.lastPlayed);
    final timeStr = lastPlayedStr.isNotEmpty ? lastPlayedStr : '—';

    return AppHover(
      effect: AppHoverEffect.scaleHighlightOutlineLed,
      config: AppHoverConfig.scaleHighlightOutlineLed(
        scale: 1.13,
        radius: BorderRadius.circular(16),
        duration: const Duration(milliseconds: 180),
        outlineHoveredWidth: 1.6,
        outlineHoveredColor: const Color(0xFF2ED9A3),
        ledHoveredColor: ledColor,
        ledBlurRadius: 20,
        ledSpreadRadius: 1.2,
        highlightNormal: Colors.transparent,
        highlightHovered: const Color(0xFF1A2535),
      ),
      playSoundOnHover: true,
      onTap: onTap ?? () {},
      child: Builder(
        builder: (context) {
          final hovered = AppHoverScope.of(context)?.hovered ?? false;
          return _HoverReporter(
            onChanged: onHoverChanged,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141E2F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (cover.isNotEmpty)
                          Image.network(
                            cover,
                            fit: BoxFit.cover,
                            headers: headers ?? const {},
                            errorBuilder: (_, _, _) =>
                                Container(color: const Color(0xFF0F1A2B)),
                          )
                        else
                          Container(color: const Color(0xFF0F1A2B)),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Builder(
                              builder: (context) {
                                final logoAsset = PlatformAssetResolver.resolve(
                                  fakePlatform,
                                );
                                if (logoAsset != null) {
                                  return Image.asset(
                                    logoAsset,
                                    height: 16,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => Text(
                                      platformLabel.isEmpty
                                          ? 'PLAYSTATION'
                                          : platformLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  );
                                }
                                return Text(
                                  platformLabel.isEmpty
                                      ? 'PLAYSTATION'
                                      : platformLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: hovered ? 1 : 0,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.38),
                            child: Center(
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2ED9A3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastPlayedStr.isNotEmpty
                              ? 'Jugado: $lastPlayedStr'
                              : 'Slot 1: ${game.platformDisplayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF2ED9A3),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: Colors.white38,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            if (game.lastPlayed != null)
                              const Text(
                                '—',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HoverReporter extends StatefulWidget {
  const _HoverReporter({required this.child, this.onChanged});
  final Widget child;
  final ValueChanged<bool>? onChanged;
  @override
  State<_HoverReporter> createState() => _HoverReporterState();
}

class _HoverReporterState extends State<_HoverReporter> {
  bool? _last;
  @override
  Widget build(BuildContext context) {
    final hovered = AppHoverScope.of(context)?.hovered ?? false;
    if (_last != hovered) {
      _last = hovered;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.onChanged != null) widget.onChanged!(hovered);
      });
    }
    return widget.child;
  }
}
