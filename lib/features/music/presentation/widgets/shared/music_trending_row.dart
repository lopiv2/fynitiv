import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../library/application/library_providers.dart';
import '../../../../library/presentation/widgets/poster_card.dart';
import '../../../../../core/widgets/horizontal_scroll_behavior.dart';
import '../../../../../core/widgets/scroll_title.dart';

/// Fila reutilizable y tematizable por [MusicPlayerSkin].
/// Cada skin puede usarla pasando su propio [skin] y un [scroll] con filtros.
class MusicTrendingRow extends ConsumerWidget {
  const MusicTrendingRow({
    super.key,
    required this.scroll,
    required this.skin,
  });

  final MusicScroll scroll;
  final MusicPlayerSkin skin;

  String _titleFor(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'recentlyPlayed':
        return l10n.recentlyPlayed;
      case 'madeForYou':
        return l10n.madeForYou;
      case 'trending':
        return l10n.trending;
      case 'topAlbums':
        return l10n.topAlbums;
      case 'newReleasesMusic':
        return l10n.newReleasesMusic;
      case 'hotlist':
        return l10n.hotlist;
      case 'hiFiPicks':
        return l10n.hiFiPicks;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverUrl = ref.watch(authServerUrlProvider);
    final itemsAsync = ref.watch(musicScrollItemsProvider(scroll));
    return itemsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ScrollTitle(title: _titleFor(context, scroll.titleKey)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ScrollConfiguration(
                behavior: const HorizontalScrollBehavior(),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return SizedBox(
                      width: 140,
                      child: PosterCard(
                        item: item,
                        serverUrl: serverUrl,
                        onTap: () => context.push('/player/${item.id}', extra: item),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
