import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/settings/music_chart_source.dart';
import '../../../../../core/settings/music_chart_source_controller.dart';
import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../core/widgets/app_loader.dart';
import '../../../../../l10n/app_localizations.dart';
import '../shared/deezer_trending_row.dart';
import '../shared/music_trending_row.dart';

class TidalMusicView extends ConsumerWidget {
  const TidalMusicView({
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
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TIDAL', style: TextStyle(color: skin.textPrimary, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 6)),
                const SizedBox(height: 4),
                Text('${AppLocalizations.of(context)!.music} \u2022 HiFi', style: TextStyle(color: skin.textSecondary, fontSize: 12, letterSpacing: 2)),
                const SizedBox(height: 12),
                Divider(color: skin.textSecondary.withValues(alpha: 0.15)),
              ],
            ),
          ),
          albumsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoader())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e', style: TextStyle(color: Colors.white))),
            data: (list) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  for (final a in list.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: skin.textSecondary.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(skin.cardRadius),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(skin.cardRadius)),
                          leading: Container(width: 48, height: 48, color: Colors.white.withValues(alpha: 0.06), child: const Icon(Icons.album, color: Colors.white70)),
                          title: Text(a.name ?? '', style: TextStyle(color: skin.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(a.artists?.firstOrNull ?? '', style: TextStyle(color: skin.textSecondary, fontSize: 12)),
                          trailing: Icon(Icons.chevron_right, color: skin.textSecondary, size: 18),
                          onTap: () => context.push('/music/album/${a.id}', extra: a),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
