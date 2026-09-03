import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/game_bg_music_controller.dart';
import '../../../core/settings/game_video_controller.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../core/widgets/scroll_title.dart';
import 'widgets/game_content_row.dart';
import 'widgets/game_video_background.dart';
import '../../../l10n/app_localizations.dart';
import '../application/romm_providers.dart';
import '../data/platform_asset_resolver.dart';
import '../data/platform_category.dart';
import '../data/platform_led_color.dart';
import '../domain/romm_platform.dart';

/// Juego online: estilo Steam / Apple Arcade
/// Grid responsive + filtros + búsqueda + Hero + glassmorphism con fallback.
class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  String _query = '';
  PlatformCategory _filter = PlatformCategory.all;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(rommAuthProvider);
    final config = ref.watch(rommConfigProvider);
    final platforms = ref.watch(rommPlatformsProvider);
    final skin = ref.watch(skinControllerProvider).value;
    final topPadding = libraryPageTopPadding(context, skin);

    final content = auth.loading
            ? const Center(child: AppLoader())
            : !auth.authenticated
            ? _NoServer(onConfigure: () => context.go('/settings'))
            : config.isLoading
            ? const Center(child: AppLoader())
            : platforms.when(
                loading: () => const Center(child: AppLoader()),
                error: (e, _) => _ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(rommPlatformsProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return _EmptyView(
                      message: l10n.gamesEmpty,
                      onConfigure: () => context.go('/settings'),
                    );
                  }
                  // Filtrado por búsqueda + categoría
                  final filtered = list.where((p) {
                    final asset = PlatformAssetResolver.resolve(p);
                    final cat = categoryForPlatform(asset, p.slug);
                    final matchesCategory =
                        _filter == PlatformCategory.all || cat == _filter;
                    if (!matchesCategory) return false;
                    if (_query.isEmpty) return true;
                    final q = _query.toLowerCase();
                    return p.displayName.toLowerCase().contains(q) ||
                        p.slug.toLowerCase().contains(q) ||
                        p.name.toLowerCase().contains(q);
                  }).toList();

                  // Datos para “Continuar jugando” (ROMs con last_played, ordenados por API)
                  final continueAsync = ref.watch(rommContinuePlayingProvider);
                  final token = ref.watch(rommRepositoryProvider)?.token;
                  final headers = token != null && token.isNotEmpty
                      ? <String, String>{'Authorization': 'Bearer $token'}
                      : null;

                  return FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: CustomScrollView(
                      slivers: [
                      SliverToBoxAdapter(
                        child: _HeroHeader(
                          totalPlatforms: list.length,
                          totalGames: list.fold<int>(
                            0,
                            (s, p) => s + p.romCount,
                          ),
                          query: _query,
                          onQueryChanged: (v) => setState(() => _query = v),
                          controller: _searchController,
                        ),
                      ),
                      // Fila horizontal “Continuar jugando” reutilizando ContentRow/HoverPlayCard
                      SliverToBoxAdapter(
                        child: continueAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (games) {
                            if (games.isEmpty) return const SizedBox.shrink();
                            return GameContentRow(
                              title: l10n.continuePlaying,
                              games: games,
                              headers: headers,
                              // Estilo foto con AppHover universal (hover/relajado) según diseño
                              height: 280,
                              cardWidth: 220,
                              useContinueStyle: true,
                              onGameTap: (g) =>
                                  context.push('/games/rom/${g.id}'),
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                          child: ScrollTitle(title: l10n.platforms),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _FilterChips(
                          selected: _filter,
                          onSelected: (c) => setState(() => _filter = c),
                          counts: _countsByCategory(list),
                        ),
                      ),
                      if (filtered.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                l10n.noResultsForQuery(_query),
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.crossAxisExtent;
                              int crossCount;
                              if (w < 500) {
                                crossCount = 2;
                              } else if (w < 800) {
                                crossCount = 3;
                              } else if (w < 1100) {
                                crossCount = 4;
                              } else if (w < 1400) {
                                crossCount = 5;
                              } else {
                                crossCount = 6;
                              }
                              return SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossCount,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      childAspectRatio: 0.95,
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => _PlatformCard(
                                    platform: filtered[i],
                                    heroTag: 'platform-logo-${filtered[i].id}',
                                  ),
                                  childCount: filtered.length,
                                ),
                              );
                            },
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: Text(
                            l10n.platformsAndGamesCount(
                              filtered.length,
                              filtered.fold<int>(0, (s, p) => s + p.romCount),
                            ),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  );
                },
              );
    return Scaffold(
      body: GameVideoBackground(
        child: Column(
          children: [
            SizedBox(height: topPadding),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Map<PlatformCategory, int> _countsByCategory(List<RommPlatform> list) {
    final m = <PlatformCategory, int>{
      for (var c in PlatformCategory.values) c: 0,
    };
    m[PlatformCategory.all] = list.length;
    for (final p in list) {
      final cat = categoryForPlatform(PlatformAssetResolver.resolve(p), p.slug);
      m[cat] = (m[cat] ?? 0) + 1;
    }
    return m;
  }
}

class _HeroHeader extends ConsumerWidget {
  const _HeroHeader({
    required this.totalPlatforms,
    required this.totalGames,
    required this.query,
    required this.onQueryChanged,
    required this.controller,
  });

  final int totalPlatforms;
  final int totalGames;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;

    // Glassmorphism con fallback a DashboardBackground si falla el blur
    Widget headerContent = Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (skin?.accent ?? const Color(0xFF2B7FFF)).withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sports_esports,
                  color: skin?.accent ?? const Color(0xFF2B7FFF),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.games,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.gamesSubtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.platformsAndGamesCount(totalPlatforms, totalGames),
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Botones silenciar música / video arriba a la derecha
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _BgMusicSwitchCompact(),
                  SizedBox(width: 6),
                  _BgVideoSwitchCompact(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: l10n.searchPlatformHint,
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white38,
                size: 20,
              ),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                    )
                  : null,
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
                  color: (skin?.accent ?? const Color(0xFF2B7FFF)).withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Intento glassmorphism: si el device no soporta BackdropFilter, el fallback es el Container de arriba sin blur
    // Envuelto en ClipRRect + BackdropFilter; si falla, se ve solo el Container (dashboardBackground detrás)
    // El padding superior global ya lo aporta GamesScreen (libraryPageTopPadding),
    // aquí solo deixamos 16 de respiración.
    const topInset = 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topInset, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: headerContent,
        ),
      ),
    );
  }
}

// ignore: unused_element - se mantiene por si se reutiliza bajo el buscador
class _BgMusicSwitch extends ConsumerWidget {
  const _BgMusicSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final muted = ref.watch(gameBgMutedProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            muted ? Icons.music_off_rounded : Icons.music_note_rounded,
            color: Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.muteBackgroundMusic,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Switch.adaptive(
            value: !muted,
            onChanged: (v) =>
                ref.read(gameBgMutedProvider.notifier).setMuted(!v),
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF2B7FFF),
          ),
        ],
      ),
    );
  }
}

class _BgMusicSwitchCompact extends ConsumerWidget {
  const _BgMusicSwitchCompact();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final muted = ref.watch(gameBgMutedProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: l10n.muteBackgroundMusic,
            child: Icon(
              muted ? Icons.music_off_rounded : Icons.music_note_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: l10n.muteBackgroundMusic,
            child: Transform.scale(
              scale: 0.8,
              child: Switch.adaptive(
                value: !muted,
                onChanged: (v) =>
                    ref.read(gameBgMutedProvider.notifier).setMuted(!v),
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF2B7FFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BgVideoSwitchCompact extends ConsumerWidget {
  const _BgVideoSwitchCompact();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final disabled = ref.watch(gameVideoDisabledProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: l10n.disableBackgroundVideo,
            child: Icon(
              disabled ? Icons.videocam_off_rounded : Icons.videocam_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: l10n.disableBackgroundVideo,
            child: Transform.scale(
              scale: 0.8,
              child: Switch.adaptive(
                value: !disabled,
                onChanged: (v) => ref
                    .read(gameVideoDisabledProvider.notifier)
                    .setDisabled(!v),
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF2B7FFF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onSelected,
    required this.counts,
  });

  final PlatformCategory selected;
  final ValueChanged<PlatformCategory> onSelected;
  final Map<PlatformCategory, int> counts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final cat in PlatformCategory.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${cat.label} (${counts[cat] ?? 0})'),
                selected: selected == cat,
                onSelected: (_) => onSelected(cat),
                selectedColor: Colors.white.withValues(alpha: 0.14),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                labelStyle: TextStyle(
                  color: selected == cat ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: selected == cat ? Colors.white24 : Colors.white10,
                ),
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }
}

class _PlatformCard extends ConsumerWidget {
  const _PlatformCard({required this.platform, required this.heroTag});

  final RommPlatform platform;
  final String heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final textSecondary = skin?.textSecondary ?? Colors.white70;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final token = ref.watch(rommRepositoryProvider)?.token;
    final headers = token != null && token.isNotEmpty
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;

    final localAsset = PlatformAssetResolver.resolve(platform);

    Widget logoContent;
    if (localAsset != null) {
      logoContent = Image.asset(
        localAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            _PlatformFallback(platform: platform, color: Colors.transparent),
      );
    } else if (platform.logoUrl != null && platform.logoUrl!.isNotEmpty) {
      logoContent = _PlatformLogoImage(
        url: platform.logoUrl!,
        headers: headers,
        fallback: _PlatformFallback(
          platform: platform,
          color: Colors.transparent,
        ),
      );
    } else {
      logoContent = _PlatformFallback(
        platform: platform,
        color: Colors.transparent,
      );
    }

    // Hero visible y más lento: vuelo con arc + fade/scale, placeholder transparente
    final heroLogo = Hero(
      tag: heroTag,
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
            final hero = flightDirection == HeroFlightDirection.push
                ? toHeroContext.widget as Hero
                : fromHeroContext.widget as Hero;
            return FadeTransition(
              opacity: animation.drive(CurveTween(curve: Curves.easeInOut)),
              child: ScaleTransition(
                scale: animation.drive(
                  Tween<double>(
                    begin: 0.92,
                    end: 1.0,
                  ).chain(CurveTween(curve: Curves.easeInOutCubic)),
                ),
                child: hero.child,
              ),
            );
          },
      placeholderBuilder: (context, heroSize, child) => SizedBox.fromSize(
        size: heroSize,
        child: Opacity(opacity: 0, child: child),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Center(child: logoContent),
        ),
      ),
    );

    // Card con glassmorphism + fallback a DashboardBackground si blur falla
    final cardChild = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(margin: const EdgeInsets.all(10), child: heroLogo),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  platform.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        l10n.gamesCount(platform.romCount),
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: textSecondary.withValues(alpha: 0.6),
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Glass card con blur; fallback es el mismo card sin blur (DashboardBackground detrás)
    // RepaintBoundary evita que el blur se recalcule en cada frame del hover
    final glassCard = RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: cardChild,
        ),
      ),
    );

    final ledColor = platformLedColor(platform, fallback: accent);
    // Transparente en reposo (glass), sólida al hacer hover para que el glow resalte
    final solidHover = const Color(0xFF1E2633);
    return AppHover(
      effect: AppHoverEffect.scaleHighlightOutlineLed,
      config: AppHoverConfig.scaleHighlightOutlineLed(
        scale: 1.04,
        radius: BorderRadius.circular(16),
        duration: const Duration(milliseconds: 180),
        outlineHoveredWidth: 1.8,
        outlineHoveredColor: ledColor,
        ledHoveredColor: ledColor,
        ledBlurRadius: 22,
        ledSpreadRadius: 2,
        highlightNormal: Colors.transparent,
        highlightHovered: solidHover,
      ),
      onTap: () =>
          context.push('/games/platform/${platform.id}', extra: platform),
      playSoundOnHover: true,
      child: glassCard,
    );
  }
}

class _PlatformLogoImage extends StatelessWidget {
  const _PlatformLogoImage({
    required this.url,
    required this.headers,
    required this.fallback,
  });
  final String url;
  final Map<String, String>? headers;
  final Widget fallback;
  bool get _isSvg =>
      url.toLowerCase().endsWith('.svg') || url.toLowerCase().contains('.svg?');
  @override
  Widget build(BuildContext context) {
    if (_isSvg) {
      return SvgPicture.network(
        url,
        headers: headers,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => fallback,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers ?? const {},
      fit: BoxFit.contain,
      placeholder: (context, _) => const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorBuilder: (context, error, stackTrace) => fallback,
      memCacheWidth: 300,
      maxWidthDiskCache: 300,
      fadeInDuration: const Duration(milliseconds: 150),
      useOldImageOnUrlChange: true,
    );
  }
}

class _PlatformFallback extends StatelessWidget {
  const _PlatformFallback({required this.platform, required this.color});
  final RommPlatform platform;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final name = platform.displayName;
    return Container(
      color: color.withValues(alpha: 0.0),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
        style: const TextStyle(color: Colors.white70, fontSize: 28),
      ),
    );
  }
}

class _NoServer extends StatelessWidget {
  const _NoServer({required this.onConfigure});
  final VoidCallback onConfigure;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_esports, color: Colors.white24, size: 56),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.gamesNoServer,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onConfigure,
            icon: const Icon(Icons.settings, size: 18),
            label: Text(l10n.gamesConfigure),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message, required this.onConfigure});
  final String message;
  final VoidCallback onConfigure;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videogame_asset_off,
            color: Colors.white24,
            size: 48,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onConfigure,
            icon: const Icon(Icons.settings, size: 18),
            label: Text(l10n.gamesConfigure),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final msg = '$error';
    final isForbidden =
        msg.contains('403') || msg.toLowerCase().contains('forbidden');
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForbidden ? Icons.lock_outline : Icons.error_outline,
              color: Colors.white38,
              size: 48,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SelectableText(
                isForbidden ? l10n.rommForbidden(msg) : msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.retry),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings, size: 16),
              label: Text(l10n.gamesConfigure),
            ),
          ],
        ),
      ),
    );
  }
}
