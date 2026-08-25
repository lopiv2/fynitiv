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
              child: Row(
                children: [
                  Expanded(child: ScrollTitle(title: _titleFor(context, scroll.titleKey))),
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _MusicScrollShowAllScreen(title: _titleFor(context, scroll.titleKey), items: items, serverUrl: serverUrl, skin: skin))),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(AppLocalizations.of(context)!.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ScrollConfiguration(
                behavior: const HorizontalScrollBehavior(),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  clipBehavior: Clip.none,
                  physics: const BouncingScrollPhysics(),
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

class _MusicScrollShowAllScreen extends StatelessWidget {
  const _MusicScrollShowAllScreen({required this.title, required this.items, required this.serverUrl, required this.skin});
  final String title;
  final List items;
  final String? serverUrl;
  final MusicPlayerSkin skin;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: skin.backgroundTop,
      appBar: AppBar(backgroundColor: skin.backgroundTop, title: Text(title, style: TextStyle(color: skin.textPrimary)), iconTheme: IconThemeData(color: skin.textPrimary)),
      body: GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.72),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return PosterCard(item: item, serverUrl: serverUrl, onTap: () => context.push('/player/${item.id}', extra: item));
        },
      ),
    );
  }
}
