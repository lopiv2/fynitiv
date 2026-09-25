import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fynitiv/core/widgets/marquee_text.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/horizontal_scroll_behavior.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../music/application/audio_eq_provider.dart';
import '../../music/application/soloud_music_provider.dart';
import '../../music/presentation/widgets/audio_eq_drawer.dart';
import '../../../l10n/app_localizations.dart';
import '../application/jukebox_providers.dart';
import '../application/jukebox_ui_state.dart';
import '../application/ost_providers.dart';
import '../application/romm_providers.dart';
import '../domain/game_ost_track.dart';
import '../domain/romm_music_facet.dart';
import 'widgets/game_video_background.dart';
import 'widgets/jukebox_now_playing_panel.dart';
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
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Restaura texto del buscador desde el estado persistido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(jukeboxUiProvider).search;
      if (s.isNotEmpty) _searchController.text = s;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(jukeboxUiProvider.notifier).setSearch(v.trim());
    });
  }

  void _pickTab(String tab) {
    final cur = ref.read(jukeboxUiProvider).tab;
    if (cur == tab) return;
    ref.read(jukeboxUiProvider.notifier).setTab(tab);
    // Prima Biblioteca: borra texto del buscador si lo había.
    if (_searchController.text.isNotEmpty) _searchController.clear();
  }

  Future<void> _playTracks(List<GameOstTrack> tracks, int index) async {
    if (tracks.isEmpty) return;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    await ref
        .read(soloudMusicProvider.notifier)
        .playOstQueue(
          tracks: tracks,
          startIndex: index,
          serverUrl: repo.serverUrl,
          authToken: repo.token,
        );
  }

  Future<void> _shuffleAll() async {
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    final search = ref.read(jukeboxUiProvider).search;
    final tracks = await ref.read(
      jukeboxTracksProvider(JukeboxTracksQuery(search: search)).future,
    );
    if (tracks.isEmpty || !mounted) return;
    await ref
        .read(soloudMusicProvider.notifier)
        .playOstQueue(
          tracks: tracks,
          serverUrl: repo.serverUrl,
          authToken: repo.token,
          shuffle: true,
        );
  }

  Future<void> _playFreeRadio() async {
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    final search = ref.read(jukeboxUiProvider).search;
    final all = await ref.read(
      jukeboxTracksProvider(JukeboxTracksQuery(search: search)).future,
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
    await ref
        .read(soloudMusicProvider.notifier)
        .playOstQueue(
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
    var covers = const <int, String>{};
    try {
      final games = await repo.getMusicGames();
      covers = {
        for (final g in games)
          if (g.coverUrl?.isNotEmpty == true) g.romId: g.coverUrl!,
      };
    } catch (_) {}
    await ref
        .read(soloudMusicProvider.notifier)
        .playOstQueue(
          tracks: [
            for (final t in tracks)
              GameOstTrack(
                name: t.displayName,
                url: t.streamUrl,
                duration: t.displayDuration,
                artist: t.artist,
                album: t.album,
                romFileId: t.romFileId,
                isFavorite: t.isFavorite,
                gameName: t.gameName,
                gameId: t.romId,
                coverUrl: covers[t.romId],
              ),
          ],
          serverUrl: repo.serverUrl,
          authToken: repo.token,
        );
  }

  Future<void> _playFavorites() async {
    _pickTab('favorites');
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    final fav = await ref.read(
      jukeboxTracksProvider(
        const JukeboxTracksQuery(favoritesOnly: true),
      ).future,
    );
    if (fav.isEmpty || !mounted) return;
    await ref
        .read(soloudMusicProvider.notifier)
        .playOstQueue(
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.jukeboxDecadeMix,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final d in sorted)
            ListTile(
              title: Text(
                l10n.jukeboxDecadeRange(d.toString(), (d + 9).toString()),
                style: const TextStyle(color: Colors.white),
              ),
              trailing: Text(
                '${decades[d]}',
                style: const TextStyle(color: Colors.white38),
              ),
              onTap: () => Navigator.of(context).pop(d),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    final tracks = await ref.read(
      jukeboxTracksProvider(
        JukeboxTracksQuery(minYear: picked, maxYear: picked + 9),
      ).future,
    );
    if (tracks.isEmpty || !mounted) return;
    await ref
        .read(soloudMusicProvider.notifier)
        .playOstQueue(
          tracks: tracks,
          serverUrl: repo.serverUrl,
          authToken: repo.token,
        );
  }

  void _handlePickTab(String tab) {
    _pickTab(tab);
    // Ya borra texto en _pickTab, pero asegura estado limpio
  }

  void _handleSelectGame(MusicGameEntry g) {
    ref.read(jukeboxUiProvider.notifier).selectGame(g.romId, g.name);
    if (_searchController.text.isNotEmpty) _searchController.clear();
    unawaited(_autoPlayGame(g));
  }

  void _handleSelectFacet(String v) {
    final tab = ref.read(jukeboxUiProvider).tab;
    ref.read(jukeboxUiProvider.notifier).selectFacet(v);
    if (_searchController.text.isNotEmpty) _searchController.clear();
    unawaited(_autoPlayFacet(tab, v));
  }

  Future<void> _autoPlayGame(MusicGameEntry g) async {
    final shuffle = ref.read(jukeboxUiProvider).shuffleEnabled;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    try {
      final tracks = await ref.read(ostTracksProvider(g.romId).future);
      if (tracks.isEmpty || !mounted) return;
      await ref
          .read(soloudMusicProvider.notifier)
          .playOstQueue(
            tracks: tracks,
            serverUrl: repo.serverUrl,
            authToken: repo.token,
            shuffle: shuffle,
          );
    } catch (_) {}
  }

  Future<void> _autoPlayFacet(String tab, String v) async {
    final shuffle = ref.read(jukeboxUiProvider).shuffleEnabled;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    JukeboxTracksQuery? q;
    if (tab == 'platforms') {
      try {
        final facet = await ref.read(jukeboxFacetProvider('platforms').future);
        final entry = facet.where((e) => e.value == v).firstOrNull;
        if (entry?.platformId != null) {
          q = JukeboxTracksQuery(platformIds: [entry!.platformId!]);
        }
      } catch (_) {}
    } else {
      q = switch (tab) {
        'artists' => JukeboxTracksQuery(artist: v),
        'albums' => JukeboxTracksQuery(album: v),
        'genres' => JukeboxTracksQuery(genre: v),
        'years' => JukeboxTracksQuery(year: int.tryParse(v)),
        _ => null,
      };
    }
    if (q == null) return;
    try {
      final tracks = await ref.read(jukeboxTracksProvider(q).future);
      if (tracks.isEmpty || !mounted) return;
      await ref
          .read(soloudMusicProvider.notifier)
          .playOstQueue(
            tracks: tracks,
            serverUrl: repo.serverUrl,
            authToken: repo.token,
            shuffle: shuffle,
          );
    } catch (_) {}
  }

  JukeboxTracksQuery? get _tracksQuery {
    final ui = ref.read(jukeboxUiProvider);
    final tab = ui.tab;
    final search = ui.search;
    final facet = ui.facetValue;
    if (tab == 'favorites') {
      return JukeboxTracksQuery(search: search, favoritesOnly: true);
    }
    if (tab == 'platforms') {
      final v = facet;
      if (v == null || v.isEmpty) return null;
      final facetData = ref.read(jukeboxFacetProvider('platforms')).value;
      final entry = facetData?.where((e) => e.value == v).firstOrNull;
      final id = entry?.platformId;
      if (id == null) return null;
      return JukeboxTracksQuery(search: search, platformIds: [id]);
    }
    final v = facet;
    if (v == null || v.isEmpty) return null;
    return switch (tab) {
      'artists' => JukeboxTracksQuery(search: search, artist: v),
      'albums' => JukeboxTracksQuery(search: search, album: v),
      'genres' => JukeboxTracksQuery(search: search, genre: v),
      'years' => JukeboxTracksQuery(search: search, year: int.tryParse(v)),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(jukeboxUiProvider);
    final skin = ref.watch(skinControllerProvider).value;
    final topPadding = libraryPageTopPadding(context, skin);
    // Sincroniza el campo de búsqueda si el provider borró el texto (prima Biblioteca).
    ref.listen(jukeboxUiProvider, (prev, next) {
      if (prev?.search != next.search &&
          next.search.isEmpty &&
          _searchController.text.isNotEmpty) {
        _searchController.clear();
      } else if (next.search.isNotEmpty &&
          _searchController.text != next.search) {
        _searchController.text = next.search;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
      }
    });

    final eqOpen = ref.watch(eqDrawerOpenProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              GameVideoBackground(
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _JukeboxTopHeader(
                          searchController: _searchController,
                          onSearchChanged: _onSearchChanged,
                          onBack: () => context.pop(),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Izquierda: Listas + Biblioteca + Resultados
                              Expanded(
                                child: wide
                                    ? SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            _Section(
                                              icon: Icons.gamepad_rounded,
                                              title: AppLocalizations.of(
                                                context,
                                              )!.jukeboxMixes,
                                              child: _MixesRow(
                                                onFreeRadio: () =>
                                                    unawaited(_playFreeRadio()),
                                                onDecades: () =>
                                                    unawaited(_openDecades()),
                                                onRecent: () => unawaited(
                                                  _playRecentlyAdded(),
                                                ),
                                                onFavorites: () =>
                                                    unawaited(_playFavorites()),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            _Section(
                                              icon: Icons.library_music_rounded,
                                              title: AppLocalizations.of(
                                                context,
                                              )!.jukeboxLibrary,
                                              child: _LibraryRow(
                                                onPlayAll: () =>
                                                    unawaited(_shuffleAll()),
                                                onPick: _handlePickTab,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            _ResultadosSection(
                                              search: ui.search,
                                              tab: ui.tab,
                                              facetValue: ui.facetValue,
                                              onPickGame: _handleSelectGame,
                                              onPickFacet: _handleSelectFacet,
                                            ),
                                          ],
                                        ),
                                      )
                                    : _narrowPaneContent(),
                              ),
                              if (wide)
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.02,
                                ),
                              if (wide)
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.3,
                                  child: _RightLateralPanel(
                                    tab: ui.tab,
                                    selGameId: ui.selGameId,
                                    selGameName: ui.selGameName,
                                    facetValue: ui.facetValue,
                                    search: ui.search,
                                    onPlay: _playTracks,
                                    onClearGame: () => ref
                                        .read(jukeboxUiProvider.notifier)
                                        .clearGame(),
                                    onClearFacet: () => ref
                                        .read(jukeboxUiProvider.notifier)
                                        .clearFacet(),
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
              if (eqOpen)
                Positioned.fill(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            ref.read(eqDrawerOpenProvider.notifier).close(),
                        child: Container(color: Colors.black54),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 360,
                          child: AudioEqDrawer(
                            onClose: () =>
                                ref.read(eqDrawerOpenProvider.notifier).close(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _narrowPaneContent() {
    final ui = ref.read(jukeboxUiProvider);
    final inTracks =
        (ui.tab == 'games' && ui.selGameId != null) ||
        (ui.tab == 'favorites') ||
        (_tracksQuery != null);
    if (inTracks) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const JukeboxNowPlayingPanel(),
          const SizedBox(height: 12),
          Expanded(
            child: _InlineTrackPane(
              tab: ui.tab,
              selGameId: ui.selGameId,
              facetValue: ui.facetValue,
              search: ui.search,
              selGameName: ui.selGameName,
              onPickGame: (g) => _handleSelectGame(g),
              onPickFacet: (v) => _handleSelectFacet(v),
              onPlay: _playTracks,
              onClearGame: () =>
                  ref.read(jukeboxUiProvider.notifier).clearGame(),
              onClearFacet: () =>
                  ref.read(jukeboxUiProvider.notifier).clearFacet(),
            ),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            icon: Icons.gamepad_rounded,
            title: AppLocalizations.of(context)!.jukeboxMixes,
            child: _MixesRow(
              onFreeRadio: () => unawaited(_playFreeRadio()),
              onDecades: () => unawaited(_openDecades()),
              onRecent: () => unawaited(_playRecentlyAdded()),
              onFavorites: () => unawaited(_playFavorites()),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            icon: Icons.library_music_rounded,
            title: AppLocalizations.of(context)!.jukeboxLibrary,
            child: _LibraryRow(
              onPlayAll: () => unawaited(_shuffleAll()),
              onPick: _handlePickTab,
            ),
          ),
          const SizedBox(height: 12),
          _ResultadosSection(
            search: ref.read(jukeboxUiProvider).search,
            tab: ref.read(jukeboxUiProvider).tab,
            facetValue: ref.read(jukeboxUiProvider).facetValue,
            onPickGame: _handleSelectGame,
            onPickFacet: _handleSelectFacet,
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _rightPane(AppLocalizations l10n, bool wide) {
    final ui = ref.read(jukeboxUiProvider);
    final gameId = ui.selGameId;
    final query = _tracksQuery;

    Widget trackPane;
    if (ui.tab == 'games' && gameId == null) {
      trackPane = _PickHint(wide: wide);
    } else if (ui.tab != 'games' && ui.tab != 'favorites' && query == null) {
      trackPane = _PickHint(wide: wide);
    } else {
      final title = ui.tab == 'games'
          ? (ui.selGameName ?? '')
          : ui.tab == 'favorites'
          ? l10n.jukeboxFavorites
          : (ui.facetValue ?? '');
      if (gameId != null) {
        final ostAsync = ref.watch(ostTracksProvider(gameId));
        trackPane = _TrackListView(
          title: title,
          tracksAsync: ostAsync,
          subtitleFallback: ui.selGameName ?? '',
          showBack: !wide,
          onBack: () => ref.read(jukeboxUiProvider.notifier).clearGame(),
          onPlay: _playTracks,
          onRetry: () => ref.invalidate(ostTracksProvider(gameId)),
        );
      } else {
        final q = query!;
        final tracksAsync = ref.watch(jukeboxTracksProvider(q));
        trackPane = _TrackListView(
          title: title,
          tracksAsync: tracksAsync,
          subtitleFallback: '',
          showBack: !wide && ui.tab != 'favorites',
          onBack: () => ref.read(jukeboxUiProvider.notifier).clearFacet(),
          onPlay: _playTracks,
          onRetry: () => ref.invalidate(jukeboxTracksProvider(q)),
        );
      }
    }

    // En la captura el lateral derecho muestra el player arriba + lista abajo.
    // En wide: panel lateral fijo a la derecha; en narrow: se delega a _narrowPane.
    if (!wide) return trackPane;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JukeboxNowPlayingPanel(),
        const SizedBox(height: 12),
        Expanded(child: trackPane),
      ],
    );
  }

  // ignore: unused_element
  Widget _narrowPane(AppLocalizations l10n) {
    final ui = ref.read(jukeboxUiProvider);
    final inTracks =
        (ui.tab == 'games' && ui.selGameId != null) ||
        (ui.tab == 'favorites') ||
        (_tracksQuery != null);
    if (inTracks) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const JukeboxNowPlayingPanel(),
          const SizedBox(height: 12),
          Expanded(child: _rightPane(l10n, false)),
        ],
      );
    }
    return _LeftPane(
      tab: ui.tab,
      search: ui.search,
      selGameId: ui.selGameId,
      facetValue: ui.facetValue,
      onPickGame: (g) =>
          ref.read(jukeboxUiProvider.notifier).selectGame(g.romId, g.name),
      onPickFacet: (v) => ref.read(jukeboxUiProvider.notifier).selectFacet(v),
      onRetry: () {},
    );
  }
}

/// Dos filas de atajos bajo los chips, estilo captura de referencia.
class _MixesRow extends ConsumerWidget {
  const _MixesRow({
    required this.onFreeRadio,
    required this.onDecades,
    required this.onRecent,
    required this.onFavorites,
  });
  final VoidCallback onFreeRadio;
  final VoidCallback onDecades;
  final VoidCallback onRecent;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final favCount =
        ref.watch(jukeboxFacetProvider('favorites')).value?.length ??
        ref
            .watch(
              jukeboxTracksProvider(
                const JukeboxTracksQuery(favoritesOnly: true),
              ),
            )
            .value
            ?.length ??
        0;
    // Recientes: limitar a 25 como en la captura
    const recentCount = 25;
    final decadesCount =
        ref.watch(jukeboxFacetProvider('years')).value?.fold<Set<int>>(
          <int>{},
          (s, v) {
            final y = int.tryParse(v.value);
            if (y != null) s.add((y ~/ 10) * 10);
            return s;
          },
        ).length ??
        1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ScrollConfiguration(
          behavior: const HorizontalScrollBehavior(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.hardEdge,
            child: Row(
              children: [
                _JukeboxShortcutCard(
                  icon: Icons.radar_rounded,
                  title: l10n.jukeboxFreeRadio,
                  subtitle: l10n.jukeboxFreeRadioHint,
                  onTap: onFreeRadio,
                  featured: true,
                ),
                _JukeboxShortcutCard(
                  icon: Icons.calendar_month_rounded,
                  title: l10n.jukeboxDecadeMix,
                  subtitle: decadesCount == 1
                      ? l10n.jukeboxDecadeHint
                      : l10n.jukeboxDecadesHint(decadesCount),
                  onTap: onDecades,
                  featured: true,
                ),
                _JukeboxShortcutCard(
                  icon: Icons.schedule_rounded,
                  title: l10n.jukeboxRecentlyAdded,
                  subtitle: l10n.jukeboxRecentlyAddedSub(recentCount),
                  onTap: onRecent,
                  featured: true,
                ),
                _JukeboxShortcutCard(
                  icon: Icons.favorite_rounded,
                  title: l10n.jukeboxFavoriteTracks,
                  subtitle: l10n.jukeboxFavoriteSub(favCount),
                  onTap: onFavorites,
                  featured: true,
                ),
              ],
            ),
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
    final platforms =
        ref.watch(jukeboxFacetProvider('platforms')).value?.length ?? 0;
    final artists =
        ref.watch(jukeboxFacetProvider('artists')).value?.length ?? 0;
    final genres = ref.watch(jukeboxFacetProvider('genres')).value?.length ?? 0;
    final years = ref.watch(jukeboxFacetProvider('years')).value?.length ?? 0;
    final games =
        ref.watch(jukeboxRecentGamesProvider).value?.length ??
        ref.watch(jukeboxGamesProvider('')).value?.length ??
        0;
    final recentCount =
        ref.watch(jukeboxRecentGamesProvider).value?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        FocusTraversalGroup(
          child: ScrollConfiguration(
            behavior: const HorizontalScrollBehavior(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.hardEdge,
              child: Row(
                children: [
                  _JukeboxShortcutCard(
                    icon: Icons.queue_music_rounded,
                    title: l10n.jukeboxPlayAll,
                    subtitle: l10n.jukeboxPlayAllSub(stats?.totalTracks ?? 0),
                    onTap: onPlayAll,
                  ),
                  _JukeboxShortcutCard(
                    icon: Icons.videogame_asset_rounded,
                    title: l10n.jukeboxGames,
                    subtitle: '$games',
                    onTap: () => onPick('games'),
                  ),
                  _JukeboxShortcutCard(
                    icon: Icons.album_rounded,
                    title: l10n.jukeboxOstByAlbum,
                    subtitle: l10n.jukeboxFacetCountAlbums(albums),
                    onTap: () => onPick('albums'),
                  ),
                  _JukeboxShortcutCard(
                    icon: Icons.sports_esports_rounded,
                    title: l10n.jukeboxOstByPlatform,
                    subtitle: platforms == 1
                        ? l10n.jukeboxFacetCountPlatforms(platforms)
                        : l10n.jukeboxFacetCountPlatformsPlural(platforms),
                    onTap: () => onPick('platforms'),
                  ),
                  _JukeboxShortcutCard(
                    icon: Icons.person_rounded,
                    title: l10n.jukeboxOstByArtist,
                    subtitle: l10n.jukeboxFacetCountArtists(artists),
                    onTap: () => onPick('artists'),
                  ),
                  _JukeboxShortcutCard(
                    icon: Icons.category_rounded,
                    title: l10n.jukeboxOstByGenre,
                    subtitle: l10n.jukeboxFacetCountGenres(genres),
                    onTap: () => onPick('genres'),
                  ),
                  _JukeboxShortcutCard(
                    icon: Icons.calendar_today_rounded,
                    title: l10n.jukeboxYears,
                    subtitle: '$years',
                    onTap: () => onPick('years'),
                  ),
                  _JukeboxShortcutCard(
                    icon: Icons.access_time_rounded,
                    title: l10n.jukeboxRecentlyAdded,
                    subtitle: recentCount == 0 ? '$games' : '$recentCount',
                    onTap: () => onPick('games'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _JukeboxShortcutCard extends ConsumerWidget {
  const _JukeboxShortcutCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.featured = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(jukeboxCardScaleProvider);
    final width = (featured ? 170.0 : 148.0) * s;
    final height = (featured ? 132.0 : 118.0) * s;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: AppHover(
        effect: AppHoverEffect.highlightWithScale,
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          padding: EdgeInsets.fromLTRB(12, featured ? 14 : 12, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
            gradient: featured
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.28),
                    ],
                  )
                : null,
          ),
          child: featured
              ? Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Icon(icon, color: Colors.white, size: 28 * s),
                    ),
                    Positioned(
                      left: 0,
                      right: 28 * s,
                      bottom: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11 * s,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2 * s),
                          Text(
                            subtitle,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10 * s,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22 * s,
                        height: 22 * s,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 14 * s,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Container(
                      width: 36 * s,
                      height: 36 * s,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10 * s),
                      ),
                      child: Icon(icon, color: Colors.white70, size: 18 * s),
                    ),
                    SizedBox(height: 10 * s),
                    Text(
                      title,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11 * s,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4 * s),
                    Text(
                      subtitle,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 10 * s),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _Header extends ConsumerWidget {
  const _Header({
    required this.accent,
    required this.onBack,
    required this.onShuffle,
  });
  final Color accent;
  final VoidCallback onBack;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stats = ref.watch(jukeboxStatsProvider);
    return Row(
      children: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.jukeboxTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              stats.when(
                data: (s) => Text(
                  l10n.jukeboxStats(s.totalTracks, s.displayTotal),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                loading: () => const SizedBox(height: 14),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.jukeboxShuffleAll,
          onPressed: onShuffle,
          icon: Icon(Icons.shuffle_rounded, color: accent, size: 24),
        ),
      ],
    );
  }
}

// ignore: unused_element
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
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Colors.white38,
          size: 20,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
    );
  }
}

// Chips eliminados: navegación ahora vía Biblioteca (_LibraryRow).
// Se mantiene placeholder por si se reintroduce filtrado rápido.

// ignore: unused_element
class _LeftPane extends ConsumerWidget {
  const _LeftPane({
    required this.tab,
    required this.search,
    required this.selGameId,
    required this.facetValue,
    required this.onPickGame,
    required this.onPickFacet,
    required this.onRetry,
  });
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
        error: (_, _) => _PaneError(
          onRetry: () {
            ref.invalidate(jukeboxGamesProvider(search));
            onRetry();
          },
        ),
        data: (list) {
          if (list.isEmpty) return const _PaneEmpty();
          return GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) => _GameCard(
              game: list[i],
              selected: list[i].romId == selGameId,
              onTap: () => onPickGame(list[i]),
            ),
          );
        },
      );
    }
    if (tab == 'favorites') return const SizedBox.shrink();
    final facet = ref.watch(jukeboxFacetProvider(tab));
    return facet.when(
      loading: () => const Center(child: AppLoader()),
      error: (_, _) => _PaneError(
        onRetry: () {
          ref.invalidate(jukeboxFacetProvider(tab));
          onRetry();
        },
      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          v.value.isEmpty ? '—' : v.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${v.count}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
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

class _GameCard extends ConsumerWidget {
  const _GameCard({
    required this.game,
    required this.selected,
    required this.onTap,
  });
  final MusicGameEntry game;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(jukeboxCardScaleProvider);
    return AppHover(
      effect: AppHoverEffect.highlightWithScale,
      config: AppHoverConfig(
        scale: 1.04,
        borderRadius: BorderRadius.circular(12 * s),
      ),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12 * s),
          border: Border.all(color: selected ? Colors.white54 : Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12 * s),
                ),
                child: game.coverUrl != null && game.coverUrl!.isNotEmpty
                    ? Image.network(
                        game.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _CoverFallback(),
                      )
                    : const _CoverFallback(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8 * s, 6 * s, 8 * s, 2 * s),
              child: Text(
                game.name.isEmpty ? '—' : game.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12 * s,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8 * s, 0, 8 * s, 8 * s),
              child: Text(
                '${game.count}',
                style: TextStyle(color: Colors.white38, fontSize: 11 * s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white.withValues(alpha: 0.05),
    child: const Center(
      child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 36),
    ),
  );
}

class _TrackListView extends ConsumerWidget {
  const _TrackListView({
    required this.title,
    required this.tracksAsync,
    required this.subtitleFallback,
    required this.showBack,
    required this.onBack,
    required this.onPlay,
    required this.onRetry,
  });
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
    final playingUrl = ref.watch(
      soloudMusicProvider.select((s) => s.session?.streamUrl),
    );
    return tracksAsync.when(
      loading: () => const Center(child: AppLoader()),
      error: (_, _) => _PaneError(onRetry: onRetry),
      data: (tracks) {
        if (tracks.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrackListTitle(title: title, showBack: showBack, onBack: onBack),
              Expanded(
                child: Center(
                  child: Text(
                    l10n.jukeboxNoResults,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TrackListTitle(title: title, showBack: showBack, onBack: onBack),
            Text(
              l10n.ostTracksCount(tracks.length),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 26,
                            child: isCurrent
                                ? const Icon(
                                    Icons.graphic_eq_rounded,
                                    color: Color(0xFF8B7CF6),
                                    size: 18,
                                  )
                                : Text(
                                    '${i + 1}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent
                                        ? const Color(0xFF8B7CF6)
                                        : Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  t.subtitle(subtitleFallback),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (t.duration != null && t.duration!.isNotEmpty)
                            Text(
                              t.duration!,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
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
  const _TrackListTitle({
    required this.title,
    required this.showBack,
    required this.onBack,
  });
  final String title;
  final bool showBack;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (showBack)
        IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white70,
            size: 20,
          ),
        ),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _PickHint extends StatelessWidget {
  const _PickHint({required this.wide});
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.library_music_rounded,
            color: Colors.white24,
            size: 48,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.jukeboxPickHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PaneEmpty extends StatelessWidget {
  const _PaneEmpty();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(
        l10n.jukeboxNoResults,
        style: const TextStyle(color: Colors.white38, fontSize: 13),
      ),
    );
  }
}

class _PaneError extends StatelessWidget {
  const _PaneError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.jukeboxError,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

class _JukeboxTopHeader extends ConsumerWidget {
  const _JukeboxTopHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.onBack,
  });
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(jukeboxStatsProvider);
    return Row(
      children: [
        IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF5B6BFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.music_note_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jukebox',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
            stats.when(
              data: (s) => Text(
                '${s.totalTracks} canciones · ${s.displayTotal}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              loading: () => const SizedBox(height: 12),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        SizedBox(width: MediaQuery.of(context).size.width * 0.3),
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Busca juegos, artistas, canciones...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Colors.white38,
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: const Icon(
            Icons.tune_rounded,
            color: Colors.white70,
            size: 20,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
    required this.child,
  });
  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF8B7CF6), size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: kSectionTitleFontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (actionLabel != null &&
                  actionLabel!.isNotEmpty &&
                  onAction != null) ...[
                const Spacer(),
                GestureDetector(
                  onTap: onAction,
                  child: Row(
                    children: [
                      Text(
                        actionLabel!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white54,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: child),
        ],
      ),
    );
  }
}

class _ResultadosSection extends ConsumerWidget {
  const _ResultadosSection({
    required this.search,
    required this.tab,
    required this.facetValue,
    required this.onPickGame,
    required this.onPickFacet,
  });
  final String search;
  final String tab;
  final String? facetValue;
  final ValueChanged<MusicGameEntry> onPickGame;
  final ValueChanged<String> onPickFacet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(jukeboxCardScaleProvider);
    final l10n = AppLocalizations.of(context)!;

    // Favoritas solo lateral derecho, nunca en Resultados (aunque haya búsqueda)
    if (tab == 'favorites') return const SizedBox.shrink();

    // Prioridad Biblioteca: si hay búsqueda activa, muestra resultados de búsqueda
    // filtrados por search (grid juegos). Si no hay búsqueda, muestra el
    // facet sin filtrar correspondiente al tab seleccionado en Biblioteca.
    final isSearching = search.isNotEmpty;

    // Caso búsqueda: resultados filtrados (sin facetValue aún)
    if (isSearching) {
      final gamesAsync = ref.watch(jukeboxGamesProvider(search));
      return _Section(
        icon: Icons.search_rounded,
        title: l10n.jukeboxSearchHint,
        actionLabel: '',
        onAction: () {},
        child: gamesAsync.when(
          loading: () => SizedBox(
            height: 110 * s,
            child: Center(child: AppLoader()),
          ),
          error: (_, _) => Text(
            l10n.jukeboxError,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 16 * s),
                child: Text(
                  l10n.jukeboxNoResults,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              );
            }
            final items = list.take(12).toList();
            return SizedBox(
              height: 210 * s,
              child: ScrollConfiguration(
                behavior: const HorizontalScrollBehavior(),
                child: FocusTraversalGroup(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.hardEdge,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => SizedBox(width: 10 * s),
                    itemBuilder: (context, i) {
                      final g = items[i];
                      return _GameTileWithMarquee(
                        key: ValueKey(g.name),
                        game: g,
                        s: s,
                        onTap: () => onPickGame(g),
                        fontWeight: FontWeight.w800,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // Sin búsqueda: muestra facet sin filtrar según tab de Biblioteca
    // Tab games → grid de juegos sin filtrar; otros tabs → lista de facets
    if (tab == 'games') {
      final gamesAsync = ref.watch(jukeboxGamesProvider(''));
      return _Section(
        icon: Icons.videogame_asset_rounded,
        title: l10n.jukeboxGames,
        actionLabel: '',
        onAction: () {},
        child: gamesAsync.when(
          loading: () => SizedBox(
            height: 110 * s,
            child: Center(child: AppLoader()),
          ),
          error: (_, _) => Text(
            l10n.jukeboxError,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 16 * s),
                child: Text(
                  l10n.jukeboxNoResults,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              );
            }
            final items = list.take(12).toList();
            return SizedBox(
              height: 210 * s,
              child: ScrollConfiguration(
                behavior: const HorizontalScrollBehavior(),
                child: FocusTraversalGroup(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    clipBehavior: Clip.hardEdge,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => SizedBox(width: 10 * s),
                    itemBuilder: (context, i) {
                      final g = items[i];
                      return _GameTileWithMarquee(
                        key: ValueKey(g.name),
                        game: g,
                        s: s,
                        onTap: () => onPickGame(g),
                        fontWeight: FontWeight.w600,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // Facet sin filtrar (artists/albums/genres/years/platforms)
    final facetAsync = ref.watch(jukeboxFacetProvider(tab));
    final title = switch (tab) {
      'artists' => l10n.jukeboxArtists,
      'albums' => l10n.jukeboxAlbums,
      'genres' => l10n.jukeboxGenres,
      'years' => l10n.jukeboxYears,
      'platforms' => l10n.jukeboxPlatforms,
      _ => tab,
    };
    return _Section(
      icon: Icons.list_rounded,
      title: title,
      actionLabel: '',
      onAction: () {},
      child: facetAsync.when(
        loading: () => SizedBox(
          height: 110 * s,
          child: Center(child: AppLoader()),
        ),
        error: (_, _) => Text(
          l10n.jukeboxError,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16 * s),
              child: Text(
                l10n.jukeboxNoResults,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            );
          }
          return SizedBox(
            height: 140 * s,
            child: ScrollConfiguration(
              behavior: const HorizontalScrollBehavior(),
              child: FocusTraversalGroup(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.hardEdge,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => SizedBox(width: 10 * s),
                  itemBuilder: (context, i) {
                    final v = list[i];
                    final selected = v.value == facetValue;
                    return AppHover(
                      effect: AppHoverEffect.highlightWithScale,
                      config: AppHoverConfig(
                        scale: 1.04,
                        borderRadius: BorderRadius.circular(10 * s),
                      ),
                      onTap: () => onPickFacet(v.value),
                      child: Container(
                        width: 160 * s,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10 * s),
                          border: Border.all(
                            color: selected ? Colors.white38 : Colors.white12,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              v.value.isEmpty ? '—' : v.value,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${v.count}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GameTileWithMarquee extends StatefulWidget {
  const _GameTileWithMarquee({
    super.key,
    required this.game,
    required this.s,
    required this.onTap,
    this.fontWeight = FontWeight.w800,
  });
  final MusicGameEntry game;
  final double s;
  final VoidCallback onTap;
  final FontWeight fontWeight;
  @override
  State<_GameTileWithMarquee> createState() => _GameTileWithMarqueeState();
}

class _GameTileWithMarqueeState extends State<_GameTileWithMarquee> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AppHover(
        effect: AppHoverEffect.highlightWithScale,
        config: AppHoverConfig(scale: 1.04, borderRadius: BorderRadius.circular(10 * widget.s)),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10 * widget.s),
          child: Container(
            width: 160 * widget.s,
            decoration: BoxDecoration(border: Border.all(color: Colors.white12)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.game.coverUrl != null && widget.game.coverUrl!.isNotEmpty)
                  Image.network(widget.game.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.white10))
                else
                  Container(color: Colors.white10, child: const Icon(Icons.videogame_asset_rounded, color: Colors.white24)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    color: Colors.black54,
                    child: MarqueeText(
                      text: widget.game.name,
                      style: TextStyle(color: Colors.white, fontSize: 11 * widget.s, fontWeight: widget.fontWeight),
                      isHovered: _hovered,
                      enabled: true,
                      velocity: 28,
                      gap: 36,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RightLateralPanel extends ConsumerWidget {
  const _RightLateralPanel({
    required this.tab,
    required this.selGameId,
    required this.selGameName,
    required this.facetValue,
    required this.search,
    required this.onPlay,
    required this.onClearGame,
    required this.onClearFacet,
  });
  final String tab;
  final int? selGameId;
  final String? selGameName;
  final String? facetValue;
  final String search;
  final void Function(List<GameOstTrack>, int) onPlay;
  final VoidCallback onClearGame;
  final VoidCallback onClearFacet;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Determina pane de pistas igual que antes
    final gameId = selGameId;
    String? queryFacet = facetValue;
    JukeboxTracksQuery? q;
    if (tab == 'favorites') {
      q = JukeboxTracksQuery(search: search, favoritesOnly: true);
    } else if (tab == 'platforms' && queryFacet != null) {
      final facet = ref.watch(jukeboxFacetProvider('platforms')).value;
      final entry = facet?.where((e) => e.value == queryFacet).firstOrNull;
      if (entry?.platformId != null) {
        q = JukeboxTracksQuery(
          search: search,
          platformIds: [entry!.platformId!],
        );
      }
    } else if (queryFacet != null) {
      q = switch (tab) {
        'artists' => JukeboxTracksQuery(search: search, artist: queryFacet),
        'albums' => JukeboxTracksQuery(search: search, album: queryFacet),
        'genres' => JukeboxTracksQuery(search: search, genre: queryFacet),
        'years' => JukeboxTracksQuery(
          search: search,
          year: int.tryParse(queryFacet),
        ),
        _ => null,
      };
    }
    Widget trackPane;
    if (tab == 'games' && gameId == null) {
      trackPane = const _PickHint(wide: true);
    } else if (tab != 'games' && tab != 'favorites' && q == null) {
      trackPane = const _PickHint(wide: true);
    } else if (gameId != null) {
      final ostAsync = ref.watch(ostTracksProvider(gameId));
      trackPane = _TrackListView(
        title: selGameName ?? '',
        tracksAsync: ostAsync,
        subtitleFallback: selGameName ?? '',
        showBack: false,
        onBack: onClearGame,
        onPlay: onPlay,
        onRetry: () => ref.invalidate(ostTracksProvider(gameId)),
      );
    } else {
      final tracksAsync = ref.watch(jukeboxTracksProvider(q!));
      trackPane = _TrackListView(
        title: tab == 'favorites' ? l10n.jukeboxFavorites : (facetValue ?? ''),
        tracksAsync: tracksAsync,
        subtitleFallback: '',
        showBack: false,
        onBack: onClearFacet,
        onPlay: onPlay,
        onRetry: () => ref.invalidate(jukeboxTracksProvider(q!)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const JukeboxNowPlayingPanel(),
          const SizedBox(height: 12),
          Expanded(child: trackPane),
        ],
      ),
    );
  }
}

class _InlineTrackPane extends ConsumerWidget {
  const _InlineTrackPane({
    required this.tab,
    required this.selGameId,
    required this.facetValue,
    required this.search,
    required this.selGameName,
    required this.onPickGame,
    required this.onPickFacet,
    required this.onPlay,
    required this.onClearGame,
    required this.onClearFacet,
  });
  final String tab;
  final int? selGameId;
  final String? facetValue;
  final String search;
  final String? selGameName;
  final ValueChanged<MusicGameEntry> onPickGame;
  final ValueChanged<String> onPickFacet;
  final void Function(List<GameOstTrack>, int) onPlay;
  final VoidCallback onClearGame;
  final VoidCallback onClearFacet;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Solo muestra algo si hay selección
    final hasSel =
        (tab == 'games' && selGameId != null) ||
        (tab == 'favorites') ||
        (facetValue != null && facetValue!.isNotEmpty);
    if (!hasSel) return const SizedBox.shrink();
    JukeboxTracksQuery? q;
    if (tab == 'favorites') {
      q = JukeboxTracksQuery(search: search, favoritesOnly: true);
    } else if (tab == 'platforms' && facetValue != null) {
      final facet = ref.watch(jukeboxFacetProvider('platforms')).value;
      final entry = facet?.where((e) => e.value == facetValue).firstOrNull;
      if (entry?.platformId != null) {
        q = JukeboxTracksQuery(
          search: search,
          platformIds: [entry!.platformId!],
        );
      }
    } else if (facetValue != null) {
      q = switch (tab) {
        'artists' => JukeboxTracksQuery(search: search, artist: facetValue),
        'albums' => JukeboxTracksQuery(search: search, album: facetValue),
        'genres' => JukeboxTracksQuery(search: search, genre: facetValue),
        // ignore: unnecessary_non_null_assertion
        'years' => JukeboxTracksQuery(
          search: search,
          year: int.tryParse(facetValue!),
        ),
        _ => null,
      };
    }
    if (tab == 'games' && selGameId != null) {
      final ostAsync = ref.watch(ostTracksProvider(selGameId!));
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: SizedBox(
          height: 340,
          child: _TrackListView(
            title: selGameName ?? '',
            tracksAsync: ostAsync,
            subtitleFallback: selGameName ?? '',
            showBack: true,
            onBack: onClearGame,
            onPlay: onPlay,
            onRetry: () => ref.invalidate(ostTracksProvider(selGameId!)),
          ),
        ),
      );
    }
    if (q != null) {
      // ignore: unnecessary_non_null_assertion
      final tracksAsync = ref.watch(jukeboxTracksProvider(q!));
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        // ignore: unnecessary_non_null_assertion
        child: SizedBox(
          height: 340,
          child: _TrackListView(
            title: tab == 'favorites'
                ? l10n.jukeboxFavorites
                : (facetValue ?? ''),
            tracksAsync: tracksAsync,
            subtitleFallback: '',
            showBack: true,
            onBack: onClearFacet,
            onPlay: onPlay,
            onRetry: () => ref.invalidate(jukeboxTracksProvider(q!)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
