import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../core/skin/music_player_skin_controller.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/artist_logo_name.dart';
import '../../../core/widgets/responsive_carousel.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/image_url.dart';
import '../../library/application/library_providers.dart';
import '../application/deezer_providers.dart';
import 'artist_discography_screen.dart';
import 'deezer_preview_player.dart';
import 'widgets/artist_discography.dart';
import 'widgets/media_card.dart';

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

/// Pistas Jellyfin del artista con su estado de paginado.
class _JellyData {
  const _JellyData({
    required this.all,
    required this.firstLoading,
    required this.hasMore,
    required this.lastLoading,
  });

  final List<BaseItemDto> all;
  final bool firstLoading;
  final bool hasMore;
  final bool lastLoading;
}

// Dedup interno Deezer (misma canción dos versiones) para garantizar 20
// válidos. Top-level para usarlo también desde la rama clásica.
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

class _ArtistDetailScreenState extends ConsumerState<ArtistDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  int _loadedPages = 1;

  String _fmtCount(int count) {
    if (count >= 1000000000) {
      return '${(count / 1000000000).toStringAsFixed(1)}B';
    }
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ArtistDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistName != widget.artistName ||
        oldWidget.jellyfinArtist?.id != widget.jellyfinArtist?.id) {
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
      final lastAsync = ref.read(
        artistTracksByArtistIdPagedProvider(
          ArtistTracksByIdPageArgs(artistId: artistId, page: lastIndex),
        ),
      );
      if (lastAsync.isLoading) return;
      final lastLen = lastAsync.value?.length ?? 0;
      if (lastLen < kArtistTracksPageSize) return;
      setState(() => _loadedPages++);
    } else {
      final idxAsync = ref.read(
        artistJellyIndexByNameProvider(widget.artistName),
      );
      if (idxAsync.isLoading) return;
      final total = idxAsync.value?.length ?? 0;
      final loaded = _loadedPages * kArtistTracksPageSize;
      if (loaded >= total) return;
      setState(() => _loadedPages++);
    }
  }

  /// Pistas Jellyfin del artista (por id exacto o por índice de nombre).
  _JellyData _watchJellyTracks() {
    final artistId = widget.jellyfinArtist?.id;
    final isById = artistId != null && artistId.isNotEmpty;
    if (isById) {
      final pageAsyncs = [
        for (int i = 0; i < _loadedPages; i++)
          ref.watch(
            artistTracksByArtistIdPagedProvider(
              ArtistTracksByIdPageArgs(artistId: artistId, page: i),
            ),
          ),
      ];
      final all = [
        for (final p in pageAsyncs) ...p.value ?? const <BaseItemDto>[],
      ];
      final lastAsync = pageAsyncs.isNotEmpty ? pageAsyncs.last : null;
      final lastLen = lastAsync?.value?.length ?? 0;
      return _JellyData(
        all: all,
        firstLoading: pageAsyncs.isNotEmpty && pageAsyncs.first.isLoading,
        hasMore:
            lastAsync != null &&
            !(lastAsync.isLoading) &&
            lastLen >= kArtistTracksPageSize,
        lastLoading: lastAsync?.isLoading ?? false,
      );
    }
    final idxAsync = ref.watch(
      artistJellyIndexByNameProvider(widget.artistName),
    );
    final full = idxAsync.value;
    final total = full?.length ?? 0;
    final take = (_loadedPages * kArtistTracksPageSize).clamp(0, total);
    return _JellyData(
      all: full != null ? full.take(take).toList() : const <BaseItemDto>[],
      firstLoading: idxAsync.isLoading,
      hasMore: total > take,
      lastLoading: idxAsync.isLoading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final musicSkin = ref.watch(musicPlayerSkinControllerProvider).value;
    final isSpotify = musicSkin?.id == 'spotify';

    final serverUrl = ref.watch(authServerUrlProvider);
    final artistId = widget.jellyfinArtist?.id;
    final isById = artistId != null && artistId.isNotEmpty;
    final deezerQuery = widget.deezerArtist != null
        ? 'id:${widget.deezerArtist!.id}'
        : widget.artistName;

    String? headerImage;
    if (widget.deezerArtist != null &&
        widget.deezerArtist!.picture.isNotEmpty) {
      headerImage = widget.deezerArtist!.picture;
    } else if (widget.jellyfinArtist != null &&
        serverUrl != null &&
        widget.jellyfinArtist!.id != null) {
      headerImage = itemImageUrl(
        serverUrl,
        widget.jellyfinArtist!,
        maxWidth: 800,
      );
    }

    if (!isSpotify) {
      return _buildNonSpotifyScaffold(
        context,
        ref,
        headerImage: headerImage,
        artistId: artistId,
        artistName: widget.artistName,
        deezerArtist: widget.deezerArtist,
        jellyfinArtist: widget.jellyfinArtist,
        scrollController: _scrollController,
      );
    }

    // Solo skin Spotify: tabs Resumen / Relacionados / Sobre.
    final jelly = _watchJellyTracks();
    final deezerAsync = ref.watch(
      deezerArtistTopTracksWithLimitProvider(
        DeezerTopTracksArgs(query: deezerQuery, limit: 40),
      ),
    );
    final deezerTop = _deduplicateDeezer(
      deezerAsync.value ?? const <DeezerTrack>[],
      20,
    );
    final deezerLoading = deezerAsync.isLoading && (deezerAsync.value == null);

    // Artista Deezer efectivo: el que viene por navegación o el primero que
    // devuelve la búsqueda por nombre (para relacionados y fans).
    final searchedDeezer = widget.deezerArtist == null
        ? ref.watch(deezerArtistSearchProvider(widget.artistName)).value
        : null;
    final effectiveDeezer = widget.deezerArtist ?? searchedDeezer;
    final deezerDetailAsync = effectiveDeezer == null
        ? null
        : ref.watch(deezerArtistDetailProvider('id:${effectiveDeezer.id}'));
    final relatedAsync = effectiveDeezer == null || effectiveDeezer.id <= 0
        ? null
        : ref.watch(deezerRelatedArtistsProvider(effectiveDeezer.id));

    // Ficha Jellyfin efectiva: la que viene por navegación o la resuelta
    // por nombre (cubre artistas Deezer que sí están en la biblioteca).
    // Biografía: del artista Jellyfin; si no está en Jellyfin, la API de
    // Deezer no expone biografías y se muestra el aviso correspondiente.
    final lookedUpJelly = isById
        ? null
        : ref.watch(jellyfinArtistByNameProvider(widget.artistName)).value;
    final effectiveJelly = widget.jellyfinArtist ?? lookedUpJelly;
    final bioSourceId = effectiveJelly?.id;
    final jellyBio = (bioSourceId != null && bioSourceId.isNotEmpty)
        ? (ref.watch(itemDetailProvider(bioSourceId)).value?.overview?.trim() ??
              effectiveJelly?.overview?.trim() ??
              '')
        : '';
    final fans = deezerDetailAsync?.value?['nb_fan'] as int?;
    // Posición en el chart Deezer para la pastilla "#N del mundo".
    final chartArtists = ref.watch(deezerPopularArtistsProvider).value;
    int? worldRank;
    if (chartArtists != null) {
      final me = widget.artistName.toLowerCase().trim();
      for (final a in chartArtists) {
        if ((effectiveDeezer != null &&
                effectiveDeezer.id > 0 &&
                a.id == effectiveDeezer.id) ||
            a.name.toLowerCase().trim() == me) {
          if (a.position > 0) worldRank = a.position;
          break;
        }
      }
    }
    final discoAsync = ref.watch(
      artistDiscographyProvider((artistId ?? '', widget.artistName)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 320,
            backgroundColor: const Color(0xFF121212),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/music'),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (headerImage != null)
                    Image.network(
                      headerImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: const Color(0xFF2A2A2A)),
                    ),
                  if (headerImage == null)
                    Container(color: const Color(0xFF2A2A2A)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF121212)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 22,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ArtistLogoName(
                          artistName: widget.artistName,
                          artistEntity: widget.jellyfinArtist,
                          serverUrl: serverUrl,
                          logoHeight: 220,
                          maxWidth: 360,
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (deezerDetailAsync != null)
                          deezerDetailAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                            data: (data) {
                              final f = data?['nb_fan'] as int?;
                              if (f == null || f == 0) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                l10n.monthlyListeners(_fmtCount(f)),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: kSectionTitleFontSize / 1.3,
                                ),
                              );
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Builder(
                      builder: (_) {
                        final firstJelly = jelly.all.isNotEmpty
                            ? jelly.all.first
                            : null;
                        return IconButton(
                          onPressed: firstJelly == null
                              ? null
                              : () => context.push(
                                  '/player/${firstJelly.id}',
                                  extra: firstJelly,
                                ),
                          icon: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1DB954),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 32,
                            ),
                          ),
                          iconSize: 56,
                          padding: EdgeInsets.zero,
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.shuffle_rounded,
                        color: Colors.white70,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ..._summarySlivers(
            deezerTop: deezerTop,
            deezerLoading: deezerLoading,
            serverUrl: serverUrl,
            isById: isById,
            artistId: artistId,
            deezerQuery: deezerQuery,
            discoAlbums: discoAsync.value ?? const <BaseItemDto>[],
            discoLoading: discoAsync.isLoading,
            onDiscoRetry: () => ref.invalidate(
              artistDiscographyProvider((artistId ?? '', widget.artistName)),
            ),
            onShowAll: (visible) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ArtistDiscographyScreen(
                  artistName: widget.artistName,
                  albums: visible,
                ),
              ),
            ),
            infoBio: jellyBio,
            infoFans: fans,
            infoImage: headerImage,
            infoRank: worldRank,
          ),
          _relatedSliver(relatedAsync),
        ],
      ),
    );
  }

  /// Tab Resumen (Spotify): Populares Deezer + Discografía + Información.
  List<Widget> _summarySlivers({
    required List<DeezerTrack> deezerTop,
    required bool deezerLoading,
    required String? serverUrl,
    required bool isById,
    required String? artistId,
    required String deezerQuery,
    required List<BaseItemDto> discoAlbums,
    required bool discoLoading,
    required VoidCallback onDiscoRetry,
    required void Function(List<BaseItemDto> visible) onShowAll,
    required String infoBio,
    required int? infoFans,
    required String? infoImage,
    required int? infoRank,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return [
      const SliverToBoxAdapter(
        child: ColoredBox(
          color: Color(0xFF121212),
          child: SizedBox(height: kBetweenSectionsGap),
        ),
      ),
      SliverToBoxAdapter(
        child: Container(
          color: const Color(0xFF121212),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.populares,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: kSectionTitleFontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
      // Separación estándar entre secciones antes de Discografía.
      const SliverToBoxAdapter(
        child: ColoredBox(
          color: Color(0xFF121212),
          child: SizedBox(height: kSectionTitleGap),
        ),
      ),
      if (deezerLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: AppLoader()),
          ),
        )
      else if (deezerTop.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.noPlayableSongs,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(
                      deezerArtistTopTracksWithLimitProvider(
                        DeezerTopTracksArgs(query: deezerQuery, limit: 40),
                      ),
                    );
                    if (isById && artistId != null) {
                      ref.invalidate(artistJellyIndexByIdProvider(artistId));
                    } else {
                      ref.invalidate(
                        artistJellyIndexByNameProvider(widget.artistName),
                      );
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      if (!deezerLoading && deezerTop.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: deezerTop.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: Color(0xFF1A1A1A)),
            itemBuilder: (context, i) {
              final dt = deezerTop[i];
              return _DeezerSuggestionRow(track: dt, rank: (i + 1).toString());
            },
          ),
        ),
      // Separación estándar entre secciones antes de Discografía.
      const SliverToBoxAdapter(
        child: ColoredBox(
          color: Color(0xFF121212),
          child: SizedBox(height: kBetweenSectionsGap),
        ),
      ),
      // Sección Discografía: carrusel de álbumes de tu biblioteca.
      SliverToBoxAdapter(
        child: Container(
          color: const Color(0xFF121212),
          child: DiscographySection(
            albums: discoAlbums,
            isLoading: discoLoading,
            serverUrl: serverUrl,
            onRetry: onDiscoRetry,
            onShowAll: onShowAll,
          ),
        ),
      ),
      const SliverToBoxAdapter(
        child: ColoredBox(
          color: Color(0xFF121212),
          child: SizedBox(height: kSectionTitleGap),
        ),
      ),
      // Sección Información: foto con oyentes y bio (sustituye al tab Sobre).
      if (infoBio.isNotEmpty || (infoFans != null && infoFans != 0))
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFF121212),
            child: _ArtistInfoSection(
              bio: infoBio,
              fans: infoFans,
              imageUrl: infoImage,
              rank: infoRank,
            ),
          ),
        ),
      const SliverToBoxAdapter(
        child: ColoredBox(
          color: Color(0xFF121212),
          child: SizedBox(height: 24),
        ),
      ),
    ];
  }

  /// Sección Artistas relacionados tras Información: carrusel horizontal
  /// con foto y nombre. Si no hay datos se oculta sin hacer ruido.
  Widget _relatedSliver(AsyncValue<List<DeezerArtist>>? relatedAsync) {
    final l10n = AppLocalizations.of(context)!;
    if (relatedAsync == null) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return relatedAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: AppLoader()),
        ),
      ),
      error: (_, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.artistNoRelated,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(
                  deezerArtistSearchProvider(widget.artistName),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Text(
                  l10n.artistTabRelated,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: kSectionTitleFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: kSectionTitleGap),
              _RelatedCarousel(artists: list),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

/// Sección Información bajo la discografía (solo Spotify): foto con la
/// pastilla de ranking, oyentes mensuales y bio encima. Tap = expandir.
class _ArtistInfoSection extends StatefulWidget {
  const _ArtistInfoSection({
    required this.bio,
    required this.fans,
    required this.imageUrl,
    required this.rank,
  });

  final String bio;
  final int? fans;
  final String? imageUrl;
  final int? rank;

  @override
  State<_ArtistInfoSection> createState() => _ArtistInfoSectionState();
}

class _ArtistInfoSectionState extends State<_ArtistInfoSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final fansLine = widget.fans == null || widget.fans == 0
        ? null
        : l10n.monthlyListeners(
            NumberFormat.decimalPattern(l10n.localeName).format(widget.fans),
          );
    final bio = widget.bio.isEmpty ? l10n.personNoBiography : widget.bio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Text(
            l10n.artistInfoTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: kSectionTitleFontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AppHover(
            effect: AppHoverEffect.scale,
            config: AppHoverConfig.scaleOnly(
              scale: 1.01,
              radius: BorderRadius.circular(12),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.imageUrl != null)
                      Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: const Color(0xFF2A2A2A)),
                      )
                    else
                      Container(color: const Color(0xFF2A2A2A)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB3000000)],
                          stops: [0.35, 1],
                        ),
                      ),
                    ),
                    if (widget.rank != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2B7FFF),
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '#${widget.rank}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                l10n.artistWorldRank,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (fansLine != null)
                            Text(
                              fansLine,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    blurRadius: 6,
                                    color: Colors.black87,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          if (fansLine != null) const SizedBox(height: 4),
                          Text(
                            bio,
                            maxLines: _expanded ? null : 4,
                            overflow: _expanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: kBioFontSize,
                              height: 1.4,
                              shadows: [
                                Shadow(
                                  blurRadius: 6,
                                  color: Colors.black87,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Rama clásica (skins no Spotify): cabecera + Populares + Discografía.
/// Función top-level con dependencias explícitas.
Widget _buildNonSpotifyScaffold(
  BuildContext context,
  WidgetRef ref, {
  required String? headerImage,
  required String? artistId,
  required String artistName,
  required DeezerArtist? deezerArtist,
  required BaseItemDto? jellyfinArtist,
  required ScrollController scrollController,
}) {
  final serverUrl = ref.watch(authServerUrlProvider);
  final deezerQuery = deezerArtist != null
      ? 'id:${deezerArtist.id}'
      : artistName;
  final deezerAsync = ref.watch(
    deezerArtistTopTracksWithLimitProvider(
      DeezerTopTracksArgs(query: deezerQuery, limit: 40),
    ),
  );
  final deezerRaw = deezerAsync.value ?? const <DeezerTrack>[];
  final deezerTop20 = _deduplicateDeezer(deezerRaw, 20);
  final discoAsync = ref.watch(
    artistDiscographyProvider((artistId ?? '', artistName)),
  );
  final isLoading = deezerAsync.isLoading;
  final appBarTitle = ArtistLogoName(
    artistName: artistName,
    artistEntity: jellyfinArtist,
    serverUrl: serverUrl,
    logoHeight: 28,
    textStyle: const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  );
  if (isLoading) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: appBarTitle,
        backgroundColor: const Color(0xFF121212),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const Center(child: AppLoader()),
    );
  }
  return Scaffold(
    backgroundColor: const Color(0xFF121212),
    appBar: AppBar(
      title: appBarTitle,
      backgroundColor: const Color(0xFF121212),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    body: ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        if (headerImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              headerImage,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.populares,
          style: const TextStyle(
            color: Colors.white,
            fontSize: kSectionTitleFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        if (deezerTop20.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.noPopularTracks,
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  ref.invalidate(
                    deezerArtistTopTracksWithLimitProvider(
                      DeezerTopTracksArgs(query: deezerQuery, limit: 40),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        for (int i = 0; i < deezerTop20.length; i++) ...[
          _DeezerSuggestionRow(track: deezerTop20[i], rank: (i + 1).toString()),
          if (i != deezerTop20.length - 1)
            const Divider(height: 1, color: Colors.white12),
        ],
        const SizedBox(height: 8),
        DiscographySection(
          albums: discoAsync.value ?? const <BaseItemDto>[],
          isLoading: discoAsync.isLoading,
          serverUrl: serverUrl,
          onRetry: () => ref.invalidate(
            artistDiscographyProvider((artistId ?? '', artistName)),
          ),
          onShowAll: (visible) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ArtistDiscographyScreen(
                artistName: artistName,
                albums: visible,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Carrusel horizontal de artistas relacionados (foto circular + nombre).
class _RelatedCarousel extends StatelessWidget {
  const _RelatedCarousel({required this.artists});

  final List<DeezerArtist> artists;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCarousel(
      itemCount: artists.length,
      spacing: 16,
      extraHeight: 74,
      itemBuilder: (context, i, cardWidth) {
        final artist = artists[i];
        return MediaCard(
          title: artist.name,
          subtitle: AppLocalizations.of(context)!.artist,
          circular: true,
          imageSize: cardWidth - 24,
          width: cardWidth,
          padding: const EdgeInsets.all(12),
          titleWeight: FontWeight.w700,
          imageUrl: artist.picture.isNotEmpty ? artist.picture : null,
          playSize: 46,
          onTap: () => context.push(
            '/music/artist/${Uri.encodeComponent(artist.name)}',
            extra: artist,
          ),
        );
      },
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
      config: const AppHoverConfig(
        highlightNormal: Colors.transparent,
        highlightHovered: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeezerPreviewPlayerScreen(track: track),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Builder(
          builder: (context) {
            final hovered = AppHoverScope.of(context)?.hovered ?? false;
            return Row(
              children: [
                SizedBox(
                  width: 24,
                  child: hovered
                      ? const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                      : Text(
                          rank,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
                const SizedBox(width: 8),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: track.cover.isNotEmpty
                            ? Image.network(
                                track.cover,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Container(color: const Color(0xFF2A2A2A)),
                              )
                            : Container(color: const Color(0xFF2A2A2A)),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Image.asset(
                        'assets/images/logo_deezer.png',
                        height: 12,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (track.explicit) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A6A6A),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'E',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _fmt(track.duration),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 12),
                if (hovered) ...[
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                ],
                const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white54,
                  size: 18,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
