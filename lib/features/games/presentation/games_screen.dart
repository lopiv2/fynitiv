import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/scale_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/romm_providers.dart';
import '../domain/romm_platform.dart';

/// Juego online: biblioteca de ROMM (plataformas y juegos).
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
                        : _PlatformGrid(platforms: list),
                  ),
      ),
    );
  }
}

class _PlatformGrid extends ConsumerWidget {
  const _PlatformGrid({required this.platforms});

  final List<RommPlatform> platforms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;

    return ListView(
      padding: const EdgeInsets.all(24),
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.85,
          ),
          itemCount: platforms.length,
          itemBuilder: (context, i) => _PlatformCard(platform: platforms[i]),
        ),
      ],
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

    return ScaleButton(
      onPressed: () => context.push('/games/platform/${platform.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: platform.logoUrl != null && platform.logoUrl!.isNotEmpty
                  ? Image.network(
                      platform.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _PlatformFallback(platform: platform, color: fallback),
                    )
                  : _PlatformFallback(platform: platform, color: fallback),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            platform.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${platform.romCount}',
            style: TextStyle(color: textSecondary, fontSize: 12),
          ),
        ],
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
          const Icon(Icons.videogame_asset_off, color: Colors.white24, size: 48),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}