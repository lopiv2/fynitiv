import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../core/widgets/app_loader.dart';
import '../../../../../l10n/app_localizations.dart';
import '../shared/music_album_grid.dart';
import '../shared/music_trending_row.dart';

class JellyfinClassicMusicView extends ConsumerWidget {
  const JellyfinClassicMusicView({
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skin.backgroundTop, skin.backgroundBottom],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(l10n.music,
                style: TextStyle(color: skin.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(l10n.albums,
                style: TextStyle(color: skin.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          albumsAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoader())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('$e', style: TextStyle(color: Colors.white)))),
            data: (list) => MusicAlbumGrid(albums: list, serverUrl: serverUrl, skin: skin),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(l10n.songs,
                style: TextStyle(color: skin.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          tracksAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: AppLoader())),
            error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('$e'))),
            data: (list) => list.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Text(l10n.noResults, style: TextStyle(color: skin.textSecondary)))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: skin.textSecondary.withValues(alpha: 0.1)),
                    itemBuilder: (context, i) {
                      final track = list[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        title: Text(track.name ?? '', style: TextStyle(color: skin.textPrimary)),
                        subtitle: Text(track.album ?? track.artists?.join(', ') ?? '', style: TextStyle(color: skin.textSecondary, fontSize: 12)),
                        trailing: Icon(Icons.play_arrow_rounded, color: skin.accent),
                        onTap: () => context.push('/player/${track.id}', extra: track),
                      );
                    },
                  ),
          ),
          for (final scroll in skin.musicScrolls) MusicTrendingRow(scroll: scroll, skin: skin),
        ],
      ),
    );
  }
}
