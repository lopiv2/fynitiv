import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/game_bg_music_controller.dart';
import '../../../core/settings/game_video_controller.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/marquee_text.dart';
import 'widgets/game_video_background.dart';
import '../../../l10n/app_localizations.dart';
import '../application/romm_providers.dart';
import '../data/platform_asset_resolver.dart';
import '../data/platform_led_color.dart';
import '../domain/romm_game.dart';
import '../domain/romm_platform.dart';

/// Juegos de una plataforma concreta - estilo Apple Arcade con Hero y glass.
class GameListScreen extends ConsumerStatefulWidget {
  const GameListScreen({super.key, required this.platformId});

  final int platformId;

  @override
  ConsumerState<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends ConsumerState<GameListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final platforms =
        ref.watch(rommPlatformsProvider).value ?? const <RommPlatform>[];
    final platform = platforms
        .where((p) => p.id == widget.platformId)
        .firstOrNull;
    final games = ref.watch(rommGamesProvider(widget.platformId));
    final skin = ref.watch(skinControllerProvider).value;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final localAsset = platform != null
        ? PlatformAssetResolver.resolve(platform)
        : null;

    return Scaffold(
      body: GameVideoBackground(
        child: CustomScrollView(
          slivers: [
            // AppBar con glassmorphism + Hero logo
            SliverAppBar(
              pinned: true,
              expandedHeight: 220,
              backgroundColor: Colors.transparent,
              leading: IconButton(
                tooltip: l10n.back,
                onPressed: () => context.pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white70,
                ),
              ),
              actions: [
                Consumer(
                  builder: (context, ref, _) {
                    final muted = ref.watch(gameBgMutedProvider);
                    final videoDisabled = ref.watch(gameVideoDisabledProvider);
                    final l10n2 = AppLocalizations.of(context)!;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n2.muteBackgroundMusic,
                          onPressed: () =>
                              ref.read(gameBgMutedProvider.notifier).toggle(),
                          icon: Icon(
                            muted
                                ? Icons.music_off_rounded
                                : Icons.music_note_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                        Tooltip(
                          message: l10n2.muteBackgroundMusic,
                          child: Transform.scale(
                            scale: 0.8,
                            child: Switch.adaptive(
                              value: !muted,
                              onChanged: (v) => ref
                                  .read(gameBgMutedProvider.notifier)
                                  .setMuted(!v),
                              activeThumbColor: Colors.white,
                              activeTrackColor: const Color(0xFF2B7FFF),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: l10n2.disableBackgroundVideo,
                          onPressed: () => ref
                              .read(gameVideoDisabledProvider.notifier)
                              .toggle(),
                          icon: Icon(
                            videoDisabled
                                ? Icons.videocam_off_rounded
                                : Icons.videocam_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                        Tooltip(
                          message: l10n2.disableBackgroundVideo,
                          child: Transform.scale(
                            scale: 0.8,
                            child: Switch.adaptive(
                              value: !videoDisabled,
                              onChanged: (v) => ref
                                  .read(gameVideoDisabledProvider.notifier)
                                  .setDisabled(!v),
                              activeThumbColor: Colors.white,
                              activeTrackColor: const Color(0xFF2B7FFF),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                IconButton(
                  tooltip: l10n.retry,
                  onPressed: () =>
                      ref.invalidate(rommGamesProvider(widget.platformId)),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.15),
                        ],
                      ),
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.fromLTRB(56, 0, 56, 14),
                      centerTitle: true,
                      expandedTitleScale: 1.0,
                      title: _CollapsedPlatformTitle(
                        name: platform?.displayName ?? platform?.name ?? '',
                      ),
                      background: Padding(
                        padding: const EdgeInsets.only(
                          top: 56,
                          left: 24,
                          right: 24,
                          bottom: 24,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Hero(
                            tag: 'platform-logo-${widget.platformId}',
                            createRectTween: (begin, end) =>
                                MaterialRectArcTween(begin: begin, end: end),
                            flightShuttleBuilder:
                                (
                                  flightContext,
                                  animation,
                                  flightDirection,
                                  fromHeroContext,
                                  toHeroContext,
                                ) {
                                  final hero =
                                      flightDirection ==
                                          HeroFlightDirection.push
                                      ? toHeroContext.widget as Hero
                                      : fromHeroContext.widget as Hero;
                                  return FadeTransition(
                                    opacity: animation.drive(
                                      CurveTween(curve: Curves.easeInOut),
                                    ),
                                    child: ScaleTransition(
                                      scale: animation.drive(
                                        Tween<double>(
                                          begin: 0.92,
                                          end: 1.0,
                                        ).chain(
                                          CurveTween(
                                            curve: Curves.easeInOutCubic,
                                          ),
                                        ),
                                      ),
                                      child: hero.child,
                                    ),
                                  );
                                },
                            placeholderBuilder: (context, heroSize, child) =>
                                SizedBox.fromSize(
                                  size: heroSize,
                                  child: Opacity(opacity: 0, child: child),
                                ),
                            child: Material(
                              type: MaterialType.transparency,
                              child: SizedBox(
                                width: 380,
                                height: 380,
                                child: localAsset != null
                                    ? Image.asset(
                                        localAsset,
                                        fit: BoxFit.contain,
                                      )
                                    : platform?.logoUrl != null &&
                                          platform!.logoUrl!.isNotEmpty
                                    ? Image.network(
                                        platform.logoUrl!,
                                        fit: BoxFit.contain,
                                      )
                                    : const Icon(
                                        Icons.videogame_asset,
                                        color: Colors.white70,
                                        size: 96,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Search
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: l10n.searchGameHint,
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: accent.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Games grid
            games.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: AppLoader()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              ),
              data: (page) {
                final filtered = _query.isEmpty
                    ? page.items
                    : page.items
                          .where(
                            (g) => g.name.toLowerCase().contains(
                              _query.toLowerCase(),
                            ),
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          l10n.noResults,
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          childAspectRatio: 0.68,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _GameCard(game: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends ConsumerWidget {
  const _GameCard({required this.game});

  final RommGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final fallback = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final token = ref.watch(rommRepositoryProvider)?.token;
    final headers = token != null && token.isNotEmpty
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;
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

    return AppHover(
      effect: AppHoverEffect.scaleHighlightOutlineLed,
      config: AppHoverConfig.scaleHighlightOutlineLed(
        scale: 1.13,
        radius: BorderRadius.circular(12),
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
      onTap: () => context.push('/games/rom/${game.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Glass card background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.07),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                      border: Border.all(color: Colors.white12),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Cover
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:
                        game.coverSmallUrl != null &&
                            game.coverSmallUrl!.isNotEmpty
                        ? Image.network(
                            game.coverSmallUrl!,
                            fit: BoxFit.cover,
                            headers: headers,
                            errorBuilder: (_, _, _) =>
                                _GameFallback(game: game, color: fallback),
                          )
                        : _GameFallback(game: game, color: fallback),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (context) {
                final hovered = AppHoverScope.of(context)?.hovered ?? false;
                final style = TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                );
                // Marquee siempre activo en tarjetas de juegos cuando hay overflow,
                // independientemente del ajuste global titleMarqueeOnHover.
                return MarqueeText(
                  text: game.name,
                  style: style,
                  isHovered: hovered,
                  enabled: true,
                  textAlign: TextAlign.center,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CollapsedPlatformTitle extends StatelessWidget {
  const _CollapsedPlatformTitle({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final settings = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    // FlexibleSpaceBarSettings.currentExtent va de maxExtent (220) a minExtent (kToolbarHeight + padding)
    const maxExtent = 220.0;
    final minExtent = settings?.minExtent ?? kToolbarHeight;
    final current = settings?.currentExtent ?? maxExtent;
    final delta = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final t = ((current - minExtent) / delta).clamp(0.0, 1.0);
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    // Sin nombre no muestra nada para evitar flash vacío
    if (name.isEmpty) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity,
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GameFallback extends StatelessWidget {
  const _GameFallback({required this.game, required this.color});

  final RommGame game;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final name = game.name;
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: const TextStyle(color: Colors.white70, fontSize: 24),
      ),
    );
  }
}
