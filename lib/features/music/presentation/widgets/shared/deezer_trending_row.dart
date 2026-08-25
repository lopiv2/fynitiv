import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../core/widgets/horizontal_scroll_behavior.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../application/deezer_providers.dart';
import '../../deezer_preview_player.dart';
import '../../deezer_show_all_screen.dart';

class DeezerTrendingSongsRow extends ConsumerWidget {
  const DeezerTrendingSongsRow({super.key, required this.skin});
  final MusicPlayerSkin skin;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(deezerTrendingSongsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.trendingSongs, style: TextStyle(color: skin.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerShowAllScreen(title: l10n.trendingSongs, skin: skin, tracks: tracks))),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(l10n.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
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
                  itemCount: tracks.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    return _DeezerSongCard(track: t, skin: skin);
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

class _DeezerSongCard extends ConsumerWidget {
  const _DeezerSongCard({required this.track, required this.skin});
  final DeezerTrack track;
  final MusicPlayerSkin skin;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exists = ref.watch(deezerTrackExistsInJellyfinProvider(track)).value ?? false;
    final logo = exists ? 'assets/images/jellyfin.png' : 'assets/images/logo_deezer.png';
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerPreviewPlayerScreen(track: track))),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(skin.cardRadius), child: SizedBox(width: 140, height: 140, child: track.cover.isNotEmpty ? Image.network(track.cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: skin.accent.withValues(alpha: 0.15))) : Container(color: skin.accent.withValues(alpha: 0.15)))),
              Positioned(right: 6, bottom: 6, child: Image.asset(logo, height: 14, errorBuilder: (_, _, _) => const SizedBox.shrink())),
            ]),
            const SizedBox(height: 8),
            Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(track.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class DeezerPopularArtistsRow extends ConsumerWidget {
  const DeezerPopularArtistsRow({super.key, required this.skin});
  final MusicPlayerSkin skin;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(deezerPopularArtistsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (artists) {
        if (artists.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.popularArtists, style: TextStyle(color: skin.textPrimary, fontSize: 16, fontWeight: FontWeight.w700))),
                  InkWell(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerShowAllScreen(title: l10n.popularArtists, skin: skin, artists: artists))),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(l10n.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ScrollConfiguration(
                behavior: const HorizontalScrollBehavior(),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  clipBehavior: Clip.none,
                  physics: const BouncingScrollPhysics(),
                  itemCount: artists.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, i) {
                    final a = artists[i];
                    return SizedBox(
                      width: 120,
                      child: Column(children: [ClipOval(child: SizedBox(width: 110, height: 110, child: a.picture.isNotEmpty ? Image.network(a.picture, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.white12)) : Container(color: Colors.white12))), const SizedBox(height: 8), Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: skin.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)), Text(l10n.artist, style: TextStyle(color: skin.textSecondary, fontSize: 11))]),
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
