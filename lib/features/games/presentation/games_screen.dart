import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/scale_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/romm_providers.dart';
import '../domain/romm_platform.dart';

/// Juego online: biblioteca de ROMM en modo consola (slider de plataformas).
/// No carga todos los juegos de golpe para evitar 403/overhead con bibliotecas grandes.
class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(rommAuthProvider);
    final config = ref.watch(rommConfigProvider);
    final platforms = ref.watch(rommPlatformsProvider);
    return Scaffold(
      body: DashboardBackground(
        child: auth.loading
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
                data: (list) => list.isEmpty
                    ? _EmptyView(
                        message: l10n.gamesEmpty,
                        onConfigure: () => context.go('/settings'),
                      )
                    : _PlatformSlider(platforms: list),
              ),
      ),
    );
  }
}

class _HorizontalPlatformScrollBehavior extends MaterialScrollBehavior {
  const _HorizontalPlatformScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers =>
      const <LogicalKeyboardKey>{};
}

/// Slider horizontal de plataformas al estilo consola de RomM:
/// cada consola muestra logo, nombre y nÃºmero de juegos.
/// Scroll mejorado: arrastre con ratÃ³n/trackpad, rueda sin Shift, botones laterales y scrollbar.
class _PlatformSlider extends ConsumerStatefulWidget {
  const _PlatformSlider({required this.platforms});

  final List<RommPlatform> platforms;

  @override
  ConsumerState<_PlatformSlider> createState() => _PlatformSliderState();
}

class _PlatformSliderState extends ConsumerState<_PlatformSlider> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Text(
          l10n.games,
          style: TextStyle(
            color: textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.gamesSubtitle,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ScrollConfiguration(
                  behavior: const _HorizontalPlatformScrollBehavior(),
                  child: Scrollbar(
                    controller: _controller,
                    thumbVisibility: false,
                    trackVisibility: false,
                    child: ListView.separated(
                      controller: _controller,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemCount: widget.platforms.length,
                      itemBuilder: (context, i) =>
                          _PlatformCard(platform: widget.platforms[i]),
                    ),
                  ),
                ),
              ),
              if (widget.platforms.length > 3) ...[
                Positioned(
                  left: 0,
                  child: _ScrollArrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _scrollBy(-320),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: _ScrollArrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _scrollBy(320),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${widget.platforms.length} plataformas Â· ${widget.platforms.fold<int>(0, (s, p) => s + p.romCount)} juegos',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }
}

class _ScrollArrow extends StatelessWidget {
  const _ScrollArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.45),
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _PlatformCard extends ConsumerWidget {
  const _PlatformCard({required this.platform});

  final RommPlatform platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final textSecondary = skin?.textSecondary ?? Colors.white70;
    final fallback = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final token = ref.watch(rommRepositoryProvider)?.token;
    final headers = token != null && token.isNotEmpty
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;

    return ScaleButton(
      onPressed: () => context.push('/games/platform/${platform.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Container(
                  color: fallback,
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.center,
                  child: platform.logoUrl != null && platform.logoUrl!.isNotEmpty
                      ? _PlatformLogoImage(
                          url: platform.logoUrl!,
                          headers: headers,
                          fallback: _PlatformFallback(
                            platform: platform,
                            color: fallback,
                          ),
                        )
                      : _PlatformFallback(platform: platform, color: fallback),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platform.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: fallback.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${platform.romCount} juegos',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      color: color,
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
                isForbidden
                    ? 'Acceso denegado (403). Verifica permisos del usuario ROMM en el servidor.\n\nDetalle: $msg'
                    : msg,
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
