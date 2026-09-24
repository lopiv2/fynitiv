import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../music/application/soloud_music_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../application/jukebox_providers.dart';
import '../application/ost_providers.dart';
import '../application/romm_providers.dart';
import '../domain/game_ost_track.dart';
import '../domain/romm_music_facet.dart';
import 'widgets/game_video_background.dart';
import 'widgets/ost_favorite_button.dart';

/// Jukebox de bandas sonoras (`/games/jukebox`) sobre el player global
/// `soloudMusicProvider` (mismo `SoLoud.instance` que la música Jellyfin).
/// Dos filas de atajos (Mezclas y Biblioteca) bajo los chips, como en la
/// captura de referencia, más pestañas y reproducción sin mini local.
class JukeboxScreen extends ConsumerStatefulWidget {
  const JukeboxScreen({super.key});

  @override
  ConsumerState<JukeboxScreen> createState() => _JukeboxScreenState();
}

class _JukeboxScreenState extends ConsumerState<JukeboxScreen> {
  static const _tabs = [
    'games',
    'artists',
    'albums',
    'genres',
    'years',
    'platforms',
    'favorites',
  ];

  String _tab = 'games';
  String _search = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  int? _selGameId;
  String? _selGameName;
  String? _facetValue;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _search = v.trim());
    });
  }

  void _pickTab(String tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _selGameId = null;
      _selGameName = null;
      _facetValue = null;
    });
  }

  Future<void> _playTracks(List<GameOstTrack> tracks, int index) async {
    if (tracks.isEmpty) return;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    await ref.read(soloudMusicProvider.notifier).playOstQueue(
          tracks: tracks,
          startIndex: index,
          serverUrl: repo.serverUrl,
          authToken: repo.token,
        );
  }

  Future<void> _shuffleAll() async {
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    final tracks = await ref.read(
      jukeboxTracksProvider(JukeboxTracksQuery(search: _search)).future,
    );
    if (tracks.isEmpty || !mounted) return;
    await ref.read(soloudMusicProvider.notifier).playOstQueue(
          tracks: tracks,
          serverUrl: repo.serverUrl,
          authToken: repo.token,
          shuffle: true,
        );
  }

  Future<void> _playFreeRadio() async {
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    final all = await ref.read(
      jukeboxTracksProvider(JukeboxTracksQuery(search: _search)).future,
    );
    if (all.isEmpty || !mounted) return;
    final shuffled = List<GameOstTrack>.from(all)..shuffle();
    var secs = 0.0;
    final picked = <GameOstTrack>[];
    for (final t in shuffled) {
      final d = t.durationSeconds;
      picked.add(t);
      secs += d > 0 ? d : 180;
      if (secs >= 60 * 60) break;
    }
    await ref.read(soloudMusicProvider.notifier).playOstQueue(
          tracks: picked.isEmpty ? shuffled.take(20).toList() : picked,
          serverUrl: repo.serverUrl,
          authToken: repo.token,
          shuffle: false,
        );
  }

  Future<void> _playRecentlyAdded() async {
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    final tracks = await repo.getMusicTracks(
      orderBy: 'added',
      orderDir: 'desc',
      limit: 25,
    );
    if (tracks.isEmpty || !mounted) return;
    await ref.read(soloudMusicProvider.notifier).playOstQueue(
          tracks: [for (final t in tracks) GameOstTrack(name: t.displayName, url: t.streamUrl, duration: t.displayDuration, artist: t.artist, album: t.album, romFileId: t.romFileId, isFavorite: t.isFavorite, gameName: t.gameName)],
          serverUrl: repo.serverUrl,
          authToken: repo.token,
        );
  }

  Future<void> _playFavorites() async {
    _pickTab('favorites');
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    final fav = await ref.read(jukeboxTracksProvider(const JukeboxTracksQuery(favoritesOnly: true)).future);
    if (fav.isEmpty || !mounted) return;
    await ref.read(soloudMusicProvider.notifier).playOstQueue(
          tracks: fav,
          serverUrl: repo.serverUrl,
          authToken: repo.token,
        );
  }

  Future<void> _openDecades() async {
    final l10n = AppLocalizations.of(context)!;
    final years = await ref.read(jukeboxFacetProvider('years').future);
    if (!mounted) return;
    final decades = <int, int>{};
    for (final v in years) {
      final y = int.tryParse(v.value);
      if (y == null) continue;
      final d = (y ~/ 10) * 10;
      decades[d] = (decades[d] ?? 0) + v.count;
    }
    if (decades.isEmpty) return;
    final sorted = decades.keys.toList()..sort();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1E2633),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(l10n.jukeboxDecadeMix, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
          for (final d in sorted)
            ListTile(
              title: Text(l10n.jukeboxDecadeRange(d.toString(), (d + 9).toString()), style: const TextStyle(color: Colors.white)),
              trailing: Text('${decades[d]}', style: const TextStyle(color: Colors.white38)),
              onTap: () => Navigator.of(context).pop(d),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    final tracks = await ref.read(
      jukeboxTracksProvider(JukeboxTracksQuery(minYear: picked, maxYear: picked + 9)).future,
    );
    if (tracks.isEmpty || !mounted) return;
    await ref.read(soloudMusicProvider.notifier).playOstQueue(
          tracks: tracks,
          serverUrl: repo.serverUrl,
          authToken: repo.token,
        );
  }

  JukeboxTracksQuery? get _tracksQuery {
    if (_tab == 'favorites') {
      return JukeboxTracksQuery(search: _search, favoritesOnly: true);
    }
    if (_tab == 'platforms') {
      final v = _facetValue;
      if (v == null || v.isEmpty) return null;
      // Resolver platformId del facet seleccionado
      final facet = ref.read(jukeboxFacetProvider('platforms')).value;
      final entry = facet?.where((e) => e.value == v).firstOrNull;
      final id = entry?.platformId;
      if (id == null) return null;
      return JukeboxTracksQuery(search: _search, platformIds: [id]);
    }
    final v = _facetValue;
    if (v == null || v.isEmpty) return null;
    return switch (_tab) {
      'artists' => JukeboxTracksQuery(search: _search, artist: v),
      'albums' => JukeboxTracksQuery(search: _search, album: v),
      'genres' => JukeboxTracksQuery(search: _search, genre: v),
      'years' => JukeboxTracksQuery(search: _search, year: int.tryParse(v)),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(skinControllerProvider).value;
    final topPadding = libraryPageTopPadding(context, skin);
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: GameVideoBackground(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(accent: accent, onBack: () => context.pop(), onShuffle: () => unawaited(_shuffleAll())),
                    const SizedBox(height: 12),
                    _SearchField(controller: _searchController, onChanged: _onSearchChanged),
                    const SizedBox(height: 10),
                    _TabChips(tab: _tab, onPick: _pickTab),
                    const SizedBox(height: 14),
                    _MixesRow(
                      onFreeRadio: () => unawaited(_playFreeRadio()),
                      onDecades: () => unawaited(_openDecades()),
                      onRecent: () => unawaited(_playRecentlyAdded()),
                      onFavorites: () => unawaited(_playFavorites()),
                    ),
                    const SizedBox(height: 12),
                    _LibraryRow(
                      onPlayAll: () => unawaited(_shuffleAll()),
                      onPick: _pickTab,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 380,
                                  child: _LeftPane(
                                    tab: _tab,
                                    search: _search,
                                    selGameId: _selGameId,
                                    facetValue: _facetValue,
                                    onPickGame: (g) => setState(() {
                                      _selGameId = g.romId;
                                      _selGameName = g.name;
                                    }),
                                    onPickFacet: (v) => setState(() => _facetValue = v),
                                    onRetry: () => setState(() {}),
                                  ),
                                ),
                                const VerticalDivider(color: Colors.white12, width: 24),
                                Expanded(child: _rightPane(l10n, true)),
                              ],
                            )
                          : _narrowPane(l10n),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _rightPane(AppLocalizations l10n, bool wide) {
    final gameId = _selGameId;
    final query = _tracksQuery;
    if (_tab == 'games' && gameId == null) return _PickHint(wide: wide);
    if (_tab != 'games' && _tab != 'favorites' && query == null) {
      return _PickHint(wide: wide);
    }
    final title = _tab == 'games'
        ? (_selGameName ?? '')
        : _tab == 'favorites'
            ? l10n.jukeboxFavorites
            : (_facetValue ?? '');
    if (gameId != null) {
      final ostAsync = ref.watch(ostTracksProvider(gameId));
      return _TrackListView(
        title: title,
        tracksAsync: ostAsync,
        subtitleFallback: _selGameName ?? '',
        showBack: !wide,
        onBack: () => setState(() {
          _selGameId = null;
          _selGameName = null;
        }),
        onPlay: _playTracks,
        onRetry: () => ref.invalidate(ostTracksProvider(gameId)),
      );
    }
    final q = query!;
    final tracksAsync = ref.watch(jukeboxTracksProvider(q));
    return _TrackListView(
      title: title,
      tracksAsync: tracksAsync,
      subtitleFallback: '',
      showBack: !wide && _tab != 'favorites',
      onBack: () => setState(() => _facetValue = null),
      onPlay: _playTracks,
      onRetry: () => ref.invalidate(jukeboxTracksProvider(q)),
    );
  }

  Widget _narrowPane(AppLocalizations l10n) {
    final inTracks = (_tab == 'games' && _selGameId != null) || (_tab == 'favorites') || (_tracksQuery != null);
    if (inTracks) return _rightPane(l10n, false);
    return _LeftPane(
      tab: _tab,
      search: _search,
      selGameId: _selGameId,
      facetValue: _facetValue,
      onPickGame: (g) => setState(() {
        _selGameId = g.romId;
        _selGameName = g.name;
      }),
      onPickFacet: (v) => setState(() => _facetValue = v),
      onRetry: () => setState(() {}),
    );
  }
}

/// Dos filas de atajos bajo los chips, estilo captura de referencia.
class _MixesRow extends ConsumerWidget {
  const _MixesRow({required this.onFreeRadio, required this.onDecades, required this.onRecent, required this.onFavorites});
  final VoidCallback onFreeRadio;
  final VoidCallback onDecades;
  final VoidCallback onRecent;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final favCount = ref.watch(jukeboxFacetProvider('favorites')).value?.length ?? ref.watch(jukeboxTracksProvider(const JukeboxTracksQuery(favoritesOnly: true))).value?.length ?? 0;
    // Recientes: limitar a 25 como en la captura
    const recentCount = 25;
    final decadesCount = ref.watch(jukeboxFacetProvider('years')).value?.fold<Set<int>>(<int>{}, (s, v) {
          final y = int.tryParse(v.value);
          if (y != null) s.add((y ~/ 10) * 10);
          return s;
        }).length ??
        1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.jukeboxMixes, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _JukeboxShortcutCard(icon: Icons.radar_rounded, title: l10n.jukeboxFreeRadio, subtitle: l10n.jukeboxFreeRadioHint, onTap: onFreeRadio),
              _JukeboxShortcutCard(icon: Icons.calendar_month_rounded, title: l10n.jukeboxDecadeMix, subtitle: decadesCount == 1 ? l10n.jukeboxDecadeHint : l10n.jukeboxDecadesHint(decadesCount), onTap: onDecades),
              _JukeboxShortcutCard(icon: Icons.schedule_rounded, title: l10n.jukeboxRecentlyAdded, subtitle: l10n.jukeboxRecentlyAddedSub(recentCount), onTap: onRecent),
              _JukeboxShortcutCard(icon: Icons.favorite_rounded, title: l10n.jukeboxFavoriteTracks, subtitle: l10n.jukeboxFavoriteSub(favCount), onTap: onFavorites),
            ],
          ),
        ),
      ],
    );
  }
}

class _LibraryRow extends ConsumerWidget {
  const _LibraryRow({required this.onPlayAll, required this.onPick});
  final VoidCallback onPlayAll;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stats = ref.watch(jukeboxStatsProvider).value;
    final albums = ref.watch(jukeboxFacetProvider('albums')).value?.length ?? 0;
    final platforms = ref.watch(jukeboxFacetProvider('platforms')).value?.length ?? 0;
    final artists = ref.watch(jukeboxFacetProvider('artists')).value?.length ?? 0;
    final genres = ref.watch(jukeboxFacetProvider('genres')).value?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.jukeboxLibrary, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _JukeboxShortcutCard(icon: Icons.queue_music_rounded, title: l10n.jukeboxPlayAll, subtitle: l10n.jukeboxPlayAllSub(stats?.totalTracks ?? 0), onTap: onPlayAll),
              _JukeboxShortcutCard(icon: Icons.album_rounded, title: l10n.jukeboxOstByAlbum, subtitle: l10n.jukeboxFacetCountAlbums(albums), onTap: () => onPick('albums')),
              _JukeboxShortcutCard(icon: Icons.sports_esports_rounded, title: l10n.jukeboxOstByPlatform, subtitle: platforms == 1 ? l10n.jukeboxFacetCountPlatforms(platforms) : l10n.jukeboxFacetCountPlatformsPlural(platforms), onTap: () => onPick('platforms')),
              _JukeboxShortcutCard(icon: Icons.person_rounded, title: l10n.jukeboxOstByArtist, subtitle: l10n.jukeboxFacetCountArtists(artists), onTap: () => onPick('artists')),
              _JukeboxShortcutCard(icon: Icons.category_rounded, title: l10n.jukeboxOstByGenre, subtitle: l10n.jukeboxFacetCountGenres(genres), onTap: () => onPick('genres')),
            ],
          ),
        ),
      ],
    );
  }
}

class _JukeboxShortcutCard extends StatelessWidget {
  const _JukeboxShortcutCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: AppHover(
        effect: AppHoverEffect.highlightWithScale,
        onTap: onTap,
        child: Container(
          width: 132,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white70, size: 22),
              ),
              const SizedBox(height: 10),
              Text(title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 1, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.accent, required this.onBack, required this.onShuffle});
  final Color accent;
  final VoidCallback onBack;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stats = ref.watch(jukeboxStatsProvider);
    return Row(
      children: [
        IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70)),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.jukeboxTitle, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              stats.when(data: (s) => Text(l10n.jukeboxStats(s.totalTracks, s.displayTotal), style: const TextStyle(color: Colors.white38, fontSize: 12)), loading: () => const SizedBox(height: 14), error: (_, _) => const SizedBox.shrink()),
            ],
          ),
        ),
        IconButton(tooltip: l10n.jukeboxShuffleAll, onPressed: onShuffle, icon: Icon(Icons.shuffle_rounded, color: accent, size: 24)),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: l10n.jukeboxSearchHint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
      ),
    );
  }
}

class _TabChips extends StatelessWidget {
  const _TabChips({required this.tab, required this.onPick});
  final String tab;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = <String, String>{
      'games': l10n.jukeboxGames,
      'artists': l10n.jukeboxArtists,
      'albums': l10n.jukeboxAlbums,
      'genres': l10n.jukeboxGenres,
      'years': l10n.jukeboxYears,
      'platforms': l10n.jukeboxPlatforms,
      'favorites': l10n.jukeboxFavorites,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in _JukeboxScreenState._tabs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[t]!),
                selected: tab == t,
                onSelected: (_) => onPick(t),
                selectedColor: Colors.white.withValues(alpha: 0.16),
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                labelStyle: TextStyle(color: tab == t ? Colors.white : Colors.white60, fontSize: 13, fontWeight: FontWeight.w600),
                side: const BorderSide(color: Colors.white12),
              ),
            ),
        ],
      ),
    );
  }
}

class _LeftPane extends ConsumerWidget {
  const _LeftPane({required this.tab, required this.search, required this.selGameId, required this.facetValue, required this.onPickGame, required this.onPickFacet, required this.onRetry});
  final String tab;
  final String search;
  final int? selGameId;
  final String? facetValue;
  final ValueChanged<MusicGameEntry> onPickGame;
  final ValueChanged<String> onPickFacet;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tab == 'games') {
      final games = ref.watch(jukeboxGamesProvider(search));
      return games.when(
        loading: () => const Center(child: AppLoader()),
        error: (_, _) => _PaneError(onRetry: () {
          ref.invalidate(jukeboxGamesProvider(search));
          onRetry();
        }),
        data: (list) {
          if (list.isEmpty) return const _PaneEmpty();
          return GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
            itemCount: list.length,
            itemBuilder: (context, i) => _GameCard(game: list[i], selected: list[i].romId == selGameId, onTap: () => onPickGame(list[i])),
          );
        },
      );
    }
    if (tab == 'favorites') return const SizedBox.shrink();
    final facet = ref.watch(jukeboxFacetProvider(tab));
    return facet.when(
      loading: () => const Center(child: AppLoader()),
      error: (_, _) => _PaneError(onRetry: () {
        ref.invalidate(jukeboxFacetProvider(tab));
        onRetry();
      }),
      data: (list) {
        if (list.isEmpty) return const _PaneEmpty();
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: list.length,
          itemBuilder: (context, i) {
            final v = list[i];
            final selected = v.value == facetValue;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppHover(
                effect: AppHoverEffect.highlight,
                onTap: () => onPickFacet(v.value),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: selected ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
                  child: Row(
                    children: [
                      Expanded(child: Text(v.value.isEmpty ? '—' : v.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 8),
                      Text('${v.count}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.selected, required this.onTap});
  final MusicGameEntry game;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return AppHover(
      effect: AppHoverEffect.highlightWithScale,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? Colors.white54 : Colors.white12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: game.coverUrl != null && game.coverUrl!.isNotEmpty
                    ? Image.network(game.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _CoverFallback())
                    : const _CoverFallback(),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(8, 6, 8, 2), child: Text(game.name.isEmpty ? '—' : game.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
            Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Text('${game.count}', style: const TextStyle(color: Colors.white38, fontSize: 11))),
          ],
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();
  @override
  Widget build(BuildContext context) => Container(color: Colors.white.withValues(alpha: 0.05), child: const Center(child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 36)));
}

class _TrackListView extends ConsumerWidget {
  const _TrackListView({required this.title, required this.tracksAsync, required this.subtitleFallback, required this.showBack, required this.onBack, required this.onPlay, required this.onRetry});
  final String title;
  final AsyncValue<List<GameOstTrack>> tracksAsync;
  final String subtitleFallback;
  final bool showBack;
  final VoidCallback onBack;
  final void Function(List<GameOstTrack>, int) onPlay;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playingUrl = ref.watch(soloudMusicProvider.select((s) => s.session?.streamUrl));
    return tracksAsync.when(
      loading: () => const Center(child: AppLoader()),
      error: (_, _) => _PaneError(onRetry: onRetry),
      data: (tracks) {
        if (tracks.isEmpty) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_TrackListTitle(title: title, showBack: showBack, onBack: onBack), Expanded(child: Center(child: Text(l10n.jukeboxNoResults, style: const TextStyle(color: Colors.white38, fontSize: 13))))]);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TrackListTitle(title: title, showBack: showBack, onBack: onBack),
            Text(l10n.ostTracksCount(tracks.length), style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: tracks.length,
                itemBuilder: (context, i) {
                  final t = tracks[i];
                  final isCurrent = playingUrl != null && playingUrl == t.url;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    highlightColor: Colors.white.withValues(alpha: 0.06),
                    focusColor: Colors.white.withValues(alpha: 0.08),
                    onTap: () => onPlay(tracks, i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(color: isCurrent ? Colors.white.withValues(alpha: 0.07) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          SizedBox(width: 26, child: isCurrent ? const Icon(Icons.graphic_eq_rounded, color: Color(0xFF8B7CF6), size: 18) : Text('${i + 1}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12))),
                          const SizedBox(width: 4),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isCurrent ? const Color(0xFF8B7CF6) : Colors.white, fontSize: 14, fontWeight: FontWeight.w600)), Text(t.subtitle(subtitleFallback), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 12))])),
                          if (t.duration != null && t.duration!.isNotEmpty) Text(t.duration!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          OstFavoriteButton(track: t),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TrackListTitle extends StatelessWidget {
  const _TrackListTitle({required this.title, required this.showBack, required this.onBack});
  final String title;
  final bool showBack;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Row(children: [if (showBack) IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20)), Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)))]);
}

class _PickHint extends StatelessWidget {
  const _PickHint({required this.wide});
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.library_music_rounded, color: Colors.white24, size: 48), const SizedBox(height: 10), Text(l10n.jukeboxPickHint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 13))]));
  }
}

class _PaneEmpty extends StatelessWidget {
  const _PaneEmpty();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(child: Text(l10n.jukeboxNoResults, style: const TextStyle(color: Colors.white38, fontSize: 13)));
  }
}

class _PaneError extends StatelessWidget {
  const _PaneError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(l10n.jukeboxError, style: const TextStyle(color: Colors.white54, fontSize: 13)), const SizedBox(height: 8), TextButton(onPressed: onRetry, child: Text(l10n.retry))]));
  }
}
