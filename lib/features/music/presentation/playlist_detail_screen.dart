import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/image_url.dart';
import '../../player/application/playback_provider.dart';
import '../application/music_player_provider.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/widgets/poster_card.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId, this.playlist});

  final String playlistId;
  final BaseItemDto? playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverUrl = ref.watch(authServerUrlProvider);
    final tracksAsync = ref.watch(playlistTracksProvider(playlistId));
    final detailAsync = ref.watch(itemDetailProvider(playlistId));

    return detailAsync.when(
      loading: () => const Scaffold(backgroundColor: Color(0xFF0A0A0A), body: Center(child: AppLoader())),
      error: (e, _) => Scaffold(backgroundColor: const Color(0xFF0A0A0A), body: Center(child: Text('$e', style: TextStyle(color: Colors.white54)))),
      data: (detail) {
        final item = detail ?? playlist;
        return _PlaylistJellyfinView(
          playlist: item,
          playlistId: playlistId,
          serverUrl: serverUrl,
          tracks: tracksAsync,
        );
      },
    );
  }
}

class _PlaylistJellyfinView extends ConsumerWidget {
  const _PlaylistJellyfinView({
    required this.playlist,
    required this.playlistId,
    required this.serverUrl,
    required this.tracks,
  });

  final BaseItemDto? playlist;
  final String playlistId;
  final String? serverUrl;
  final AsyncValue<List<BaseItemDto>> tracks;

  String _formatMs(int ms) {
    final totalSec = ms ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pl = playlist;
    final artist = (pl?.albumArtists?.firstOrNull?.name ?? pl?.artists?.firstOrNull ?? '').trim();
    final title = pl?.name ?? '';
    final logoText = artist.isNotEmpty ? artist.toUpperCase() : (pl?.albumArtist ?? '').toUpperCase();
    final globalSkin = ref.watch(skinControllerProvider).value;
    final topPadding = libraryPageTopPadding(context, globalSkin);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          SizedBox(height: topPadding),
          Expanded(
            child: tracks.when(
              loading: () => const Center(child: AppLoader()),
              error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white54))),
              data: (list) {
          final totalMs = list.fold<int>(0, (p, e) => p + (e.runTimeTicks ?? 0) ~/ 10000);
          final count = list.length;
          final minutes = totalMs > 0 ? '${_formatMs(totalMs).split(':').first}m' : '';
          final year = pl?.productionYear?.toString() ?? '';
          final rating = pl?.communityRating != null ? '★ ${pl!.communityRating!.toStringAsFixed(1)}' : '';
          final genre = pl?.genres?.firstOrNull ?? (list.isNotEmpty ? list.first.genres?.firstOrNull ?? 'Dance-Pop' : 'Dance-Pop');

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: IconButton(
                              tooltip: l10n.back,
                              style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.08), foregroundColor: Colors.white),
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: () => context.canPop() ? context.pop() : context.go('/music'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 320,
                          height: 320,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, offset: const Offset(0, 8))],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: serverUrl != null && pl != null
                              ? Image.network(itemImageUrl(serverUrl!, pl), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFF1A1A1A)))
                              : Container(color: const Color(0xFF1A1A1A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (logoText.isNotEmpty)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Text(logoText, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: -1, height: 0.9)),
                          ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.07),
                        Container(
                          color: const Color(0xFF1A1A1A),
                          padding: EdgeInsets.fromLTRB(MediaQuery.of(context).size.width * 0.03, 16, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title.isNotEmpty ? title : '—', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (artist.isNotEmpty)
                                          Text(artist, style: const TextStyle(color: Color(0xFF3DDC84), fontSize: 18, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(l10n.tracksCount(count), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                            if (minutes.isNotEmpty) ...[const Text('  ', style: TextStyle(color: Colors.white70)), Text(minutes, style: const TextStyle(color: Colors.white70, fontSize: 14))],
                                            if (year.isNotEmpty) ...[const SizedBox(width: 8), Text(year, style: const TextStyle(color: Colors.white70, fontSize: 14))],
                                            if (rating.isNotEmpty) ...[const SizedBox(width: 8), Text(rating, style: const TextStyle(color: Color(0xFFFFC107), fontSize: 14, fontWeight: FontWeight.w600))],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(onPressed: list.isEmpty ? null : () => context.push('/player/${list.first.id}', extra: list.first), icon: const Icon(Icons.play_arrow_rounded, color: Colors.white)),
                                      IconButton(onPressed: () {}, icon: const Icon(Icons.explore_outlined, color: Colors.white70, size: 20)),
                                      IconButton(onPressed: () {}, icon: const Icon(Icons.shuffle_rounded, color: Colors.white70, size: 20)),
                                      IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border_rounded, color: Colors.white70, size: 20)),
                                      IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(50, 0, 26, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(spacing: 4, children: [for (final t in ['MusicBrainz Album', 'MusicBrainz Album Artist', 'MusicBrainz Release Group']) Text(t, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.w600))]),
                              const SizedBox(height: 12),
                              Row(children: [Text(l10n.genre, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(width: 24), Text(genre, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.w600))]),
                              const SizedBox(height: 16),
                              Column(
                                children: [
                                  for (var i = 0; i < list.length; i++)
                                    _PlaylistTrackRow(index: (list[i].indexNumber ?? i + 1).toString(), track: list[i], onTap: () => context.push('/player/${list[i].id}', extra: list[i])),
                                  if (list.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(l10n.noTracks, style: const TextStyle(color: Colors.white54)),
                                          const SizedBox(height: 12),
                                          FilledButton.icon(
                                            onPressed: () {
                                              ref.invalidate(playlistTracksProvider(playlistId));
                                              ref.invalidate(itemDetailProvider(playlistId));
                                            },
                                            icon: const Icon(Icons.refresh_rounded, size: 18),
                                            label: Text(l10n.retry),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 56),
                              if (pl != null) _MoreArtistAlbums(album: pl, serverUrl: serverUrl),
                              const SizedBox(height: 24),
                              Text(l10n.moreLikeThis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistTrackRow extends ConsumerWidget {
  const _PlaylistTrackRow({required this.index, required this.track, required this.onTap});
  final String index;
  final BaseItemDto track;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dur = track.runTimeTicks != null ? (track.runTimeTicks! ~/ 10000) : 0;
    final ms = dur;
    final m = (ms ~/ 60000);
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final durStr = ms > 0 ? '$m:$s' : '3:23';
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1A1A1A)))),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text(index, style: const TextStyle(color: Colors.white70, fontSize: 12))),
            Expanded(child: Text(track.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13))),
            const SizedBox(width: 12),
            Text(durStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Reproducir',
              icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              onPressed: () async {
                final id = track.id;
                if (id == null || id.isEmpty) return;
                final session = await ref.read(playbackSessionProvider(id).future);
                if (session != null) {
                  ref.read(musicPlayerProvider.notifier).playFromSession(session, track);
                }
              },
            ),
            const SizedBox(width: 4),
            const Icon(Icons.favorite_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}

class _MoreArtistAlbums extends ConsumerWidget {
  const _MoreArtistAlbums({required this.album, required this.serverUrl});
  final BaseItemDto album;
  final String? serverUrl;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final more = ref.watch(artistAlbumsProvider(album));
    final artist = (album.albumArtist?.trim().isNotEmpty == true ? album.albumArtist!.trim() : (album.artists?.firstOrNull?.trim() ?? '')).trim();
    final l10n = AppLocalizations.of(context)!;
    final title = artist.isNotEmpty ? l10n.moreAlbumsByArtist(artist) : l10n.moreAlbumsOfArtist;
    return more.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final item = list[i];
                  return SizedBox(width: 130, child: PosterCard(item: item, serverUrl: serverUrl, onTap: () => context.push('/music/album/${item.id}', extra: item)));
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
