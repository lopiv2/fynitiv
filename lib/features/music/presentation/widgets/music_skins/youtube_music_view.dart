import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../core/widgets/app_loader.dart';
import '../../../../../l10n/app_localizations.dart';
import '../shared/music_trending_row.dart';

class YoutubeMusicView extends ConsumerWidget {
  const YoutubeMusicView({
    super.key,
    required this.skin,
    required this.serverUrl,
    required this.albumsAsync,
    required this.tracksAsync,
  });

  final MusicPlayerSkin skin;
  final String? serverUrl;
  final AsyncValue<List<BaseItemDto>> albumsAsync;
  final AsyncValue<List<BaseItemDto>> tracksAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: skin.backgroundTop,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: skin.accent, borderRadius: BorderRadius.circular(4)),
                  child: const Text('MUSIC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context)!.music, style: TextStyle(color: skin.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  labelColor: skin.textPrimary,
                  unselectedLabelColor: skin.textSecondary,
                  indicatorColor: skin.accent,
                  tabs: [Tab(text: AppLocalizations.of(context)!.albums), Tab(text: AppLocalizations.of(context)!.songs)],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          albumsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoader())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e', style: TextStyle(color: Colors.white))),
            data: (list) => SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final a = list[i];
                  return SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(skin.cardRadius),
                          child: Container(height: 140, color: skin.accent.withValues(alpha: 0.15), alignment: Alignment.center, child: Icon(Icons.album, color: skin.accent)),
                        ),
                        const SizedBox(height: 8),
                        Text(a.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(a.artists?.firstOrNull ?? '', maxLines: 1, style: TextStyle(color: skin.textSecondary, fontSize: 11)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          for (final s in skin.musicScrolls) MusicTrendingRow(scroll: s, skin: skin),
        ],
      ),
    );
  }
}
