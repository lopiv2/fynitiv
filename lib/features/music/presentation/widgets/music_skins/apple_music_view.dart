import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/settings/music_chart_source.dart';
import '../../../../../core/settings/music_chart_source_controller.dart';
import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../core/widgets/app_loader.dart';
import '../../../../../l10n/app_localizations.dart';
import '../shared/deezer_trending_row.dart';
import '../shared/music_trending_row.dart';

class AppleMusicView extends ConsumerWidget {
  const AppleMusicView({
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: skin.backgroundTop,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.music,
                    style: TextStyle(color: skin.textPrimary, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1)),
                Text('Player \u2022 Apple',
                    style: TextStyle(color: skin.accent, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
              ],
            ),
          ),
          albumsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoader())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e')),
            data: (list) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.78,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final album = list[i];
                return Container(
                  decoration: BoxDecoration(
                    color: skin.backgroundBottom,
                    borderRadius: BorderRadius.circular(skin.cardRadius),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(skin.cardRadius)),
                          child: Container(color: skin.accent.withValues(alpha: 0.12), alignment: Alignment.center, child: Icon(Icons.album_rounded, color: skin.accent, size: 48)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(album.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(album.artists?.firstOrNull ?? '', maxLines: 1, style: TextStyle(color: skin.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          if (ref.watch(musicChartSourceControllerProvider) == MusicChartSource.deezer) ...[
            DeezerTrendingSongsRow(skin: skin),
            DeezerPopularArtistsRow(skin: skin),
          ] else
            for (final s in skin.musicScrolls) MusicTrendingRow(scroll: s, skin: skin),
        ],
      ),
    );
  }
}
