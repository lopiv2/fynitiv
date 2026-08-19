import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/scale_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/romm_providers.dart';
import '../domain/romm_game.dart';
import '../domain/romm_platform.dart';

/// Juegos de una plataforma concreta de la biblioteca ROMM.
class GameListScreen extends ConsumerWidget {
  const GameListScreen({super.key, required this.platformId});

  final int platformId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final platforms = ref.watch(rommPlatformsProvider).value ?? const <RommPlatform>[];
    final platform =
        platforms.where((p) => p.id == platformId).firstOrNull;
    final games = ref.watch(rommGamesProvider(platformId));
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.back,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      platform?.displayName ?? '...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.retry,
                    onPressed: () =>
                        ref.invalidate(rommGamesProvider(platformId)),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: games.when(
                loading: () => const Center(child: AppLoader()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
                data: (page) => page.items.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noResults,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: page.items.length,
                        itemBuilder: (context, i) =>
                            _GameCard(game: page.items[i]),
                      ),
              ),
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

    return ScaleButton(
      onPressed: () => context.push('/games/rom/${game.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: game.coverSmallUrl != null && game.coverSmallUrl!.isNotEmpty
                  ? Image.network(
                      game.coverSmallUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _GameFallback(game: game, color: fallback),
                    )
                  : _GameFallback(game: game, color: fallback),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            game.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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