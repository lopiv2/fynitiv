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

class ArtistDetailScreen extends ConsumerStatefulWidget {
  const ArtistDetailScreen({
    super.key,
    required this.artistName,
    this.deezerArtist,
    this.jellyfinArtist,
  });

  final String artistName;
  final DeezerArtist? deezerArtist;
  final BaseItemDto? jellyfinArtist;

  @override
  ConsumerState<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  int _loadedPages = 1;

  String _fmtCount(int count) {
    if (count >= 1000000000) return '${(count / 1000000000).toStringAsFixed(1)}B';
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  // Dedup interno Deezer (misma canción dos versiones) para garantizar 20 válidos
  List<DeezerTrack> _deduplicateDeezer(List<DeezerTrack> pool, int take) {
    final seen = <String>{};
    final out = <DeezerTrack>[];
    for (final d in pool) {
      final norm = d.title.toLowerCase().trim();
      if (norm.isEmpty) continue;
      // simple dedup por título normalizado (sin transliterar complejo, solo para Deezer-Deezer)
      final key = norm.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (seen.contains(key)) continue;
      seen.add(key);
      out.add(d);
      if (out.length >= take) break;
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ArtistDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName || oldWidget.jellyfinArtist?.id != widget.jellyfinArtist?.id) {
      _loadedPages = 1;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter > 500) return;
    final artistId = widget.jellyfinArtist?.id;
    final isById = artistId != null && artistId.isNotEmpty;
    if (isById) {
      final lastIndex = _loadedPages - 1;
      final lastAsync = ref.read(artistTracksByArtistIdPagedProvider(ArtistTracksByIdPageArgs(artistId: artistId, page: lastIndex)));
      if (lastAsync.isLoading) return;
      final lastLen = lastAsync.value?.length ?? 0;
      if (lastLen < kArtistTracksPageSize) return;
      setState(() => _loadedPages++);
    } else {
      final idxAsync = ref.read(artistJellyIndexByNameProvider(widget.artistName));
      if (idxAsync.isLoading) return;
      final total = idxAsync.value?.length ?? 0;
      final loaded = _loadedPages * kArtistTracksPageSize;
      if (loaded >= total) return;
      setState(() => _loadedPages++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final musicSkin = ref.watch(musicPlayerSkinControllerProvider).value;
    final isSpotify = musicSkin?.id == 'spotify';

    final serverUrl = ref.watch(authServerUrlProvider);
    final artistId = widget.jellyfinArtist?.id;
    final isById = artistId != null && artistId.isNotEmpty;
    final deezerQuery = widget.deezerArtist != null ? 'id:${widget.deezerArtist!.id}' : widget.artistName;
    final deezerDetailAsync = widget.deezerArtist != null ? ref.watch(deezerArtistDetailProvider('id:${widget.deezerArtist!.id}')) : null;

    String? headerImage;
    if (widget.deezerArtist != null && widget.deezerArtist!.picture.isNotEmpty) {
      headerImage = widget.deezerArtist!.picture;
    } else if (widget.jellyfinArtist != null && serverUrl != null && widget.jellyfinArtist!.id != null) {
      headerImage = itemImageUrl(serverUrl, widget.jellyfinArtist!, maxWidth: 800);
    }

    if (!isSpotify) {
      return _buildNonSpotifyScaffold(context, ref, headerImage, isById, artistId);
    }

    // Spotify: dos secciones separadas como Spotify real
    final jellyIndexAsync = isById
        ? ref.watch(artistJellyIndexByIdProvider(artistId))
        : ref.watch(artistJellyIndexByNameProvider(widget.artistName));
    final jellyIndexFull = jellyIndexAsync.value;

    List<BaseItemDto> jellyAll;
    bool jellyLoading;
    bool hasMore;
    bool loadingMore;
    if (isById) {
      final pageAsyncs = [
        for (int i = 0; i < _loadedPages; i++) ref.watch(artistTracksByArtistIdPagedProvider(ArtistTracksByIdPageArgs(artistId: artistId, page: i))),
      ];
      jellyAll = [for (final p in pageAsyncs) ...p.value ?? const <BaseItemDto>[]];
      jellyLoading = pageAsyncs.isNotEmpty && pageAsyncs.first.isLoading && jellyAll.isEmpty;
      final lastAsync = pageAsyncs.isNotEmpty ? pageAsyncs.last : null;
      final lastLen = lastAsync?.value?.length ?? 0;
      hasMore = lastAsync != null && !lastAsync.isLoading && lastLen >= kArtistTracksPageSize;
      loadingMore = lastAsync?.isLoading ?? false;
    } else {
      final total = jellyIndexFull?.length ?? 0;
      jellyLoading = jellyIndexAsync.isLoading && total == 0;
      final take = (_loadedPages * kArtistTracksPageSize).clamp(0, total);
      jellyAll = jellyIndexFull != null ? jellyIndexFull.take(take).toList() : const <BaseItemDto>[];
      hasMore = total > jellyAll.length;
      loadingMore = jellyIndexAsync.isLoading;
    }

    final deezerAsync = ref.watch(deezerArtistTopTracksWithLimitProvider(DeezerTopTracksArgs(query: deezerQuery, limit: 40)));
    final deezerLoading = deezerAsync.isLoading && (deezerAsync.value == null);
    final deezerRaw = deezerAsync.value ?? const <DeezerTrack>[];
    final deezerTop20 = _deduplicateDeezer(deezerRaw, 20);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        controller: _scrollController,
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
                  if (headerImage != null) Image.network(headerImage, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFF2A2A2A))),
                  if (headerImage == null) Container(color: const Color(0xFF2A2A2A)),
                  Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF121212)]))),
                  Positioned(
                    left: 24,
                    bottom: 32,
                    right: 24,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1)),
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
                    ]),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF121212),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(children: [
                  Builder(builder: (_) {
                    final firstJelly = jellyAll.isNotEmpty ? jellyAll.first : null;
                    return IconButton(
                      onPressed: firstJelly == null ? null : () => context.push('/player/${firstJelly.id}', extra: firstJelly),
                      icon: Container(width: 56, height: 56, decoration: const BoxDecoration(color: Color(0xFF1DB954), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32)),
                      iconSize: 56,
                      padding: EdgeInsets.zero,
                    );
                  }),
                  const SizedBox(width: 16),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.shuffle_rounded, color: Colors.white70, size: 28)),
                  const SizedBox(width: 8),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded, color: Colors.white70)),
                ]),
              ),
            ),
          ),
          // Sección 1: Populares Deezer (20)
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF121212),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Align(alignment: Alignment.centerLeft, child: Text(l10n.populares, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)))),
            ),
          ),
          if (deezerLoading)
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())))
          else if (deezerTop20.isEmpty)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text(l10n.noPlayableSongs, style: const TextStyle(color: Colors.white54, fontSize: 13)))),
          if (!deezerLoading && deezerTop20.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: deezerTop20.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF1A1A1A)),
                itemBuilder: (context, i) {
                  final dt = deezerTop20[i];
                  return _DeezerSuggestionRow(track: dt, rank: (i + 1).toString());
                },
              ),
            ),
          // Sección 2: En tu biblioteca (Jellyfin)
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF121212),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Align(alignment: Alignment.centerLeft, child: Text(l10n.inYourLibrary, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
              ),
            ),
          ),
          if (jellyLoading)
            const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: Center(child: AppLoader())))
          else if (jellyAll.isEmpty)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text(l10n.noSongsInLibrary, style: const TextStyle(color: Colors.white54, fontSize: 13)))),
          if (!jellyLoading && jellyAll.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: jellyAll.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF1A1A1A)),
                itemBuilder: (context, i) {
                  final track = jellyAll[i];
                  final playCount = track.userData?.playCount ?? 0;
                  final playCountStr = playCount > 0 ? _fmtCount(playCount) : '';
                  return _ArtistTrackRow(rank: (i + 1).toString(), track: track, serverUrl: serverUrl, playCountStr: playCountStr, onTap: () => context.push('/player/${track.id}', extra: track));
                },
              ),
            ),
          if (loadingMore) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: Center(child: AppLoader()))),
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF121212),
              child: Column(children: [
                if (!hasMore && (jellyAll.isNotEmpty || deezerTop20.isNotEmpty)) Padding(padding: const EdgeInsets.all(16), child: Text(l10n.libraryAndPopularCounts(jellyAll.length, deezerTop20.length), style: const TextStyle(color: Colors.white38, fontSize: 12))),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonSpotifyScaffold(BuildContext context, WidgetRef ref, String? headerImage, bool isById, String? artistId) {
    final serverUrl = ref.watch(authServerUrlProvider);
    final deezerQuery = widget.deezerArtist != null ? 'id:${widget.deezerArtist!.id}' : widget.artistName;
    final deezerAsync = ref.watch(deezerArtistTopTracksWithLimitProvider(DeezerTopTracksArgs(query: deezerQuery, limit: 40)));
    final deezerRaw = deezerAsync.value ?? const <DeezerTrack>[];
    final deezerTop20 = _deduplicateDeezer(deezerRaw, 20);
    final jellyIndexAsync = isById
        ? ref.watch(artistJellyIndexByIdProvider(artistId!))
        : ref.watch(artistJellyIndexByNameProvider(widget.artistName));
    final jellyIndexFull = jellyIndexAsync.value;

    List<BaseItemDto> jellyAll;
    bool firstLoading;
    bool hasMore;
    bool lastLoading;
    if (isById) {
      final pageAsyncs = [
        for (int i = 0; i < _loadedPages; i++) ref.watch(artistTracksByArtistIdPagedProvider(ArtistTracksByIdPageArgs(artistId: artistId!, page: i))),
      ];
      jellyAll = [for (final p in pageAsyncs) ...p.value ?? const <BaseItemDto>[]];
      firstLoading = pageAsyncs.first.isLoading && jellyAll.isEmpty;
      final lastLen = pageAsyncs.isNotEmpty ? (pageAsyncs.last.value?.length ?? 0) : 0;
      lastLoading = pageAsyncs.isNotEmpty ? pageAsyncs.last.isLoading : false;
      hasMore = !lastLoading && lastLen >= kArtistTracksPageSize;
    } else {
      final total = jellyIndexFull?.length ?? 0;
      firstLoading = jellyIndexAsync.isLoading && total == 0;
      final take = (_loadedPages * kArtistTracksPageSize).clamp(0, total);
      jellyAll = jellyIndexFull != null ? jellyIndexFull.take(take).toList() : const <BaseItemDto>[];
      lastLoading = jellyIndexAsync.isLoading;
      hasMore = total > jellyAll.length;
    }
    final isLoading = firstLoading || deezerAsync.isLoading;
    if (isLoading) {
      return Scaffold(backgroundColor: const Color(0xFF121212), appBar: AppBar(title: Text(widget.artistName, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF121212), iconTheme: const IconThemeData(color: Colors.white)), body: const Center(child: AppLoader()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: Text(widget.artistName, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF121212), iconTheme: const IconThemeData(color: Colors.white)),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        children: [
          if (headerImage != null) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(headerImage, height: 180, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.populares, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (deezerTop20.isEmpty) Text(AppLocalizations.of(context)!.noPopularTracks, style: const TextStyle(color: Colors.white54)),
          for (int i = 0; i < deezerTop20.length; i++) ...[
            _DeezerSuggestionRow(track: deezerTop20[i], rank: (i + 1).toString()),
            if (i != deezerTop20.length - 1) const Divider(height: 1, color: Colors.white12),
          ],
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context)!.inYourLibraryCount(jellyAll.length), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (jellyAll.isEmpty) Text(AppLocalizations.of(context)!.noSongsForArtist, style: const TextStyle(color: Colors.white54)),
          for (int i = 0; i < jellyAll.length; i++) ...[
            ListTile(
              leading: serverUrl != null ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(itemImageUrl(serverUrl, jellyAll[i], maxWidth: 200), width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 40, height: 40, color: const Color(0xFF2A2A2A)))) : null,
              title: Text(jellyAll[i].name ?? '', style: const TextStyle(color: Colors.white)),
              subtitle: Text('${i + 1}', style: const TextStyle(color: Colors.white54)),
              trailing: Image.asset('assets/images/jellyfin.png', height: 14, errorBuilder: (_, _, _) => const SizedBox.shrink()),
              onTap: () => context.push('/player/${jellyAll[i].id}', extra: jellyAll[i]),
            ),
            if (i != jellyAll.length - 1) const Divider(height: 1, color: Colors.white12),
          ],
          if (lastLoading) const Padding(padding: EdgeInsets.all(16), child: Center(child: AppLoader())),
          if (hasMore) FilledButton(onPressed: () => setState(() => _loadedPages++), child: Text(AppLocalizations.of(context)!.loadMore)),
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
          return Row(children: [
            SizedBox(width: 24, child: hovered ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16) : Text(rank, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center)),
            const SizedBox(width: 8),
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 40, height: 40, child: serverUrl != null ? Image.network(itemImageUrl(serverUrl!, track, maxWidth: 200), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFF2A2A2A))) : Container(color: const Color(0xFF2A2A2A)))),
              Positioned(right: 2, bottom: 2, child: Image.asset('assets/images/jellyfin.png', height: 10, errorBuilder: (_, _, _) => const SizedBox.shrink())),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Row(children: [Flexible(child: Text(track.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))), if (hasE) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF6A6A6A), borderRadius: BorderRadius.circular(2)), child: const Text('E', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800)))] ])),
            if (playCountStr.isNotEmpty) ...[const SizedBox(width: 12), Text(playCountStr, style: TextStyle(color: hovered ? Colors.white : Colors.white54, fontSize: 12, fontWeight: hovered ? FontWeight.w700 : FontWeight.w400))],
            const SizedBox(width: 12),
            if (hovered) ...[const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 18), const SizedBox(width: 12)],
            Text(durStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 12),
            const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
          ]);
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
          return Row(children: [
            SizedBox(width: 24, child: hovered ? const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16) : Text(rank, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center)),
            const SizedBox(width: 8),
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 40, height: 40, child: track.cover.isNotEmpty ? Image.network(track.cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFF2A2A2A))) : Container(color: const Color(0xFF2A2A2A)))),
              Positioned(right: 2, bottom: 2, child: Image.asset('assets/images/logo_deezer.png', height: 12, errorBuilder: (_, _, _) => const SizedBox.shrink())),
            ]),
            const SizedBox(width: 12),
            Expanded(child: Row(children: [Flexible(child: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14))), if (track.explicit) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF6A6A6A), borderRadius: BorderRadius.circular(2)), child: const Text('E', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w800)))] ])),
            const SizedBox(width: 16),
            Text(_fmt(track.duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 12),
            if (hovered) ...[const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 18), const SizedBox(width: 12)],
            const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 18),
          ]);
        }),
      ),
    );
  }
}
