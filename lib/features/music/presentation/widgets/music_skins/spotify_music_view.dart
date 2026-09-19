import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../core/constants/ui_constants.dart';
import '../../../../../core/settings/music_chart_source.dart';
import '../../../../../core/settings/music_chart_source_controller.dart';
import '../../../../../core/skin/music_player_skin.dart';
import '../../../../../core/widgets/app_loader.dart';
import '../../../../../core/widgets/responsive_carousel.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../library/application/image_url.dart';
import '../../../../library/application/library_providers.dart';
import '../../../application/deezer_providers.dart';
import '../media_card.dart';
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
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: AppLoader()),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (songs) {
            if (songs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.noResults,
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.trendingSongs,
                          style: TextStyle(
                            color: skin.textPrimary,
                            fontSize: kSectionTitleFontSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DeezerShowAllScreen(
                              title: l10n.trendingSongs,
                              skin: skin,
                              tracks: songs,
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(
                            l10n.showAll,
                            style: TextStyle(
                              color: skin.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kSectionTitleGap),
                ResponsiveCarousel(
                  itemCount: songs.length,
                  extraHeight: 64,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  itemBuilder: (context, i, cardWidth) {
                    final track = songs[i];
                    return Consumer(
                      builder: (context, ref, _) {
                        final exists =
                            ref
                                .watch(
                                  deezerTrackExistsInJellyfinProvider(track),
                                )
                                .value ??
                            false;
                        return MediaCard(
                          title: track.title,
                          subtitle: track.artistName,
                          showExplicit: track.explicit,
                          imageUrl: track.cover.isNotEmpty ? track.cover : null,
                          fallbackBackground: skin.accent.withValues(
                            alpha: 0.15,
                          ),
                          badgeAsset: exists
                              ? 'assets/images/jellyfin.png'
                              : 'assets/images/logo_deezer.png',
                          dimOnHover: true,
                          width: cardWidth,
                          textPrimary: skin.textPrimary,
                          textSecondary: skin.textSecondary,
                          playBackground: skin.accent,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  DeezerPreviewPlayerScreen(track: track),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      } else {
        return trendingJelly.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: AppLoader()),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (songs) {
            if (songs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.noResults,
                  style: TextStyle(color: skin.textSecondary),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.trendingSongs,
                          style: TextStyle(
                            color: skin.textPrimary,
                            fontSize: kSectionTitleFontSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DeezerShowAllScreen(
                              title: l10n.trendingSongs,
                              skin: skin,
                              tracks: songs
                                  .map(
                                    (e) => DeezerTrack(
                                      id: int.tryParse(e.id ?? '0') ?? 0,
                                      title: e.name ?? '',
                                      artistName:
                                          (e.artists != null &&
                                              e.artists!.isNotEmpty)
                                          ? e.artists!.first
                                          : '',
                                      artistPicture: '',
                                      cover: '',
                                      preview: '',
                                      explicit: false,
                                      position: 0,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(
                            l10n.showAll,
                            style: TextStyle(
                              color: skin.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kSectionTitleGap),
                ResponsiveCarousel(
                  itemCount: songs.length,
                  extraHeight: 64,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  itemBuilder: (context, i, cardWidth) {
                    final item = songs[i];
                    final title = (item.name ?? '').toString();
                    final artists = (item.artists is List)
                        ? (item.artists as List).join(', ')
                        : (item.artists?.toString() ?? '');
                    return MediaCard(
                      title: title,
                      subtitle: artists.isNotEmpty
                          ? artists
                          : (item.album ?? ''),
                      showExplicit:
                          (item.officialRating
                                  ?.toString()
                                  .toLowerCase()
                                  .contains('explicit') ??
                              false) ||
                          title.toLowerCase().contains('explicit') ||
                          (title.hashCode % 3 == 0),
                      imageUrl: (serverUrl != null && item.id != null)
                          ? itemImageUrl(serverUrl!, item, maxWidth: 400)
                          : null,
                      fallbackBackground: skin.accent.withValues(alpha: 0.15),
                      badgeAsset: 'assets/images/jellyfin.png',
                      badgeSize: 18,
                      dimOnHover: true,
                      width: cardWidth,
                      textPrimary: skin.textPrimary,
                      textSecondary: skin.textSecondary,
                      playBackground: skin.accent,
                      onTap: () =>
                          context.push('/player/${item.id}', extra: item),
                    );
                  },
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
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: AppLoader()),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (artists) {
            if (artists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.noResults,
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.popularArtists,
                          style: TextStyle(
                            color: skin.textPrimary,
                            fontSize: kSectionTitleFontSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DeezerShowAllScreen(
                              title: l10n.popularArtists,
                              skin: skin,
                              artists: artists,
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(
                            l10n.showAll,
                            style: TextStyle(
                              color: skin.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kSectionTitleGap),
                ResponsiveCarousel(
                  itemCount: artists.length,
                  spacing: 18,
                  extraHeight: 60,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  itemBuilder: (context, i, cardWidth) {
                    final artist = artists[i];
                    return MediaCard(
                      title: artist.name,
                      subtitle: AppLocalizations.of(context)!.artist,
                      circular: true,
                      imageSize: cardWidth - 16,
                      width: cardWidth,
                      padding: const EdgeInsets.all(8),
                      textPrimary: skin.textPrimary,
                      textSecondary: skin.textSecondary,
                      playBackground: skin.accent,
                      imageUrl: artist.picture.isNotEmpty
                          ? artist.picture
                          : null,
                      playSize: 40,
                      centerText: true,
                      onTap: () => context.push(
                        '/music/artist/${Uri.encodeComponent(artist.name)}',
                        extra: artist,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      } else {
        return artistsJelly.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: AppLoader()),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (artists) {
            if (artists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.noResults,
                  style: TextStyle(color: skin.textSecondary),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.popularArtists,
                          style: TextStyle(
                            color: skin.textPrimary,
                            fontSize: kSectionTitleFontSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          final list = artists;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DeezerShowAllScreen(
                                title: l10n.popularArtists,
                                skin: skin,
                                artists: list
                                    .map(
                                      (e) => DeezerArtist(
                                        id: int.tryParse(e.id ?? '0') ?? 0,
                                        name: (e.name ?? ''),
                                        picture: '',
                                        position: 0,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(
                            l10n.showAll,
                            style: TextStyle(
                              color: skin.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: kSectionTitleGap),
                ResponsiveCarousel(
                  itemCount: artists.length,
                  spacing: 18,
                  extraHeight: 60,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  itemBuilder: (context, i, cardWidth) {
                    final item = artists[i];
                    final name = (item.name ?? '').toString();
                    return MediaCard(
                      title: name,
                      subtitle: AppLocalizations.of(context)!.artist,
                      circular: true,
                      imageSize: cardWidth - 16,
                      imageUrl: (serverUrl != null && item.id != null)
                          ? itemImageUrl(serverUrl!, item, maxWidth: 400)
                          : null,
                      fallbackText: name.isNotEmpty
                          ? name[0].toUpperCase()
                          : '?',
                      width: cardWidth,
                      textPrimary: skin.textPrimary,
                      textSecondary: skin.textSecondary,
                      playBackground: skin.accent,
                      playSize: 40,
                      centerText: true,
                      onTap: () => context.push(
                        '/music/artist/${Uri.encodeComponent(name)}',
                        extra: item,
                      ),
                    );
                  },
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
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: AppLoader()),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (list) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.myPlaylists,
                        style: TextStyle(
                          color: skin.textPrimary,
                          fontSize: kSectionTitleFontSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DeezerShowAllScreen(
                            title: l10n.myPlaylists,
                            skin: skin,
                            tracks: list
                                .map(
                                  (e) => DeezerTrack(
                                    id: int.tryParse(e.id ?? '0') ?? 0,
                                    title: e.name ?? '',
                                    artistName: '',
                                    artistPicture: '',
                                    cover: '',
                                    preview: '',
                                    explicit: false,
                                    position: 0,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          l10n.showAll,
                          style: TextStyle(
                            color: skin.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSectionTitleGap),
              ResponsiveCarousel(
                itemCount: list.length,
                extraHeight: 58,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                itemBuilder: (context, i, cardWidth) {
                  final item = list[i];
                  final url = serverUrl != null && item.id != null
                      ? itemImageUrl(serverUrl!, item, maxWidth: 400)
                      : null;
                  return MediaCard(
                    title: item.name ?? '',
                    subtitle: 'Playlist',
                    imageUrl: url,
                    fallbackIcon: Icons.playlist_play,
                    fallbackIconColor: Colors.white70,
                    fallbackBackground: skin.accent.withValues(alpha: 0.15),
                    width: cardWidth,
                    imageSize: cardWidth - 16,
                    badgeAsset: 'assets/images/jellyfin.png',
                    badgeSize: 14,
                    playSize: 36,
                    playBackground: skin.accent,
                    textPrimary: skin.textPrimary,
                    textSecondary: skin.textSecondary,
                    onTap: () =>
                        context.push('/music/playlist/${item.id}', extra: item),
                  );
                },
              ),
            ],
          );
        },
      );
    }

    Widget recentlyAddedSection() {
      return recentlyAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: AppLoader()),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (list) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.recentlyAdded,
                        style: TextStyle(
                          color: skin.textPrimary,
                          fontSize: kSectionTitleFontSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DeezerShowAllScreen(
                            title: l10n.recentlyAdded,
                            skin: skin,
                            tracks: list
                                .map(
                                  (e) => DeezerTrack(
                                    id: int.tryParse(e.id ?? '0') ?? 0,
                                    title: e.name ?? '',
                                    artistName:
                                        (e.artists != null &&
                                            (e.artists as List).isNotEmpty)
                                        ? (e.artists as List).first.toString()
                                        : '',
                                    artistPicture: '',
                                    cover: '',
                                    preview: '',
                                    explicit: false,
                                    position: 0,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          l10n.showAll,
                          style: TextStyle(
                            color: skin.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSectionTitleGap),
              ResponsiveCarousel(
                itemCount: list.length,
                extraHeight: 58,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                itemBuilder: (context, i, cardWidth) {
                  final item = list[i];
                  final url = serverUrl != null && item.id != null
                      ? itemImageUrl(serverUrl!, item, maxWidth: 400)
                      : null;
                  return MediaCard(
                    title: item.name ?? '',
                    subtitle: (item.artists != null && item.artists!.isNotEmpty)
                        ? item.artists!.first
                        : (item.albumArtist ?? ''),
                    imageUrl: url,
                    fallbackBackground: skin.accent.withValues(alpha: 0.15),
                    width: cardWidth,
                    imageSize: cardWidth - 16,
                    badgeAsset: 'assets/images/jellyfin.png',
                    badgeSize: 14,
                    playSize: 36,
                    playBackground: skin.accent,
                    textPrimary: skin.textPrimary,
                    textSecondary: skin.textSecondary,
                    onTap: () =>
                        context.push('/player/${item.id}', extra: item),
                  );
                },
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
          const SizedBox(height: kBetweenSectionsGap),
          artistsSection(),
          const SizedBox(height: kBetweenSectionsGap),
          playlistsSection(),
          const SizedBox(height: kBetweenSectionsGap),
          recentlyAddedSection(),
        ],
      ),
    );
  }
}
