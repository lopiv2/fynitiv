import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/music_player_skin_controller.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/image_url.dart';
import '../../library/application/library_providers.dart';
import '../application/deezer_providers.dart';
import 'deezer_preview_player.dart';

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({
    super.key,
    required this.artistName,
    this.deezerArtist,
    this.jellyfinArtist,
  });

  final String artistName;
  final DeezerArtist? deezerArtist;
  final BaseItemDto? jellyfinArtist;

  String _fmtCount(int count) {
    if (count >= 1000000000) return '${(count / 1000000000).toStringAsFixed(1)}B';
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final musicSkin = ref.watch(musicPlayerSkinControllerProvider).value;
    final isSpotify = musicSkin?.id == 'spotify';

    // Si no es Spotify, fallback simple
    if (!isSpotify) {
      final artistId = jellyfinArtist?.id;
      final tracksAsync = (artistId != null && artistId.isNotEmpty)
          ? ref.watch(artistTracksByArtistIdProvider(artistId))
          : ref.watch(artistTracksProvider(artistName));
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(title: Text(artistName, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF121212), iconTheme: const IconThemeData(color: Colors.white)),
        body: tracksAsync.when(
          loading: () => const Center(child: AppLoader()),
          error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.white54))),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1, color: Colors.white12),
            itemBuilder: (context, i) {
              final t = list[i];
              return ListTile(title: Text(t.name ?? '', style: const TextStyle(color: Colors.white)), onTap: () => context.push('/player/${t.id}', extra: t));
            },
          ),
        ),
      );
    }

    final serverUrl = ref.watch(authServerUrlProvider);
    final artistId = jellyfinArtist?.id;
    final jellyTracksAsync = (artistId != null && artistId.isNotEmpty)
        ? ref.watch(artistTracksByArtistIdProvider(artistId))
        : ref.watch(artistTracksProvider(artistName));
    final deezerQuery = deezerArtist != null ? 'id:${deezerArtist!.id}' : artistName;
    final deezerDetailAsync = deezerArtist != null ? ref.watch(deezerArtistDetailProvider('id:${deezerArtist!.id}')) : null;

    // Imagen cabecera: prioriza Deezer picture_xl, luego Jellyfin imagen si tiene id
    String? headerImage;
    if (deezerArtist != null && deezerArtist!.picture.isNotEmpty) {
      headerImage = deezerArtist!.picture;
    } else if (jellyfinArtist != null && serverUrl != null && jellyfinArtist!.id != null) {
      headerImage = itemImageUrl(serverUrl, jellyfinArtist!, maxWidth: 800);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: const Color(0xFF121212),
            leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.canPop() ? context.pop() : context.go('/music')),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (headerImage != null)
                    Image.network(headerImage, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFF2A2A2A))),
                  if (headerImage == null) Container(color: const Color(0xFF2A2A2A)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF121212)]),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 32,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1)),
                        const SizedBox(height: 6),
                        if (deezerDetailAsync != null)
                          deezerDetailAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                            data: (data) {
                              final fans = data?['nb_fan'] as int?;
                              if (fans == null || fans == 0) return const SizedBox.shrink();
                              return Text(l10n.monthlyListeners(_fmtCount(fans)), style: const TextStyle(color: Colors.white70, fontSize: 13));
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF121212),
              child: Column(
                children: [
                  // Controles: play + shuffle + more (sin Seguir)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      children: [
                        // Play primera canción si hay
                        jellyTracksAsync.when(
                          data: (list) => IconButton(
                            onPressed: list.isEmpty ? null : () => context.push('/player/${list.first.id}', extra: list.first),
                            icon: Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFF1DB954), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32)),
                            iconSize: 56,
                            padding: EdgeInsets.zero,
                          ),
                          loading: () => const SizedBox(width: 56, height: 56, child: Center(child: AppLoader())),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 16),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.shuffle_rounded, color: Colors.white70, size: 28)),
                        const SizedBox(width: 8),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Populares
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Align(alignment: Alignment.centerLeft, child: Text(l10n.populares, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
                  ),
                  jellyTracksAsync.when(
                    loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())),
                    error: (e, _) => Padding(padding: const EdgeInsets.all(24), child: Text('$e', style: const TextStyle(color: Colors.white54))),
                    data: (jellyList) {
                      if (jellyList.isNotEmpty) {
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: jellyList.length > 20 ? 20 : jellyList.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF1A1A1A)),
                          itemBuilder: (context, i) {
                            final track = jellyList[i];
                            final rank = (i + 1).toString();
                            final playCount = track.userData?.playCount ?? 0;
                            final playCountStr = playCount > 0 ? _fmtCount(playCount) : '';
                            return _ArtistTrackRow(
                              rank: rank,
                              track: track,
                              serverUrl: serverUrl,
                              playCountStr: playCountStr,
                              onTap: () => context.push('/player/${track.id}', extra: track),
                            );
                          },
                        );
                      }
                      // Vacío: mensaje + sugerencias Deezer (lazy: solo se pide a Deezer si Jellyfin no tiene canciones)
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Text(l10n.noPlayableSongs, style: const TextStyle(color: Colors.white54, fontSize: 14), textAlign: TextAlign.center),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final deezerTopAsync = ref.watch(deezerArtistTopTracksProvider(deezerQuery));
                              return deezerTopAsync.when(
                                loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: AppLoader())),
                                error: (e, _) => const SizedBox.shrink(),
                                data: (deezerList) {
                                  if (deezerList.isEmpty) return const SizedBox.shrink();
                                  final take = deezerList.length > 20 ? deezerList.sublist(0, 20) : deezerList;
                                  return ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: take.length,
                                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF1A1A1A)),
                                    itemBuilder: (context, j) {
                                      final dt = take[j];
                                      return _DeezerSuggestionRow(track: dt, rank: (j + 1).toString());
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistTrackRow extends StatelessWidget {
  const _ArtistTrackRow({required this.rank, required this.track, required this.serverUrl, required this.playCountStr, required this.onTap});
  final String rank;
  final BaseItemDto track;
  final String? serverUrl;
  final String playCountStr;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final durTicks = track.runTimeTicks;
    String durStr = '';
    if (durTicks != null && durTicks > 0) {
      final ms = durTicks ~/ 10000;
      final m = ms ~/ 60000;
      final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
      durStr = '$m:$s';
    }
    final hasE = (track.officialRating?.toLowerCase().contains('explicit') ?? false);
    return AppHover(
      effect: AppHoverEffect.highlight,
      config: const AppHoverConfig(highlightNormal: Colors.transparent, highlightHovered: Color(0xFF2A2A2A), borderRadius: BorderRadius.all(Radius.circular(4))),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Builder(builder: (context) {
          final hovered = AppHoverScope.of(context)?.hovered ?? false;
          return Row(
            children: [
              SizedBox(
                width: 24,
                child: hovered
                    ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16)
                    : Text(rank, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              ),
              const SizedBox(width: 8),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 40, height: 40, child: serverUrl != null ? Image.network(itemImageUrl(serverUrl!, track, maxWidth: 200), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFF2A2A2A))) : Container(color: const Color(0xFF2A2A2A)))),
              const SizedBox(width: 12),
              Expanded(child: Row(children: [Flexible(child: Text(track.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))), if (hasE) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF6A6A6A), borderRadius: BorderRadius.circular(2)), child: const Text('E', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800)))] ])),
              if (playCountStr.isNotEmpty) ...[const SizedBox(width: 12), Text(playCountStr, style: TextStyle(color: hovered ? Colors.white : Colors.white54, fontSize: 12, fontWeight: hovered ? FontWeight.w700 : FontWeight.w400))],
              const SizedBox(width: 12),
              if (hovered) ...[const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 18), const SizedBox(width: 12)],
              Text(durStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 12),
              const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
            ],
          );
        }),
      ),
    );
  }
}

class _DeezerSuggestionRow extends StatelessWidget {
  const _DeezerSuggestionRow({required this.track, required this.rank});
  final DeezerTrack track;
  final String rank;
  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
  @override
  Widget build(BuildContext context) {
    return AppHover(
      effect: AppHoverEffect.highlight,
      config: const AppHoverConfig(highlightNormal: Colors.transparent, highlightHovered: Color(0xFF2A2A2A), borderRadius: BorderRadius.all(Radius.circular(4))),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeezerPreviewPlayerScreen(track: track))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Builder(builder: (context) {
          final hovered = AppHoverScope.of(context)?.hovered ?? false;
          return Row(
            children: [
              SizedBox(
                width: 24,
                child: hovered
                    ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16)
                    : Text(rank, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 40, height: 40, child: track.cover.isNotEmpty ? Image.network(track.cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFF2A2A2A))) : Container(color: const Color(0xFF2A2A2A)))),
                  Positioned(right: 2, bottom: 2, child: Image.asset('assets/images/logo_deezer.png', height: 12, errorBuilder: (_, _, _) => const SizedBox.shrink())),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(child: Row(children: [Flexible(child: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))), if (track.explicit) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF6A6A6A), borderRadius: BorderRadius.circular(2)), child: const Text('E', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800)))] ])),
              const SizedBox(width: 16),
              Text(_fmt(track.duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 12),
              if (hovered) ...[const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 18), const SizedBox(width: 12)],
              const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
            ],
          );
        }),
      ),
    );
  }
}
