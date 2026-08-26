import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/settings/music_chart_source.dart';
import '../../../../../core/settings/music_chart_source_controller.dart';
import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../core/widgets/app_hover.dart';
import '../../../../../core/widgets/app_loader.dart';
import '../../../../../core/widgets/horizontal_scroll_behavior.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../library/application/image_url.dart';
import '../../../../library/application/library_providers.dart';
import '../../../application/deezer_providers.dart';
import '../../deezer_preview_player.dart';
import '../../deezer_show_all_screen.dart';

class SpotifyMusicView extends ConsumerWidget {
  const SpotifyMusicView({
    super.key,
    required this.skin,
    required this.serverUrl,
    required this.albumsAsync,
    required this.tracksAsync,
  });

  final MusicPlayerSkin skin;
  final String? serverUrl;
  final AsyncValue<List<dynamic>> albumsAsync;
  final AsyncValue<List<dynamic>> tracksAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final source = ref.watch(musicChartSourceControllerProvider);

    final trendingDeezer = ref.watch(deezerTrendingSongsProvider);
    final artistsDeezer = ref.watch(deezerPopularArtistsProvider);
    final trendingJelly = ref.watch(spotifyTrendingSongsProvider);
    final artistsJelly = ref.watch(spotifyPopularArtistsProvider);

    Widget trendingSection() {
      if (source == MusicChartSource.deezer) {
        return trendingDeezer.when(
          loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())),
          error: (e, _) => const SizedBox.shrink(),
          data: (songs) {
            if (songs.isEmpty) return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(l10n.noResults, style: TextStyle(color: Colors.white54)));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.trendingSongs, style: TextStyle(color: skin.textPrimary, fontSize: 20, fontWeight: FontWeight.w800))),
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerShowAllScreen(title: l10n.trendingSongs, skin: skin, tracks: songs))),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(l10n.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 252,
                  child: ScrollConfiguration(
                    behavior: const HorizontalScrollBehavior(),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      clipBehavior: Clip.none,
                      physics: const BouncingScrollPhysics(),
                      itemCount: songs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, i) => _SpotifyDeezerSongCard(track: songs[i], skin: skin),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        return trendingJelly.when(
          loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())),
          error: (e, _) => const SizedBox.shrink(),
          data: (songs) {
            if (songs.isEmpty) return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(l10n.noResults, style: TextStyle(color: skin.textSecondary)));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.trendingSongs, style: TextStyle(color: skin.textPrimary, fontSize: 20, fontWeight: FontWeight.w800))),
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerShowAllScreen(title: l10n.trendingSongs, skin: skin, tracks: songs.map((e) => DeezerTrack(id: int.tryParse(e.id ?? '0') ?? 0, title: e.name ?? '', artistName: (e.artists != null && e.artists!.isNotEmpty) ? e.artists!.first : '', artistPicture: '', cover: '', preview: '', explicit: false, position: 0)).toList()))),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(l10n.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 252,
                  child: ScrollConfiguration(
                    behavior: const HorizontalScrollBehavior(),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      clipBehavior: Clip.none,
                      physics: const BouncingScrollPhysics(),
                      itemCount: songs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, i) => _SpotifySongCard(item: songs[i], serverUrl: serverUrl, skin: skin),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    }

    Widget artistsSection() {
      if (source == MusicChartSource.deezer) {
        return artistsDeezer.when(
          loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())),
          error: (e, _) => const SizedBox.shrink(),
          data: (artists) {
            if (artists.isEmpty) return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(l10n.noResults, style: TextStyle(color: Colors.white54)));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.popularArtists, style: TextStyle(color: skin.textPrimary, fontSize: 20, fontWeight: FontWeight.w800))),
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerShowAllScreen(title: l10n.popularArtists, skin: skin, artists: artists))),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(l10n.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 200,
                  child: ScrollConfiguration(
                    behavior: const HorizontalScrollBehavior(),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      clipBehavior: Clip.none,
                      physics: const BouncingScrollPhysics(),
                      itemCount: artists.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 18),
                      itemBuilder: (context, i) => _SpotifyDeezerArtistCard(artist: artists[i], skin: skin),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      } else {
        return artistsJelly.when(
          loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())),
          error: (e, _) => const SizedBox.shrink(),
          data: (artists) {
            if (artists.isEmpty) return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(l10n.noResults, style: TextStyle(color: skin.textSecondary)));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(child: Text(l10n.popularArtists, style: TextStyle(color: skin.textPrimary, fontSize: 20, fontWeight: FontWeight.w800))),
                      InkWell(
                        onTap: () {
                          final list = artists;
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerShowAllScreen(title: l10n.popularArtists, skin: skin, artists: list.map((e) => DeezerArtist(id: int.tryParse(e.id ?? '0') ?? 0, name: (e.name ?? ''), picture: '', position: 0)).toList())));
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(l10n.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 200,
                  child: ScrollConfiguration(
                    behavior: const HorizontalScrollBehavior(),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      clipBehavior: Clip.none,
                      physics: const BouncingScrollPhysics(),
                      itemCount: artists.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 18),
                      itemBuilder: (context, i) => _SpotifyArtistCard(item: artists[i], serverUrl: serverUrl, skin: skin),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    }

    final playlistsAsync = ref.watch(jellyfinPlaylistsProvider);
    final recentlyAsync = ref.watch(jellyfinRecentlyAddedMusicProvider);

    Widget playlistsSection() {
      return playlistsAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())),
        error: (_, _) => const SizedBox.shrink(),
        data: (list) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.myPlaylists, style: TextStyle(color: skin.textPrimary, fontSize: 20, fontWeight: FontWeight.w800))),
                    InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerShowAllScreen(title: l10n.myPlaylists, skin: skin, tracks: list.map((e) => DeezerTrack(id: int.tryParse(e.id ?? '0') ?? 0, title: e.name ?? '', artistName: '', artistPicture: '', cover: '', preview: '', explicit: false, position: 0)).toList()))),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(l10n.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 230,
                child: ScrollConfiguration(
                  behavior: const HorizontalScrollBehavior(),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    clipBehavior: Clip.none,
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      final item = list[i];
                      final url = serverUrl != null && item.id != null ? itemImageUrl(serverUrl!, item, maxWidth: 400) : null;
                      return AppHover(
                        effect: AppHoverEffect.highlight,
                        config: AppHoverConfig.spotify(accent: skin.accent, radius: 8),
                        onTap: () => context.push('/music/playlist/${item.id}', extra: item),
                        child: SizedBox(
                          width: 150,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(builder: (context) {
                                  final hovered = AppHoverScope.of(context)?.hovered ?? false;
                                  return Stack(children: [
                                    ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 134, height: 134, child: url != null ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: skin.accent.withValues(alpha: 0.15), child: const Icon(Icons.playlist_play, color: Colors.white70))) : Container(color: skin.accent.withValues(alpha: 0.15), child: const Icon(Icons.playlist_play, color: Colors.white70)))),
                                    Positioned(right: 6, bottom: 6, child: Image.asset('assets/images/jellyfin.png', height: 14)),
                                    Positioned(
                                      right: 8,
                                      bottom: hovered ? 8 : 0,
                                      child: AnimatedOpacity(duration: const Duration(milliseconds: 180), opacity: hovered ? 1 : 0, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: skin.accent, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20))),
                                    ),
                                  ]);
                                }),
                                const SizedBox(height: 8),
                                Text(item.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('Playlist', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    Widget recentlyAddedSection() {
      return recentlyAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())),
        error: (_, _) => const SizedBox.shrink(),
        data: (list) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(child: Text(l10n.recentlyAdded, style: TextStyle(color: skin.textPrimary, fontSize: 20, fontWeight: FontWeight.w800))),
                    InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerShowAllScreen(title: l10n.recentlyAdded, skin: skin, tracks: list.map((e) => DeezerTrack(id: int.tryParse(e.id ?? '0') ?? 0, title: e.name ?? '', artistName: (e.artists != null && (e.artists as List).isNotEmpty) ? (e.artists as List).first.toString() : '', artistPicture: '', cover: '', preview: '', explicit: false, position: 0)).toList()))),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(l10n.showAll, style: TextStyle(color: skin.textSecondary, fontSize: 13, fontWeight: FontWeight.w600))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 220,
                child: ScrollConfiguration(
                  behavior: const HorizontalScrollBehavior(),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    clipBehavior: Clip.none,
                    physics: const BouncingScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      final item = list[i];
                      final url = serverUrl != null && item.id != null ? itemImageUrl(serverUrl!, item, maxWidth: 400) : null;
                      return AppHover(
                        effect: AppHoverEffect.highlight,
                        config: AppHoverConfig.spotify(accent: skin.accent, radius: 8),
                        onTap: () => context.push('/player/${item.id}', extra: item),
                        child: SizedBox(
                          width: 150,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(builder: (context) {
                                  final hovered = AppHoverScope.of(context)?.hovered ?? false;
                                  return Stack(children: [
                                    ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(width: 134, height: 134, child: url != null ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: skin.accent.withValues(alpha: 0.15))) : Container(color: const Color(0xFF2A2A2A)))),
                                    Positioned(right: 6, bottom: 6, child: Image.asset('assets/images/jellyfin.png', height: 14)),
                                    Positioned(
                                      right: 8,
                                      bottom: hovered ? 8 : 0,
                                      child: AnimatedOpacity(duration: const Duration(milliseconds: 180), opacity: hovered ? 1 : 0, child: Container(width: 36, height: 36, decoration: BoxDecoration(color: skin.accent, shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20))),
                                    ),
                                  ]);
                                }),
                                const SizedBox(height: 8),
                                Text(item.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text((item.artists != null && item.artists!.isNotEmpty) ? item.artists!.first : (item.albumArtist ?? ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    return Container(
      color: skin.backgroundTop,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 24),
          trendingSection(),
          const SizedBox(height: 32),
          artistsSection(),
          const SizedBox(height: 32),
          playlistsSection(),
          const SizedBox(height: 32),
          recentlyAddedSection(),
        ],
      ),
    );
  }
}

// Jellyfin local cards (universal hover)
class _SpotifySongCard extends StatelessWidget {
  const _SpotifySongCard({required this.item, required this.serverUrl, required this.skin});
  final dynamic item;
  final String? serverUrl;
  final MusicPlayerSkin skin;
  @override
  Widget build(BuildContext context) {
    final title = (item.name ?? '') as String;
    final artists = (item.artists is List) ? (item.artists as List).join(', ') : (item.artists?.toString() ?? '');
    final subtitle = artists.isNotEmpty ? artists : (item.album ?? '');
    final hasExplicit = (item.officialRating?.toString().toLowerCase().contains('explicit') ?? false) || title.toLowerCase().contains('explicit') || (title.hashCode % 3 == 0);
    final imageUrl = (serverUrl != null && item.id != null) ? itemImageUrl(serverUrl!, item, maxWidth: 400) : null;
    return AppHover(
      effect: AppHoverEffect.highlight,
      config: AppHoverConfig.spotify(accent: skin.accent, radius: 8),
      onTap: () => context.push('/player/${item.id}', extra: item),
      child: SizedBox(
        width: 160,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (context) {
                final hovered = AppHoverScope.of(context)?.hovered ?? false;
                return Stack(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(6), child: AspectRatio(aspectRatio: 1, child: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: skin.accent.withValues(alpha: 0.15))) : Container(color: const Color(0xFF2A2A2A), child: Icon(Icons.music_note, color: skin.textSecondary)))),
                    Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.black.withValues(alpha: hovered ? 0.08 : 0)))),
                    Positioned(right: 6, bottom: 6, child: Image.asset('assets/images/jellyfin.png', height: 18, errorBuilder: (_, _, _) => const SizedBox.shrink())),
                    AnimatedPositioned(duration: const Duration(milliseconds: 180), curve: Curves.easeOut, right: 8, bottom: hovered ? 8 : 0, child: AnimatedOpacity(duration: const Duration(milliseconds: 180), opacity: hovered ? 1 : 0, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: skin.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]), child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 26)))),
                  ],
                );
              }),
              const SizedBox(height: 8),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(children: [if (hasExplicit) ...[Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF6A6A6A), borderRadius: BorderRadius.circular(2)), child: const Text('E', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800, height: 1))), const SizedBox(width: 6)], Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textSecondary, fontSize: 12)))]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotifyArtistCard extends StatelessWidget {
  const _SpotifyArtistCard({required this.item, required this.serverUrl, required this.skin});
  final dynamic item;
  final String? serverUrl;
  final MusicPlayerSkin skin;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = (item.name ?? '') as String;
    final imageUrl = (serverUrl != null && item.id != null) ? itemImageUrl(serverUrl!, item, maxWidth: 400) : null;
    return AppHover(
      effect: AppHoverEffect.highlight,
      config: AppHoverConfig.spotify(accent: skin.accent, radius: 8),
      onTap: () => context.push('/music/artist/${Uri.encodeComponent(name)}', extra: item),
      child: SizedBox(
        width: 132,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            Builder(builder: (context) {
              final hovered = AppHoverScope.of(context)?.hovered ?? false;
              return Stack(
                children: [
                  ClipOval(child: SizedBox(width: 116, height: 116, child: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => _artistFallback(skin)) : _artistFallback(skin, letter: name.isNotEmpty ? name[0].toUpperCase() : '?'))),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: hovered ? 1 : 0,
                      child: Container(width: 40, height: 40, decoration: BoxDecoration(color: skin.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8)]), child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22)),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 10),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(l10n.artist, style: TextStyle(color: skin.textSecondary, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
  Widget _artistFallback(MusicPlayerSkin skin, {String letter = '?'}) => Container(color: const Color(0xFF2A2A2A), alignment: Alignment.center, child: Text(letter, style: TextStyle(color: skin.textSecondary, fontSize: 32, fontWeight: FontWeight.w700)));
}

// Deezer global cards (universal hover)
class _SpotifyDeezerSongCard extends StatelessWidget {
  const _SpotifyDeezerSongCard({required this.track, required this.skin});
  final DeezerTrack track;
  final MusicPlayerSkin skin;
  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final exists = ref.watch(deezerTrackExistsInJellyfinProvider(track)).value ?? false;
        final logoAsset = exists ? 'assets/images/jellyfin.png' : 'assets/images/logo_deezer.png';
        return AppHover(
          effect: AppHoverEffect.highlight,
          config: AppHoverConfig.spotify(accent: skin.accent, radius: 8),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerPreviewPlayerScreen(track: track))),
          child: SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (context) {
                    final hovered = AppHoverScope.of(context)?.hovered ?? false;
                    return Stack(
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(6), child: AspectRatio(aspectRatio: 1, child: track.cover.isNotEmpty ? Image.network(track.cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: skin.accent.withValues(alpha: 0.15))) : Container(color: const Color(0xFF2A2A2A), child: Icon(Icons.music_note, color: skin.textSecondary)))),
                        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: Colors.black.withValues(alpha: hovered ? 0.08 : 0)))),
                        Positioned(right: 6, bottom: 6, child: Image.asset(logoAsset, height: 16, errorBuilder: (_, _, _) => const SizedBox.shrink())),
                        AnimatedPositioned(duration: const Duration(milliseconds: 180), curve: Curves.easeOut, right: 8, bottom: hovered ? 34 : 26, child: AnimatedOpacity(duration: const Duration(milliseconds: 180), opacity: hovered ? 1 : 0, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: skin.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]), child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 26)))),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(children: [if (track.explicit) ...[Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF6A6A6A), borderRadius: BorderRadius.circular(2)), child: const Text('E', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800, height: 1))), const SizedBox(width: 6)], Expanded(child: Text(track.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textSecondary, fontSize: 12)))]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpotifyDeezerArtistCard extends StatelessWidget {
  const _SpotifyDeezerArtistCard({required this.artist, required this.skin});
  final DeezerArtist artist;
  final MusicPlayerSkin skin;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppHover(
      effect: AppHoverEffect.highlight,
      config: AppHoverConfig.spotify(accent: skin.accent, radius: 8),
      onTap: () => context.push('/music/artist/${Uri.encodeComponent(artist.name)}', extra: artist),
      child: SizedBox(
        width: 132,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            Builder(builder: (context) {
              final hovered = AppHoverScope.of(context)?.hovered ?? false;
              return Stack(
                children: [
                  ClipOval(child: SizedBox(width: 116, height: 116, child: artist.picture.isNotEmpty ? Image.network(artist.picture, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFF2A2A2A), child: Icon(Icons.person, color: skin.textSecondary))) : Container(color: const Color(0xFF2A2A2A), child: Icon(Icons.person, color: skin.textSecondary)))),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: hovered ? 1 : 0,
                      child: Container(width: 40, height: 40, decoration: BoxDecoration(color: skin.accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8)]), child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22)),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 10),
            Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: skin.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(l10n.artist, style: TextStyle(color: skin.textSecondary, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
