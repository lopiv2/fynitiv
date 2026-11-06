import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/audio/item_theme_player.dart';
import '../../../core/navigation/play_routing.dart';
import '../../../core/skin/detail_layout.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/video/mpv_teardown.dart';
import '../../../core/widgets/ad_free_easter_egg_dialog.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/detail_primitives.dart';
import '../../../core/widgets/hover_play_glyph.dart';
import '../../../core/widgets/included_badge.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/genre_localizer.dart';
import '../../player/application/playback_provider.dart';
import '../../seerr/application/seerr_controller.dart';
import '../../seerr/application/seerr_providers.dart';
import '../../seerr/data/seerr_api.dart';
import '../../seerr/domain/seerr_models.dart';
import '../../seerr/presentation/widgets/seerr_watch_providers.dart';
import '../../downloads/application/download_manager_provider.dart';
import '../application/image_url.dart';
import '../application/library_providers.dart';
import 'widgets/content_row.dart';

/// Pantalla de informacion con composicion inspirada en Prime Video.
class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({
    super.key,
    required this.item,
    this.backdropUrl,
    this.seerrMedia,
  });

  final BaseItemDto item;

  /// Backdrop alternativo (contenido externo, p. ej. TMDB/Seerr). Si se indica,
  /// se usa en lugar del backdrop de Jellyfin.
  final String? backdropUrl;

  /// Ficha de Seerr asociada (plataformas donde se emite, etc.). Si viene, la
  /// ficha muestra "Solicitar" + proveedores de Seerr.
  final SeerrMedia? seerrMedia;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen>
    with WidgetsBindingObserver {
  final GlobalKey _detailsKey = GlobalKey();
  final GlobalKey _relatedKey = GlobalKey();
  BaseItemDto? _resolvedItem;
  bool _detailsSelected = false;
  bool? _isFavorite;
  bool _trailerLoading = false;
  Player? _trailerPlayer;
  VideoController? _trailerVideoController;
  String? _trailerError;
  bool _themeStarted = false;

  BaseItemDto get item => _resolvedItem ?? widget.item;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isFavorite = widget.item.userData?.isFavorite;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Reclamo síncrono como en _closeTrailer: si el cierre iba en vuelo,
    // ya nuló y aquí no se re-libera (evita doble dispose nativo → mutex).
    final trailer = _trailerPlayer;
    _trailerPlayer = null;
    _trailerVideoController = null;
    if (trailer != null) {
      unawaited(disposeMpvPlayer(trailer));
    }
    // El theme del detalle no debe sonar fuera de la ficha.
    ItemThemePlayer.instance.leaveDetail();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ItemThemePlayer.instance.pauseForExternal();
    } else if (state == AppLifecycleState.resumed) {
      ItemThemePlayer.instance.resumeIfNeeded();
    }
  }

  /// Autoplay del theme en el detalle (solo Jellyfin: theme.mp3).
  /// Silencioso si no hay theme; toma propiedad frente al hover.
  void _maybeStartTheme(ItemTheme? theme) {
    if (_themeStarted) return;
    final url = theme?.streamUrl;
    if (url == null || url.isEmpty) {
      return;
    }
    if (ItemThemePlayer.instance.isPlayingUrl(url)) {
      _themeStarted = true;
      return;
    }
    _themeStarted = true;
    ItemThemePlayer.instance.play(url, inDetail: true);
  }

  Future<void> _openTrailer() async {
    if (_trailerLoading || _trailerPlayer != null) return;
    // El trailer (vídeo) tiene prioridad sobre el theme de fondo.
    ItemThemePlayer.instance.pauseForExternal();
    final itemId = item.id;
    if (itemId == null || itemId.isEmpty) return;
    setState(() {
      _trailerLoading = true;
      _trailerError = null;
    });
    String? streamUrl;
    try {
      streamUrl = await ref.read(trailerStreamProvider(item).future);
    } catch (error) {
      debugPrint('Failed to fetch KinoCheck trailer: $error');
    }
    if (!mounted) return;
    if (streamUrl == null) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _trailerLoading = false;
        _trailerError = l10n.trailerNoTrailer;
      });
      return;
    }
    final player = Player();
    final videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto-copy'),
    );
    try {
      await player.open(
        Media(
          streamUrl,
          httpHeaders: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                'AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
          },
        ),
      );
    } catch (_) {
      await player.dispose();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _trailerLoading = false;
          _trailerError = l10n.trailerOpenFailed;
        });
      }
      return;
    }
    if (!mounted) {
      await player.dispose();
      return;
    }
    setState(() {
      _trailerLoading = false;
      _trailerPlayer = player;
      _trailerVideoController = videoController;
    });
    await player.play();
  }

  Future<void> _closeTrailer() async {
    // Reclamo síncrono: si el dispose() del widget iba en vuelo, ya nuló
    // y aquí no se re-libera (evita doble dispose nativo → mutex).
    final player = _trailerPlayer;
    _trailerPlayer = null;
    _trailerVideoController = null;
    _trailerLoading = false;
    _trailerError = null;
    if (mounted) setState(() {});
    if (player != null) {
      // Drenaje con gracia (ver `disposeMpvPlayer`): en Windows liberar
      // mpv pintando aborta el proceso (`unlock of unowned mutex`).
      await disposeMpvPlayer(player);
    }
    ItemThemePlayer.instance.resumeIfNeeded();
  }

  Future<void> _toggleFavorite() async {
    final itemId = item.id;
    final userId = ref.read(currentUserIdProvider);
    final client = ref.read(jellyfinClientProvider);
    if (itemId == null || itemId.isEmpty || userId == null || client == null) {
      return;
    }
    final nextValue = !(_isFavorite ?? false);
    setState(() => _isFavorite = nextValue);
    try {
      if (nextValue) {
        await client.getUserLibraryApi().markFavoriteItem(
          itemId: itemId,
          userId: userId,
        );
      } else {
        await client.getUserLibraryApi().unmarkFavoriteItem(
          itemId: itemId,
          userId: userId,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isFavorite = !nextValue);
    }
  }

  Future<void> _downloadItem() async {
    final itemId = item.id;
    if (itemId == null || itemId.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final session = await ref.read(playbackSessionProvider(itemId).future);
      if (session == null) throw StateError('No playback session');
      // El progreso/pausa/cancel vive en el gestor global (barra inferior).
      await ref
          .read(downloadManagerProvider.notifier)
          .enqueue(
            url: session.streamUrl,
            fileName: detailDownloadFilename(item.name ?? 'video'),
            sourceLabel: item.name ?? 'video',
            doneMessage: l10n.gamesDownloaded,
            failMessage: l10n.downloadFailed,
          );
    } catch (_) {
      if (mounted) {
        unawaited(EasyLoading.showError(l10n.gamesNoFile));
      }
    }
  }

  void _showDetails() {
    setState(() => _detailsSelected = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToDetails();
    });
  }

  void _scrollToDetails() {
    final target = _detailsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _showRelated() {
    setState(() => _detailsSelected = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _relatedKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  List<String> _streamLabels(BaseItemDto source, MediaStreamType type) {
    return (source.mediaStreams ?? const <MediaStream>[])
        .where((stream) => stream.type == type)
        .map((stream) => stream.displayTitle ?? stream.language ?? '')
        .where((label) => label.isNotEmpty)
        .toSet()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    _resolvedItem =
        ref.watch(itemDetailProvider(widget.item.id ?? '')).value ??
        widget.item;
    // Autoplay del theme (solo Jellyfin: theme.mp3), silencioso sin theme.
    ref.listen<AsyncValue<ItemTheme?>>(
      itemThemeProvider(item),
      (_, next) => next.whenData(_maybeStartTheme),
    );
    // El listen no re-dispara si el provider ya resolvió (caché keepAlive):
    // arranca también con el valor actual si ya trae theme.
    ref.read(itemThemeProvider(item)).whenData(_maybeStartTheme);
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final skin = ref.watch(skinControllerProvider).value;
    // Si el item abierto es un episodio/temporada, se resuelve su serie para
    // mostrar el detalle de serie (temporadas + capítulos), igual que al abrir
    // la serie desde la biblioteca. Así TODAS las vistas de detalle de serie en
    // Prime muestran las temporadas (y su desplegable).
    final seriesIdForBody = item.type == BaseItemKind.series
        ? item.id
        : item.seriesId;
    final seriesItem = (seriesIdForBody == null || seriesIdForBody.isEmpty)
        ? null
        : (seriesIdForBody == item.id
              ? item
              : (ref.watch(itemDetailProvider(seriesIdForBody)).value ??
                    BaseItemDto(
                      id: seriesIdForBody,
                      name: item.seriesName,
                      type: BaseItemKind.series,
                    )));
    // Detalle de serie con episodios (temporadas + tabs): Disney y Prime.
    final isSeriesDetail =
        seriesItem != null &&
        (skin?.id == 'disney_plus' || skin?.id == 'amazon_prime');
    // El cuerpo (y sus datos) usan la serie cuando corresponde.
    final bodyItem = isSeriesDetail ? seriesItem : item;

    final imageUrl =
        widget.backdropUrl ??
        (serverUrl == null
            ? null
            : itemBackdropUrl(serverUrl, bodyItem, maxWidth: 1800));
    final logoUrl = serverUrl == null
        ? null
        : itemLogoUrl(serverUrl, bodyItem, maxWidth: 700);
    final overview = (bodyItem.overview ?? '').trim();
    final genres = bodyItem.genres?.take(2).toList() ?? const <String>[];
    final imdbRating = bodyItem.communityRating;
    final people = bodyItem.people ?? const <BaseItemPerson>[];
    final studios =
        bodyItem.studios
            ?.map((studio) => studio.name ?? '')
            .where((name) => name.isNotEmpty)
            .toList() ??
        const <String>[];
    final audioLanguages = _streamLabels(bodyItem, MediaStreamType.audio);
    final subtitleLanguages = _streamLabels(bodyItem, MediaStreamType.subtitle);
    final related = ref.watch(similarItemsProvider(bodyItem));
    final isFavorite = _isFavorite ?? item.userData?.isFavorite ?? false;
    final wideScreen = MediaQuery.sizeOf(context).width >= 760;
    // Alto a reservar arriba dentro del SafeArea para no quedar bajo la barra
    // superior del skin (p. ej. Prime anclada). Para barras laterales vale el
    // mismo hueco que antes (8).
    final topInset =
        libraryPageTopPadding(context, skin) -
        MediaQuery.of(context).padding.top;

    final variant = detailVariantFor(skin: skin, kind: item.type);
    final isSeriesItem = item.type == BaseItemKind.series;

    return Scaffold(
      backgroundColor: const Color(0xFF02070D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF502070D),
                  Color(0xD902070D),
                  Color(0x3302070D),
                ],
                stops: [0, 0.34, 0.82],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xFF02070D), Color(0x0002070D)],
              ),
            ),
          ),
          if (wideScreen &&
              (_trailerLoading ||
                  _trailerVideoController != null ||
                  _trailerError != null))
            Positioned(
              top: 86,
              right: 100,
              width: MediaQuery.sizeOf(context).width * 0.55,
              child: _TrailerPanel(
                loading: _trailerLoading,
                controller: _trailerVideoController,
                onClose: _closeTrailer,
                error: _trailerError,
                showClose: false,
              ),
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(28, topInset, 24, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: l10n.back,
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => context.pop(),
                                ),
                                const SizedBox(width: 6),
                                const _PrimeLogo(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isSeriesItem &&
                          variant == DetailLayoutVariant.netflix)
                        _NetflixDetailBody(
                          item: seriesItem ?? item,
                          series: seriesItem ?? item,
                          serverUrl: serverUrl,
                          logoUrl: logoUrl,
                          overview: overview,
                          genres: genres,
                          people: people,
                          studios: studios,
                          isFavorite: isFavorite,
                          accent: skin?.accent ?? const Color(0xFFE50914),
                          relatedItems:
                              related.value ?? const <BaseItemDto>[],
                          onPlay: () => pushPlayForDetail(
                            context,
                            seriesItem ?? item,
                          ),
                          onPlayEpisode: (episode) =>
                              pushPlayForDetail(context, episode),
                          onTrailer: _openTrailer,
                          onFavorite: _toggleFavorite,
                        )
                      else if (isSeriesItem &&
                          variant == DetailLayoutVariant.jellyfin)
                        _JellyfinDetailBody(
                          item: seriesItem ?? item,
                          series: seriesItem ?? item,
                          serverUrl: serverUrl,
                          overview: overview,
                          genres: genres,
                          people: people,
                          studios: studios,
                          isFavorite: isFavorite,
                          relatedItems:
                              related.value ?? const <BaseItemDto>[],
                          onPlay: () => pushPlayForDetail(
                            context,
                            seriesItem ?? item,
                          ),
                          onPlayEpisode: (episode) =>
                              pushPlayForDetail(context, episode),
                          onTrailer: _openTrailer,
                          onFavorite: _toggleFavorite,
                        )
                      else if (isSeriesDetail)
                        _DisneySeriesBody(
                          item: seriesItem,
                          serverUrl: serverUrl,
                          logoUrl: logoUrl,
                          overview: overview,
                          genres: genres,
                          isFavorite: isFavorite,
                          onFavorite: _toggleFavorite,
                          related: related.value ?? const <BaseItemDto>[],
                          people: people,
                          studios: studios,
                          audioLanguages: audioLanguages,
                          subtitleLanguages: subtitleLanguages,
                          imdbRating: imdbRating,
                          seerrMedia: widget.seerrMedia,
                          relatedKey: _relatedKey,
                          detailsKey: _detailsKey,
                          detailsSelected: _detailsSelected,
                          onShowRelated: _showRelated,
                          onShowDetails: _showDetails,
                        )
                      else if (variant == DetailLayoutVariant.disney)
                        _DisneyMovieBody(
                          item: item,
                          serverUrl: serverUrl,
                          logoUrl: logoUrl,
                          overview: overview,
                          genres: genres,
                          people: people,
                          studios: studios,
                          audioLanguages: audioLanguages,
                          subtitleLanguages: subtitleLanguages,
                          imdbRating: imdbRating,
                          isFavorite: isFavorite,
                          relatedItems:
                              related.value ?? const <BaseItemDto>[],
                          onPlay: () => pushPlayForDetail(context, item),
                          onTrailer: _openTrailer,
                          onFavorite: _toggleFavorite,
                          seerrMedia: widget.seerrMedia,
                        )
                      else if (variant == DetailLayoutVariant.netflix)
                        _NetflixDetailBody(
                          item: item,
                          serverUrl: serverUrl,
                          logoUrl: logoUrl,
                          overview: overview,
                          genres: genres,
                          people: people,
                          studios: studios,
                          isFavorite: isFavorite,
                          accent: skin?.accent ?? const Color(0xFFE50914),
                          relatedItems:
                              related.value ?? const <BaseItemDto>[],
                          onPlay: () => pushPlayForDetail(context, item),
                          onTrailer: _openTrailer,
                          onFavorite: _toggleFavorite,
                          seerrMedia: widget.seerrMedia,
                        )
                      else if (variant == DetailLayoutVariant.jellyfin)
                        _JellyfinDetailBody(
                          item: item,
                          serverUrl: serverUrl,
                          overview: overview,
                          genres: genres,
                          people: people,
                          studios: studios,
                          isFavorite: isFavorite,
                          relatedItems:
                              related.value ?? const <BaseItemDto>[],
                          onPlay: () => pushPlayForDetail(context, item),
                          onTrailer: _openTrailer,
                          onFavorite: _toggleFavorite,
                          seerrMedia: widget.seerrMedia,
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(36, 24, 36, 0),
                          child: _DetailTitle(
                            title: item.name ?? '',
                            logoUrl: logoUrl,
                            compact: compact,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(36, 8, 36, 0),
                          child: _ItemThemeChip(item: item),
                        ),
                        SizedBox(
                          height: compact ? 92 : constraints.maxHeight * 0.05,
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            36,
                            0,
                            compact ? 24 : 48,
                            18,
                          ),
                          child: compact
                              ? _CompactDetailBody(
                                  item: item,
                                  overview: overview,
                                  genres: genres,
                                  l10n: l10n,
                                  isFavorite: isFavorite,
                                  downloading: ref.watch(
                                    downloadManagerProvider.select(
                                      (m) => m.values.any(
                                        (t) =>
                                            t.fileName ==
                                                detailDownloadFilename(
                                                  item.name ?? 'video',
                                                ) &&
                                            t.isActive,
                                      ),
                                    ),
                                  ),
                                  onTrailer: _openTrailer,
                                  onFavorite: _toggleFavorite,
                                  onDownload: _downloadItem,
                                  seerrMedia: widget.seerrMedia,
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      width: 350,
                                      child: _DetailActions(
                                        item: item,
                                        l10n: l10n,
                                        isFavorite: isFavorite,
                                        downloading: ref.watch(
                                          downloadManagerProvider.select(
                                            (m) => m.values.any(
                                              (t) =>
                                                  t.fileName ==
                                                      detailDownloadFilename(
                                                        item.name ?? 'video',
                                                      ) &&
                                                  t.isActive,
                                            ),
                                          ),
                                        ),
                                        onTrailer: _openTrailer,
                                        onFavorite: _toggleFavorite,
                                        onDownload: _downloadItem,
                                        seerrMedia: widget.seerrMedia,
                                      ),
                                    ),
                                    const SizedBox(width: 26),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _DetailDescription(
                                            item: item,
                                            overview: overview,
                                            genres: genres,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(36, 0, 36, 8),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _showRelated,
                                child: _DetailTab(
                                  label: l10n.related,
                                  selected: !_detailsSelected,
                                ),
                              ),
                              const SizedBox(width: 32),
                              GestureDetector(
                                onTap: _showDetails,
                                child: _DetailTab(
                                  label: l10n.details,
                                  selected: _detailsSelected,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        if (related.value?.isNotEmpty ?? false)
                          Padding(
                            key: _relatedKey,
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _RelatedSection(
                              items: related.value!.take(10).toList(),
                              serverUrl: serverUrl,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 36),
                          child: KeyedSubtree(
                            key: _detailsKey,
                            child: _AdditionalInformation(
                              item: item,
                              overview: overview,
                              genres: genres,
                              compact: compact,
                              imdbRating: imdbRating,
                              people: people,
                              studios: studios,
                              audioLanguages: audioLanguages,
                              subtitleLanguages: subtitleLanguages,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          if (wideScreen &&
              (_trailerLoading ||
                  _trailerVideoController != null ||
                  _trailerError != null))
            Positioned(
              top: 94,
              right: 44,
              child: IconButton(
                onPressed: _closeTrailer,
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimeLogo extends StatelessWidget {
  const _PrimeLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/jellyfin-logo.png',
      height: 38,
      width: 150,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
    );
  }
}

class _DetailTitle extends StatelessWidget {
  const _DetailTitle({
    required this.title,
    required this.logoUrl,
    required this.compact,
  });

  final String title;
  final String? logoUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontSize: compact ? 34 : 48,
        fontWeight: FontWeight.bold,
      ),
    );

    if (logoUrl == null) return fallback;
    return Image.network(
      logoUrl!,
      width: compact ? 280 : 530,
      height: compact ? 80 : 210,
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

class _RelatedSection extends StatelessWidget {
  const _RelatedSection({
    required this.items,
    required this.serverUrl,
    this.title,
  });

  final List<BaseItemDto> items;
  final String? serverUrl;

  /// Título de la fila (`related` por defecto; Netflix usa `moreLikeThis`).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ContentRow(
      title: title ?? l10n.related,
      items: items,
      serverUrl: serverUrl,
      cardWidth: 320,
      height: 215,
      useBackdrop: true,
      showTitle: false,
      onItemTap: (item) => pushRelatedForDetail(context, item),
      onItemImageTap: (item) =>
          context.push('/home/details/${item.id}', extra: item),
    );
  }
}

class _AdditionalInformation extends StatelessWidget {
  const _AdditionalInformation({
    required this.item,
    required this.overview,
    required this.genres,
    required this.compact,
    required this.imdbRating,
    required this.people,
    required this.studios,
    required this.audioLanguages,
    required this.subtitleLanguages,
  });

  final BaseItemDto item;
  final String overview;
  final List<String> genres;
  final bool compact;
  final double? imdbRating;
  final List<BaseItemPerson> people;
  final List<String> studios;
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final details = DetailInfoCard(
      title: item.name ?? '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final genre in genres)
                DetailLinkText(text: localizeGenre(genre, l10n)),
              if (item.officialRating != null)
                DetailInfoValue(text: item.officialRating!),
              if (item.productionYear != null)
                DetailInfoValue(text: '${item.productionYear}'),
              if (item.runTimeTicks != null)
                DetailInfoValue(text: _formatDuration(item.runTimeTicks!)),
              if (imdbRating != null)
                DetailInfoValue(
                  text: 'IMDb ${imdbRating!.toStringAsFixed(1)}/10',
                ),
              if (item.isHD == true) const DetailTag(text: 'HD'),
            ],
          ),
          if (overview.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              overview,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 18,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
    final credits = DetailInfoCard(
      title: l10n.creatorsAndCast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailCreditRow(
            label: l10n.director,
            value: detailPeopleByType(people, 'Director'),
          ),
          const SizedBox(height: 14),
          DetailCreditRow(
            label: l10n.producers,
            value: detailPeopleByType(people, 'Producer'),
          ),
          const SizedBox(height: 14),
          DetailCreditRow(
            label: l10n.castLabel,
            value: detailPeopleNames(people),
          ),
          const SizedBox(height: 14),
          DetailCreditRow(label: l10n.studio, value: studios.join(', ')),
        ],
      ),
    );
    final audio = DetailInfoCard(
      title: l10n.audioLanguages,
      child: DetailLanguageInfo(
        icon: Icons.audiotrack_outlined,
        text: audioLanguages.isEmpty
            ? l10n.noAudioTracks
            : audioLanguages.join(', '),
      ),
    );
    final subtitles = DetailInfoCard(
      title: l10n.subtitlesLabel,
      child: DetailLanguageInfo(
        icon: Icons.subtitles_outlined,
        text: subtitleLanguages.isEmpty
            ? l10n.noSubtitles
            : subtitleLanguages.join(', '),
      ),
    );

    if (compact) {
      return Column(
        children: [
          details,
          const SizedBox(height: 18),
          credits,
          audio,
          subtitles,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [details, const SizedBox(height: 18), credits],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: Column(
            children: [audio, const SizedBox(height: 18), subtitles],
          ),
        ),
      ],
    );
  }
}

class _TrailerPanel extends StatelessWidget {
  const _TrailerPanel({
    required this.loading,
    required this.controller,
    required this.onClose,
    this.error,
    this.showClose = true,
  });

  final bool loading;
  final VideoController? controller;
  final VoidCallback onClose;
  final String? error;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (controller != null)
              Video(
                controller: controller!,
                controls: NoVideoControls,
                fit: BoxFit.cover,
                fill: Colors.black,
              )
            else
              const ColoredBox(color: Colors.black),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            if (showClose)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailActions extends ConsumerStatefulWidget {
  const _DetailActions({
    required this.item,
    required this.l10n,
    required this.isFavorite,
    required this.downloading,
    required this.onTrailer,
    required this.onFavorite,
    required this.onDownload,
    this.seerrMedia,
  });

  final BaseItemDto item;
  final AppLocalizations l10n;
  final bool isFavorite;
  final bool downloading;
  final VoidCallback onTrailer;
  final VoidCallback onFavorite;
  final VoidCallback onDownload;
  final SeerrMedia? seerrMedia;

  @override
  ConsumerState<_DetailActions> createState() => _DetailActionsState();
}

class _DetailActionsState extends ConsumerState<_DetailActions> {
  bool _sending = false;

  BaseItemDto get item => widget.item;
  AppLocalizations get l10n => widget.l10n;
  bool get isFavorite => widget.isFavorite;
  bool get downloading => widget.downloading;
  VoidCallback get onTrailer => widget.onTrailer;
  VoidCallback get onFavorite => widget.onFavorite;
  VoidCallback get onDownload => widget.onDownload;

  /// Acciones para un título de Seerr: "Solicitar" (estilo del botón de
  /// reproducir, en azul claro), chip de estado si la petición ya existe, o
  /// chip "En tu biblioteca".
  Widget _buildSeerrActions(
    BuildContext context,
    (SeerrMediaType, int) seerrRef,
  ) {
    final type = seerrRef.$1;
    final tmdbId = seerrRef.$2;
    final kind = type == SeerrMediaType.movie
        ? BaseItemKind.movie
        : BaseItemKind.series;
    final libraryStatus =
        ref
            .watch(
              seerrLibraryStatusProvider((
                kind: kind,
                tmdbId: tmdbId,
                title: item.name ?? '',
              )),
            )
            .value ??
        SeerrLibraryStatus.none;
    // Estado de la petición según Seerr (`mediaInfo.status`), para que tras
    // solicitar se vea el estado en vez del botón otra vez.
    final requestLabel = switch (widget.seerrMedia?.status) {
      SeerrMediaStatus.pending => l10n.seerrStatusRequested,
      // En Radarr/Sonarr pero sin media: "Pronto en tu biblioteca".
      SeerrMediaStatus.processing => l10n.seerrComingSoonInLibrary,
      SeerrMediaStatus.partiallyAvailable => l10n.seerrStatusPartial,
      SeerrMediaStatus.available => l10n.seerrStatusAvailable,
      _ => null,
    };
    final isComingSoon =
        widget.seerrMedia?.status == SeerrMediaStatus.processing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (libraryStatus == SeerrLibraryStatus.available)
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text(l10n.seerrInLibrary)),
          )
        else if (libraryStatus == SeerrLibraryStatus.placeholder)
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text(l10n.seerrComingSoonInLibrary)),
          )
        else if (requestLabel != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(
                isComingSoon ? Icons.schedule : Icons.check,
                size: 18,
              ),
              label: Text(requestLabel),
            ),
          )
        else
          _WideDetailButton(
            label: l10n.seerrRequest,
            icon: Icons.add,
            background: const Color(0xFF7FD4FF),
            foreground: Colors.black,
            onTap: _sending ? () {} : () => _requestSeerr(type, tmdbId),
          ),
      ],
    );
  }

  Future<void> _showMoreOptions() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF11161B),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.whereToWatch,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.cancel,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SeerrWatchProvidersView(
                  providers: widget.seerrMedia?.watchProviders ?? const [],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestSeerr(SeerrMediaType type, int tmdbId) async {
    final api = ref.read(seerrApiProvider);
    if (api == null) return;
    setState(() => _sending = true);
    try {
      await api.createRequest(type: type, mediaId: tmdbId);
      if (!mounted) return;
      _refreshSeerrState(type, tmdbId);
      unawaited(
        EasyLoading.showSuccess(
          l10n.seerrRequestSuccess,
          maskType: EasyLoadingMaskType.none,
          dismissOnTap: true,
        ),
      );
    } on SeerrException catch (e) {
      if (!mounted) return;
      // Seerr responde con el motivo real (permiso, cuota, duplicada…): se
      // muestra traducido en lugar de un error genérico.
      final text = _seerrRequestErrorText(l10n, e);
      final alreadyDone =
          e.kind == SeerrErrorKind.duplicate ||
          e.kind == SeerrErrorKind.noSeasons;
      if (alreadyDone) _refreshSeerrState(type, tmdbId);
      unawaited(
        alreadyDone
            ? EasyLoading.showInfo(
                text,
                maskType: EasyLoadingMaskType.none,
                dismissOnTap: true,
              )
            : EasyLoading.showError(
                text,
                maskType: EasyLoadingMaskType.none,
                dismissOnTap: true,
              ),
      );
    } catch (_) {
      if (mounted) {
        unawaited(
          EasyLoading.showError(
            l10n.seerrRequestError,
            maskType: EasyLoadingMaskType.none,
            dismissOnTap: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Refresca ficha, metadatos, estado en biblioteca y lista de peticiones para
  /// que la solicitud se refleje sin reiniciar la app.
  void _refreshSeerrState(SeerrMediaType type, int tmdbId) {
    final title = item.name ?? '';
    ref.invalidate(seerrDetailProvider((mediaType: type, tmdbId: tmdbId)));
    ref.invalidate(
      seerrCardMetadataProvider((
        mediaType: type,
        tmdbId: tmdbId,
        title: title,
      )),
    );
    ref.invalidate(
      seerrLibraryStatusProvider((
        kind: type == SeerrMediaType.movie
            ? BaseItemKind.movie
            : BaseItemKind.series,
        tmdbId: tmdbId,
        title: title,
      )),
    );
    ref.invalidate(seerrRequestsProvider);
  }

  /// Motivo del rechazo de Seerr traducido (permiso, cuota, duplicada, CSRF…).
  String _seerrRequestErrorText(AppLocalizations l10n, SeerrException e) {
    switch (e.kind) {
      case SeerrErrorKind.duplicate:
        return l10n.seerrRequestAlreadyRequested;
      case SeerrErrorKind.noSeasons:
        return l10n.seerrRequestNoSeasons;
      case SeerrErrorKind.forbidden:
        return e.message.toLowerCase().contains('quota')
            ? l10n.seerrRequestQuota
            : l10n.seerrRequestForbidden;
      case SeerrErrorKind.csrf:
        return l10n.seerrRequestCsrf;
      case SeerrErrorKind.certificate:
        return l10n.seerrCertError;
      case SeerrErrorKind.network:
        return l10n.seerrNetworkError;
      case SeerrErrorKind.unauthorized:
        return l10n.seerrUnauthorized;
      case SeerrErrorKind.notFound:
      case SeerrErrorKind.http:
      case SeerrErrorKind.response:
      case SeerrErrorKind.unknown:
        return l10n.seerrRequestError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final seerrRef = _seerrRefOf(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Trailer/favorito/descarga solo aplican a contenido de la biblioteca.
        if (seerrRef == null) ...[
          Row(
            children: [
              _DetailActionButton(
                icon: Icons.play_circle_outline,
                tooltip: l10n.watchTrailer,
                onTap: onTrailer,
              ),
              const SizedBox(width: 12),
              _DetailActionButton(
                icon: isFavorite ? Icons.favorite : Icons.add,
                tooltip: isFavorite
                    ? l10n.removeFromFavorites
                    : l10n.addToFavorites,
                onTap: onFavorite,
              ),
              const SizedBox(width: 12),
              _DetailActionButton(
                icon: Icons.download_outlined,
                tooltip: l10n.download,
                onTap: downloading ? () {} : onDownload,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        // Título de Seerr: "Solicitar" + "Dónde ver".
        if (seerrRef != null) ...[
          _buildSeerrActions(context, seerrRef),
          const SizedBox(height: 14),
        ] else if (playTargetFor(item) != DetailPlayTarget.unsupported) ...[
          // Ver ahora va al reproductor que toca: vídeo/audio a `/player`
          // y libro al lector (ver `play_routing.dart`).
          _WideDetailButton(
            label: l10n.watchNow,
            icon: Icons.play_arrow,
            primary: true,
            onTap: () => pushPlayForDetail(context, item),
          ),
          const SizedBox(height: 14),
        ] else if (item.type == BaseItemKind.musicAlbum ||
            item.type == BaseItemKind.playlist) ...[
          // Colección de música (álbum/single, playlist): Ver ahora
          // reproduce su primera pista en `/player`.
          _CollectionWatchNow(item: item, l10n: l10n),
          const SizedBox(height: 14),
        ] else if (item.type == BaseItemKind.musicArtist) ...[
          // Artista: su ficha de Música ya tiene reproducir.
          _WideDetailButton(
            label: l10n.watchNow,
            icon: Icons.play_arrow,
            primary: true,
            onTap: () {
              final name = (item.name ?? '').trim();
              if (name.isEmpty) return;
              context.push(
                '/music/artist/${Uri.encodeComponent(name)}',
                extra: {'jellyfin': item},
              );
            },
          ),
          const SizedBox(height: 14),
        ],
        _WideDetailButton(
          label: l10n.adFreeEasterEggButton,
          onTap: () => showAdFreeEasterEggDialog(context),
        ),
        const SizedBox(height: 14),
        _WideDetailButton(
          label: l10n.moreOptionsToEnjoy,
          onTap: seerrRef == null ? _noop : _showMoreOptions,
        ),
        // "Se incluye con Jellyfin"/términos solo para contenido de la
        // biblioteca; en títulos de Seerr (no están en la biblioteca) no aplica.
        if (seerrRef == null) ...[
          const SizedBox(height: 14),
          IncludedBadge(label: l10n.includedWithJellyfin, fontSize: 14),
          const SizedBox(height: 8),
          Text(
            l10n.termsApply,
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

/// Ver ahora para colecciones de música (álbum/single, playlist): resuelve la
/// primera pista con los providers de jellyfin_dart y la abre en `/player`.
/// Sin pistas todavía, no pinta nada (carga rápida, sin loader en el detalle).
class _CollectionWatchNow extends ConsumerWidget {
  const _CollectionWatchNow({required this.item, required this.l10n});

  final BaseItemDto item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = item.id ?? '';
    if (id.isEmpty) return const SizedBox.shrink();
    final tracks = item.type == BaseItemKind.playlist
        ? ref.watch(playlistTracksProvider(id)).value
        : ref.watch(libraryItemsProvider(id)).value;
    final first = tracks?.firstOrNull;
    final firstId = first?.id;
    if (firstId == null || firstId.isEmpty) return const SizedBox.shrink();
    return _WideDetailButton(
      label: l10n.watchNow,
      icon: Icons.play_arrow,
      primary: true,
      onTap: () => context.push('/player/$firstId', extra: first),
    );
  }
}

class _CompactDetailBody extends StatelessWidget {
  const _CompactDetailBody({
    required this.item,
    required this.overview,
    required this.genres,
    required this.l10n,
    required this.isFavorite,
    required this.downloading,
    required this.onTrailer,
    required this.onFavorite,
    required this.onDownload,
    this.seerrMedia,
  });

  final BaseItemDto item;
  final String overview;
  final List<String> genres;
  final AppLocalizations l10n;
  final bool isFavorite;
  final bool downloading;
  final VoidCallback onTrailer;
  final VoidCallback onFavorite;
  final VoidCallback onDownload;
  final SeerrMedia? seerrMedia;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailActions(
          item: item,
          l10n: l10n,
          isFavorite: isFavorite,
          downloading: downloading,
          onTrailer: onTrailer,
          onFavorite: onFavorite,
          onDownload: onDownload,
          seerrMedia: seerrMedia,
        ),
        const SizedBox(height: 24),
        _DetailDescription(item: item, overview: overview, genres: genres),
      ],
    );
  }
}

class _DetailDescription extends StatelessWidget {
  const _DetailDescription({
    required this.item,
    required this.overview,
    required this.genres,
  });

  final BaseItemDto item;
  final String overview;
  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overview.isNotEmpty)
          Text(
            overview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            for (final genre in genres)
              _DetailMeta(text: localizeGenre(genre, l10n)),
            if (item.officialRating != null)
              _DetailMeta(text: item.officialRating!),
            if (item.productionYear != null)
              _DetailMeta(text: '${item.productionYear}'),
            if (item.runTimeTicks != null)
              _DetailMeta(text: _formatDuration(item.runTimeTicks!)),
          ],
        ),
      ],
    );
  }
}

class _DetailActionButton extends StatelessWidget {
  const _DetailActionButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white, size: 25),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 50, height: 50),
      style: IconButton.styleFrom(
        side: const BorderSide(color: Colors.white70, width: 2),
        shape: const CircleBorder(),
      ),
    );
  }
}

/// Chip del theme/OST en la ficha: muestra loader mientras resuelve el
/// theme de Jellyfin (theme.mp3), etiqueta de origen y botón de mute.
/// Silencioso si no hay theme (ocupa cero espacio).
class _ItemThemeChip extends ConsumerStatefulWidget {
  const _ItemThemeChip({required this.item});

  final BaseItemDto item;

  @override
  ConsumerState<_ItemThemeChip> createState() => _ItemThemeChipState();
}

class _ItemThemeChipState extends ConsumerState<_ItemThemeChip> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final themeAsync = ref.watch(itemThemeProvider(widget.item));
    return themeAsync.when(
      loading: () => const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(height: 28, width: 28, child: AppLoader(size: 22)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (theme) {
        if (theme == null) return const SizedBox.shrink();
        final muted = ItemThemePlayer.instance.isMuted;
        final sourceLabel = l10n.ostThemeFromJellyfin;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_note_outlined,
              color: Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${l10n.ostTheme} · $sourceLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: muted ? l10n.ostUnmuteTheme : l10n.ostMuteTheme,
              onPressed: () async {
                final next = !ItemThemePlayer.instance.isMuted;
                await ItemThemePlayer.instance.setMuted(next);
                if (mounted) setState(() {});
                // Si se reactiva y el theme sigue disponible, retoma.
                if (!next) {
                  final t = ref.read(itemThemeProvider(widget.item)).value;
                  final url = t?.streamUrl ?? theme.streamUrl;
                  if (url.isNotEmpty) {
                    await ItemThemePlayer.instance.play(url, inDetail: true);
                  }
                }
              },
              icon: Icon(
                muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                color: Colors.white70,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
            ),
          ],
        );
      },
    );
  }
}

class _WideDetailButton extends StatelessWidget {
  const _WideDetailButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
    this.background,
    this.foreground,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool primary;

  /// Color de fondo explícito (p. ej. azul claro del botón "Solicitar").
  final Color? background;

  /// Color de texto/icono explícito.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? (primary ? Colors.white : const Color(0xFF363B43));
    final fg = foreground ?? (primary ? Colors.black : Colors.white);
    return AppHover(
      onTap: onTap,
      effect: AppHoverEffect.invert,
      config: AppHoverConfig(
        borderRadius: BorderRadius.circular(7),
        highlightNormal: Colors.transparent,
        highlightHovered: Colors.transparent,
      ),
      playSoundOnHover: true,
      child: Container(
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 28),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailMeta extends StatelessWidget {
  const _DetailMeta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DetailTab extends StatelessWidget {
  const _DetailTab({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: selected
          ? BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white54,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

String _formatDuration(int ticks) {
  final minutes = ticks ~/ 600000000;
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  return hours > 0 ? '$hours h $remaining min' : '$remaining min';
}

void _noop() {}

/// Fracción reproducida (0..1) si hay progreso parcial; `null` si no hay
/// nada que continuar (sin posición o ya visto entero).
double? _playProgress(BaseItemDto item) {
  final total = item.runTimeTicks;
  final pos = item.userData?.playbackPositionTicks ?? 0;
  if (total == null ||
      total <= 0 ||
      pos <= 0 ||
      (item.userData?.played ?? false)) {
    return null;
  }
  return (pos / total).clamp(0.0, 1.0);
}

/// Minutos restantes de reproducción, si hay progreso parcial.
int? _remainingMinutes(BaseItemDto item) {
  final total = item.runTimeTicks;
  final pos = item.userData?.playbackPositionTicks ?? 0;
  if (total == null ||
      total <= 0 ||
      pos <= 0 ||
      (item.userData?.played ?? false)) {
    return null;
  }
  final minutes = ((total - pos) / 600000000 / 60).round();
  return minutes > 0 ? minutes : null;
}

/// Insignias de formato (1080p/H264/AAC…) del primer stream de cada tipo.
List<String> _formatBadges(BaseItemDto item) {
  MediaStream? firstOf(MediaStreamType type) {
    for (final s in item.mediaStreams ?? const <MediaStream>[]) {
      if (s.type == type) return s;
    }
    return null;
  }

  final out = <String>[];
  final video = firstOf(MediaStreamType.video);
  final height = video?.height;
  if (height != null) {
    out.add(
      height >= 2160
          ? '4K'
          : height >= 1080
          ? '1080p'
          : height >= 720
          ? '720p'
          : '${height}p',
    );
  } else if (item.isHD == true) {
    out.add('HD');
  }
  final videoCodec = (video?.codec ?? '').trim();
  if (videoCodec.isNotEmpty) out.add(videoCodec.toUpperCase());
  final audioCodec = (firstOf(MediaStreamType.audio)?.codec ?? '').trim();
  if (audioCodec.isNotEmpty) out.add(audioCodec.toUpperCase());
  return out;
}

/// URL de la foto de una persona del reparto (`/Persons/<nombre>/...`).
String _personPhotoUrl(String serverUrl, String name) =>
    '$serverUrl/Persons/${Uri.encodeComponent(name)}/Images/Primary?maxWidth=200';

/// VER: episodio a medias > siguiente sin ver > primer episodio.
BaseItemDto? _verTargetEpisode(List<BaseItemDto> episodes) {
  BaseItemDto? resume;
  BaseItemDto? next;
  for (final ep in episodes) {
    final ticks = ep.userData?.playbackPositionTicks ?? 0;
    final played = ep.userData?.played ?? false;
    if (ticks > 0 && resume == null) resume = ep;
    if (!played && ticks <= 0 && next == null) next = ep;
    if (resume != null && next != null) break;
  }
  if (episodes.isEmpty) return null;
  return resume ?? next ?? episodes.first;
}

/// Episodios de una temporada: por `seasonId`, si no por número de temporada.
List<BaseItemDto> _episodesForSeason(
  List<BaseItemDto> all,
  BaseItemDto? season,
) {
  if (season == null) return all;
  final byId = all
      .where((e) => season.id != null && e.seasonId == season.id)
      .toList();
  if (byId.isNotEmpty) return byId;
  return all.where((e) => e.parentIndexNumber == season.indexNumber).toList();
}

/// Cuerpo del detalle de SERIE solo para el skin Disney (estilo Netflix de la
/// referencia: logo, meta, VER, tabs Episodios/Sugerencias/Detalles).
/// Lógica de reproducción: VER reanuda el episodio a medias, si no el
/// siguiente sin ver, si no el S1:E1. Tocar un episodio lo reproduce directo.
class _DisneySeriesBody extends ConsumerStatefulWidget {
  const _DisneySeriesBody({
    required this.item,
    required this.serverUrl,
    required this.logoUrl,
    required this.overview,
    required this.genres,
    required this.isFavorite,
    required this.onFavorite,
    required this.related,
    required this.people,
    required this.studios,
    required this.audioLanguages,
    required this.subtitleLanguages,
    required this.imdbRating,
    this.seerrMedia,
    required this.relatedKey,
    required this.detailsKey,
    required this.detailsSelected,
    required this.onShowRelated,
    required this.onShowDetails,
  });

  final BaseItemDto item;
  final String? serverUrl;
  final String? logoUrl;
  final String overview;
  final List<String> genres;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final List<BaseItemDto> related;
  final List<BaseItemPerson> people;
  final List<String> studios;
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;
  final double? imdbRating;
  final SeerrMedia? seerrMedia;
  final GlobalKey relatedKey;
  final GlobalKey detailsKey;
  final bool detailsSelected;
  final VoidCallback onShowRelated;
  final VoidCallback onShowDetails;

  @override
  ConsumerState<_DisneySeriesBody> createState() => _DisneySeriesBodyState();
}

class _DisneySeriesBodyState extends ConsumerState<_DisneySeriesBody> {
  /// 0 = Episodios, 1 = Sugerencias, 2 = Extras.
  int _tab = 0;
  String? _seasonId;

  BaseItemDto get _series => widget.item;

  void _playEpisode(BaseItemDto episode) {
    final id = episode.id;
    if (id == null || id.isEmpty || !mounted) return;
    context.push('/player/$id', extra: episode);
  }

  /// VER: episodio a medias > siguiente sin ver > primer episodio.
  BaseItemDto? _verTarget(List<BaseItemDto> episodes) =>
      _verTargetEpisode(episodes);

  List<BaseItemDto> _episodesFor(List<BaseItemDto> all, BaseItemDto? season) =>
      _episodesForSeason(all, season);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 760;
    final seriesId = _series.id ?? '';
    // La tarjeta de capítulo con barra de progreso/tiempo restante/meta es de
    // Prime; en otros skins se mantiene la tarjeta básica.
    final prime = ref.watch(skinControllerProvider).value?.id == 'amazon_prime';
    final seasons =
        ref.watch(seriesSeasonsProvider(seriesId)).value ??
        const <BaseItemDto>[];
    final allEpisodes =
        ref.watch(seriesEpisodesProvider(seriesId)).value ??
        const <BaseItemDto>[];
    // Los especiales (temporada 0) viven en la pestaña EXTRAS.
    final episodeSeasons = seasons.where((s) => s.indexNumber != 0).toList();
    final effectiveSeasons = episodeSeasons.isNotEmpty
        ? episodeSeasons
        : seasons;
    BaseItemDto? season;
    if (effectiveSeasons.isNotEmpty) {
      season =
          effectiveSeasons.where((s) => s.id == _seasonId).firstOrNull ??
          effectiveSeasons.first;
    }
    final seasonEpisodes = _episodesFor(allEpisodes, season);
    final verTarget = _verTarget(allEpisodes);
    final verIsResume = (verTarget?.userData?.playbackPositionTicks ?? 0) > 0;
    // Sin episodios no hay "Ver ahora" ni pestañas de Episodios/Extras.
    final hasEpisodes = allEpisodes.isNotEmpty;
    final tab = (!hasEpisodes && (_tab == 0 || _tab == 2)) ? 1 : _tab;

    final rating = (_series.officialRating ?? '').trim();
    final year = _series.productionYear;
    final metaParts = <String>[
      if (year != null) '$year',
      if (seasons.isNotEmpty) l10n.seriesSeasons(seasons.length),
      ...localizeGenres(widget.genres.take(2), l10n),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 24, 36, 0),
          child: _DetailTitle(
            title: _series.name ?? '',
            logoUrl: widget.logoUrl,
            compact: compact,
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (rating.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A42),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rating,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (_series.isHD == true) const DetailTag(text: 'HD'),
              if (widget.subtitleLanguages.isNotEmpty)
                const DetailTag(text: 'CC'),
            ],
          ),
        ),
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              metaParts.join(' • '),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
        if (widget.overview.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              widget.overview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.35,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (widget.seerrMedia != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: SizedBox(
              width: compact ? double.infinity : 350,
              child: _DetailActions(
                item: _series,
                l10n: l10n,
                isFavorite: widget.isFavorite,
                downloading: false,
                onTrailer: _noop,
                onFavorite: widget.onFavorite,
                onDownload: _noop,
                seerrMedia: widget.seerrMedia,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Row(
              children: [
                if (hasEpisodes) ...[
                  _VerButton(
                    label: verIsResume ? l10n.resume : l10n.watchNow,
                    onTap: verTarget == null
                        ? _noop
                        : () => _playEpisode(verTarget),
                  ),
                  const SizedBox(width: 12),
                ],
                _DetailActionButton(
                  icon: widget.isFavorite ? Icons.check : Icons.add,
                  onTap: widget.onFavorite,
                ),
              ],
            ),
          ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (hasEpisodes) ...[
                    _SeriesTabButton(
                      label: l10n.episodes.toUpperCase(),
                      selected: tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    const SizedBox(width: 32),
                  ],
                  _SeriesTabButton(
                    label: l10n.suggestions.toUpperCase(),
                    selected: tab == 1 && !widget.detailsSelected,
                    onTap: () {
                      setState(() => _tab = 1);
                      widget.onShowRelated();
                    },
                  ),
                  if (hasEpisodes) ...[
                    const SizedBox(width: 32),
                    _SeriesTabButton(
                      label: l10n.extras.toUpperCase(),
                      selected: tab == 2,
                      onTap: () => setState(() => _tab = 2),
                    ),
                  ],
                  const SizedBox(width: 32),
                  _SeriesTabButton(
                    label: l10n.details.toUpperCase(),
                    selected: widget.detailsSelected,
                    onTap: widget.onShowDetails,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: Colors.white24),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (tab == 0)
          _EpisodesTab(
            seasons: effectiveSeasons,
            season: season,
            episodes: seasonEpisodes,
            isLoading:
                allEpisodes.isEmpty &&
                ref.watch(seriesEpisodesProvider(seriesId)).isLoading,
            l10n: l10n,
            prime: prime,
            onSeasonChanged: (id) => setState(() => _seasonId = id),
            onEpisodeTap: _playEpisode,
          )
        else if (tab == 1)
          Padding(
            key: widget.relatedKey,
            padding: const EdgeInsets.only(bottom: 24),
            child: _RelatedSection(
              items: widget.related.take(10).toList(),
              serverUrl: widget.serverUrl,
            ),
          )
        else if (tab == 2)
          _ExtrasTab(
            episodes: allEpisodes
                .where((e) => e.parentIndexNumber == 0)
                .toList(),
            l10n: l10n,
            prime: prime,
            onEpisodeTap: _playEpisode,
          ),
        Padding(
          key: widget.detailsKey,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 36),
          child: _AdditionalInformation(
            item: _series,
            overview: widget.overview,
            genres: widget.genres,
            compact: compact,
            imdbRating: widget.imdbRating,
            people: widget.people,
            studios: widget.studios,
            audioLanguages: widget.audioLanguages,
            subtitleLanguages: widget.subtitleLanguages,
          ),
        ),
      ],
    );
  }
}

/// Botón VER blanco estilo Netflix.
class _VerButton extends StatelessWidget {
  const _VerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow, color: Colors.black, size: 22),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pestaña de texto con subrayado al estar seleccionada.
class _SeriesTabButton extends StatelessWidget {
  const _SeriesTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = Colors.white,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Color del subrayado seleccionado (blanco Disney/Prime, acento Netflix).
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: selected
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: selectedColor, width: 3),
                ),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

/// Pestaña Episodios: selector de temporada + parrilla de capítulos.
class _EpisodesTab extends StatelessWidget {
  const _EpisodesTab({
    required this.seasons,
    required this.season,
    required this.episodes,
    required this.isLoading,
    required this.l10n,
    required this.prime,
    required this.onSeasonChanged,
    required this.onEpisodeTap,
  });

  final List<BaseItemDto> seasons;
  final BaseItemDto? season;
  final List<BaseItemDto> episodes;
  final bool isLoading;
  final AppLocalizations l10n;
  final bool prime;
  final ValueChanged<String?> onSeasonChanged;
  final void Function(BaseItemDto episode) onEpisodeTap;

  String _seasonLabel(BaseItemDto s) {
    final name = (s.name ?? '').trim();
    if (name.isNotEmpty) return name;
    if (s.indexNumber != null) return '${l10n.season} ${s.indexNumber}';
    return l10n.season;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 0, 36, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (seasons.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: season?.id,
                  isDense: true,
                  dropdownColor: const Color(0xFF11161B),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  items: [
                    for (final s in seasons)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(_seasonLabel(s)),
                      ),
                  ],
                  onChanged: onSeasonChanged,
                ),
              ),
            )
          else if (season != null)
            Text(
              _seasonLabel(season!),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 14),
          if (isLoading && episodes.isEmpty)
            const Center(child: AppLoader())
          else
            // Wrap en vez de GridView: el alto lo marca el contenido (sin el
            // aire muerto del childAspectRatio fijo) y runSpacing 0 lo pega.
            _EpisodeWrap(
              episodes: episodes,
              prime: prime,
              onEpisodeTap: onEpisodeTap,
            ),
        ],
      ),
    );
  }
}

/// Pestaña Extras: especiales (temporada 0) con las mismas tarjetas.
/// Si no hay, mensaje de vacío.
class _ExtrasTab extends StatelessWidget {
  const _ExtrasTab({
    required this.episodes,
    required this.l10n,
    required this.prime,
    required this.onEpisodeTap,
  });

  final List<BaseItemDto> episodes;
  final AppLocalizations l10n;
  final bool prime;
  final void Function(BaseItemDto episode) onEpisodeTap;

  @override
  Widget build(BuildContext context) {
    if (episodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(36, 8, 36, 36),
        child: Text(
          l10n.noResults,
          style: const TextStyle(color: Colors.white54),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 0, 36, 36),
      child: _EpisodeWrap(
        episodes: episodes,
        prime: prime,
        onEpisodeTap: onEpisodeTap,
      ),
    );
  }
}

/// Parrilla de capítulos sin alto fijo: cada tarjeta mide lo que su contenido
/// y las filas quedan pegadas (runSpacing 0).
class _EpisodeWrap extends StatelessWidget {
  const _EpisodeWrap({
    required this.episodes,
    required this.prime,
    required this.onEpisodeTap,
  });

  final List<BaseItemDto> episodes;
  final bool prime;
  final void Function(BaseItemDto episode) onEpisodeTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 4
        : width >= 800
        ? 3
        : 2;
    const gap = 16.0;
    final cardWidth =
        (width - 72 - gap * (columns - 1)) / columns; // padding 36+36
    return Wrap(
      spacing: gap,
      runSpacing: 80,
      children: [
        for (var i = 0; i < episodes.length; i++)
          SizedBox(
            width: cardWidth,
            child: _EpisodeCard(
              episode: episodes[i],
              index: episodes[i].indexNumber ?? (i + 1),
              prime: prime,
              onTap: () => onEpisodeTap(episodes[i]),
            ),
          ),
      ],
    );
  }
}

/// Tarjeta de capítulo. En Prime muestra barra de progreso (visto/a medias),
/// "tiempo restante" si está a medias y meta (edad/CC/duración/fecha). En el
/// resto de skins mantiene la tarjeta básica.
class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.index,
    required this.prime,
    required this.onTap,
  });

  final BaseItemDto episode;
  final int index;
  final bool prime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final overview = (episode.overview ?? '').trim();
    final ticks = episode.runTimeTicks;
    final userData = episode.userData;
    final progress = userData?.playedPercentage ?? 0;
    final played = userData?.played ?? false;
    final partial = progress > 0 && !played;

    // "Tiempo restante: X min" solo cuando está a medias.
    String? remainingText;
    final pos = userData?.playbackPositionTicks;
    if (prime && partial && ticks != null && pos != null && pos > 0) {
      final remaining = ticks - pos;
      if (remaining > 0) {
        final minutes = remaining ~/ 600000000;
        remainingText = minutes < 1
            ? l10n.timeRemainingLessThanAMinute
            : l10n.timeRemaining(minutes);
      }
    }

    final title = '$index. ${episode.name ?? ''}'.trim();
    // El tap lo gestiona el AppHover (evita doble navegación).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          // Mismo hover universal de las filas (Continuar viendo): escala +
          // borde blanco + icono de play. La descripción sigue debajo.
          child: AppHover(
            effect: AppHoverEffect.scaleHighlightOutline,
            config: AppHoverConfig.scaleHighlightOutline(
              scale: 1.04,
              radius: BorderRadius.circular(8),
              outlineHoveredColor: Colors.white,
              outlineHoveredWidth: 2,
            ),
            onTap: onTap,
            child: _EpisodeHoverThumb(
              episode: episode,
              progress: progress,
              prime: prime,
              watched: played,
              remainingText: remainingText,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          prime ? title : title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (overview.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            overview,
            maxLines: prime ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (prime)
          _EpisodePrimeMeta(episode: episode, l10n: l10n)
        else if (ticks != null)
          Text(
            '(${_formatDuration(ticks)})',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
      ],
    );
  }
}

/// Meta de un capítulo estilo Prime: edad + CC + duración + fecha.
class _EpisodePrimeMeta extends StatelessWidget {
  const _EpisodePrimeMeta({required this.episode, required this.l10n});

  final BaseItemDto episode;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final age = (episode.officialRating ?? '').trim();
    final ticks = episode.runTimeTicks;
    final hasCC = (episode.mediaStreams ?? const <MediaStream>[]).any(
      (s) => s.type == MediaStreamType.subtitle,
    );
    final date = episode.premiereDate;
    final children = <Widget>[
      if (age.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A42),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            age,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      if (hasCC)
        const Icon(Icons.subtitles_outlined, size: 16, color: Colors.white70),
      if (ticks != null)
        Text(
          _formatDuration(ticks),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      if (date != null)
        Text(
          DateFormat.yMMMd(l10n.localeName).format(date.toLocal()),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// Contenido hover de la miniatura: imagen + progreso y, al hover/foco,
/// oscurecido con icono de play (lee [AppHoverScope] del AppHover padre).
class _EpisodeHoverThumb extends StatelessWidget {
  const _EpisodeHoverThumb({
    required this.episode,
    required this.progress,
    required this.prime,
    required this.watched,
    this.remainingText,
  });

  final BaseItemDto episode;
  final double progress;
  final bool prime;
  final bool watched;
  final String? remainingText;

  @override
  Widget build(BuildContext context) {
    final hovered = AppHoverScope.of(context)?.hovered ?? false;
    // Visto → barra completa; a medias → progreso real.
    final value = watched ? 1.0 : (progress / 100).clamp(0.0, 1.0);
    final showBar = watched || progress > 0;
    return Stack(
      fit: StackFit.expand,
      children: [
        _ThumbImage(episode: episode),
        if (showBar)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: Colors.black38,
              valueColor: AlwaysStoppedAnimation<Color>(
                prime ? Colors.white : Colors.redAccent,
              ),
            ),
          ),
        if (prime && remainingText != null)
          Positioned(
            right: 8,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                remainingText!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        if (hovered)
          ColoredBox(
            color: const Color(0x59000000),
            child: Center(
              child: HoverPlayGlyph(
                style: prime
                    ? HoverPlayGlyphStyle.prime
                    : HoverPlayGlyphStyle.outline,
              ),
            ),
          ),
      ],
    );
  }
}

/// Miniatura del capítulo: Thumb con respaldo a Primary si falla o no existe.
class _ThumbImage extends ConsumerWidget {
  const _ThumbImage({required this.episode});

  final BaseItemDto episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverUrl = ref.watch(authServerUrlProvider);
    if (serverUrl == null) return const ColoredBox(color: Colors.black26);
    final thumb = itemThumbUrl(serverUrl, episode);
    final primary = itemImageUrl(serverUrl, episode, maxWidth: 640);
    return Image.network(
      thumb,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Image.network(
        primary,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black26),
      ),
    );
  }
}

/// Referencia Seerr de un item marcado con id `seerr:<type>:<tmdbId>`.
(SeerrMediaType, int)? _seerrRefOf(BaseItemDto item) {
  final id = item.id ?? '';
  if (!id.startsWith('seerr:')) return null;
  final parts = id.split(':');
  if (parts.length != 3) return null;
  final type = SeerrMediaType.fromString(parts[1]);
  final tmdb = int.tryParse(parts[2]);
  if (type == null || tmdb == null) return null;
  return (type, tmdb);
}

/// Barra fina de progreso de reproducción.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }
}

/// Pastilla oscura de metadato (edad, HD, CC…) estilo Disney.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A42),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Cuerpo Disney para pelis/episodios: cabecera con logo, badges, meta,
/// sinopsis, progreso y botones; tabs SUGERENCIAS / EXTRAS / DETALLES.
/// Las series Disney siguen con [_DisneySeriesBody].
class _DisneyMovieBody extends StatefulWidget {
  const _DisneyMovieBody({
    required this.item,
    required this.serverUrl,
    required this.logoUrl,
    required this.overview,
    required this.genres,
    required this.people,
    required this.studios,
    required this.audioLanguages,
    required this.subtitleLanguages,
    required this.imdbRating,
    required this.isFavorite,
    required this.relatedItems,
    required this.onPlay,
    required this.onTrailer,
    required this.onFavorite,
    this.seerrMedia,
  });

  final BaseItemDto item;
  final String? serverUrl;
  final String? logoUrl;
  final String overview;
  final List<String> genres;
  final List<BaseItemPerson> people;
  final List<String> studios;
  final List<String> audioLanguages;
  final List<String> subtitleLanguages;
  final double? imdbRating;
  final bool isFavorite;
  final List<BaseItemDto> relatedItems;
  final VoidCallback onPlay;
  final VoidCallback onTrailer;
  final VoidCallback onFavorite;
  final SeerrMedia? seerrMedia;

  @override
  State<_DisneyMovieBody> createState() => _DisneyMovieBodyState();
}

class _DisneyMovieBodyState extends State<_DisneyMovieBody> {
  /// 0 = Sugerencias, 1 = Extras, 2 = Detalles.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 760;
    final item = widget.item;
    final year = item.productionYear;
    final metaParts = <String>[
      if (year != null) '$year',
      if (item.runTimeTicks != null) _formatDuration(item.runTimeTicks!),
      ...localizeGenres(widget.genres.take(2), l10n),
    ];
    final progress = _playProgress(item);
    final remaining = _remainingMinutes(item);
    final hasProgress = progress != null && remaining != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 24, 36, 0),
          child: _DetailTitle(
            title: item.name ?? '',
            logoUrl: widget.logoUrl,
            compact: compact,
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if ((item.officialRating ?? '').isNotEmpty)
                _MetaChip(text: item.officialRating!),
              if (item.isHD == true) const DetailTag(text: 'HD'),
              if (widget.subtitleLanguages.isNotEmpty)
                const DetailTag(text: 'CC'),
            ],
          ),
        ),
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              metaParts.join(' • '),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
        if (widget.overview.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              widget.overview,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.35,
              ),
            ),
          ),
        ],
        if (hasProgress) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProgressLine(progress: progress),
                const SizedBox(height: 4),
                Text(
                  l10n.timeRemaining(remaining),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.seerrMedia != null)
                SizedBox(
                  width: compact ? double.infinity : 320,
                  child: _DetailActions(
                    item: item,
                    l10n: l10n,
                    isFavorite: widget.isFavorite,
                    downloading: false,
                    onTrailer: _noop,
                    onFavorite: widget.onFavorite,
                    onDownload: _noop,
                    seerrMedia: widget.seerrMedia,
                  ),
                )
              else ...[
                _VerButton(
                  label: hasProgress ? l10n.resume : l10n.watchNow,
                  onTap: widget.onPlay,
                ),
                // Reiniciar: vuelve al reproductor (sin posición inicial
                // dedicada en el player; ver FTD).
                _DetailActionButton(
                  icon: Icons.replay,
                  tooltip: l10n.watchNow,
                  onTap: widget.onPlay,
                ),
              ],
              _DetailActionButton(
                icon: Icons.movie_outlined,
                tooltip: l10n.watchTrailer,
                onTap: widget.onTrailer,
              ),
              _DetailActionButton(
                icon: widget.isFavorite ? Icons.check : Icons.add,
                onTap: widget.onFavorite,
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SeriesTabButton(
                    label: l10n.suggestions.toUpperCase(),
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 32),
                  _SeriesTabButton(
                    label: l10n.extras.toUpperCase(),
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const SizedBox(width: 32),
                  _SeriesTabButton(
                    label: l10n.details.toUpperCase(),
                    selected: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: Colors.white24),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_tab == 0)
          widget.relatedItems.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _RelatedSection(
                    items: widget.relatedItems.take(10).toList(),
                    serverUrl: widget.serverUrl,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(36, 8, 36, 36),
                  child: Text(
                    l10n.noResults,
                    style: const TextStyle(color: Colors.white54),
                  ),
                )
        else if (_tab == 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 8, 36, 36),
            child: _WideDetailButton(
              label: l10n.watchTrailer,
              icon: Icons.movie_outlined,
              onTap: widget.onTrailer,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 36),
            child: _AdditionalInformation(
              item: item,
              overview: widget.overview,
              genres: widget.genres,
              compact: compact,
              imdbRating: widget.imdbRating,
              people: widget.people,
              studios: widget.studios,
              audioLanguages: widget.audioLanguages,
              subtitleLanguages: widget.subtitleLanguages,
            ),
          ),
      ],
    );
  }
}

/// Cuerpo Netflix para pelis y series: póster lateral con resume, centro
/// con título/meta y tabs Overview/Episodios/Tráilers/Más como este.
class _NetflixDetailBody extends ConsumerStatefulWidget {
  const _NetflixDetailBody({
    required this.item,
    required this.serverUrl,
    required this.logoUrl,
    required this.overview,
    required this.genres,
    required this.people,
    required this.studios,
    required this.isFavorite,
    required this.accent,
    required this.relatedItems,
    required this.onPlay,
    required this.onTrailer,
    required this.onFavorite,
    this.series,
    this.onPlayEpisode,
    this.seerrMedia,
  });

  /// Item a mostrar (peli o serie). Si [series] no es null, modo serie.
  final BaseItemDto item;
  final BaseItemDto? series;
  final String? serverUrl;
  final String? logoUrl;
  final String overview;
  final List<String> genres;
  final List<BaseItemPerson> people;
  final List<String> studios;
  final bool isFavorite;
  final Color accent;
  final List<BaseItemDto> relatedItems;
  final VoidCallback onPlay;
  final VoidCallback onTrailer;
  final VoidCallback onFavorite;
  final void Function(BaseItemDto episode)? onPlayEpisode;
  final SeerrMedia? seerrMedia;

  @override
  ConsumerState<_NetflixDetailBody> createState() =>
      _NetflixDetailBodyState();
}

class _NetflixDetailBodyState extends ConsumerState<_NetflixDetailBody> {
  int _tab = 0;
  String? _seasonId;

  bool get _isSeries => widget.series != null;
  BaseItemDto get _display => widget.series ?? widget.item;
  String get _seriesId => widget.series?.id ?? '';

  /// Reproducir o, si es un título virtual de Seerr, solicitarlo con el
  /// flujo de `_DetailActions` (igual que `_DisneySeriesBody`).
  Widget _playOrRequest(AppLocalizations l10n, BaseItemDto? verTarget) {
    final seerr = widget.seerrMedia;
    if (seerr != null) {
      return _DetailActions(
        item: _display,
        l10n: l10n,
        isFavorite: widget.isFavorite,
        downloading: false,
        onTrailer: _noop,
        onFavorite: widget.onFavorite,
        onDownload: _noop,
        seerrMedia: seerr,
      );
    }
    return _NetflixPlayButton(
      accent: widget.accent,
      onTap: () {
        final target = _isSeries ? verTarget : null;
        if (target != null) {
          widget.onPlayEpisode?.call(target);
        } else {
          widget.onPlay();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 760;
    final display = _display;
    final seasons = _seriesId.isEmpty
        ? const <BaseItemDto>[]
        : ref.watch(seriesSeasonsProvider(_seriesId)).value ??
            const <BaseItemDto>[];
    final allEpisodes = _seriesId.isEmpty
        ? const <BaseItemDto>[]
        : ref.watch(seriesEpisodesProvider(_seriesId)).value ??
            const <BaseItemDto>[];
    final episodeSeasons =
        seasons.where((s) => s.indexNumber != 0).toList();
    final effectiveSeasons = episodeSeasons.isNotEmpty
        ? episodeSeasons
        : seasons;
    BaseItemDto? season;
    if (effectiveSeasons.isNotEmpty) {
      season =
          effectiveSeasons.where((s) => s.id == _seasonId).firstOrNull ??
          effectiveSeasons.first;
    }
    final seasonEpisodes = _episodesForSeason(allEpisodes, season);
    final verTarget = _isSeries ? _verTargetEpisode(allEpisodes) : null;
    final verProgress =
        verTarget == null ? null : _playProgress(verTarget);
    final movieProgress = !_isSeries ? _playProgress(display) : null;

    final year = display.productionYear;
    final ratingChip = (display.officialRating ?? '').trim();
    final runtimeTicks = display.runTimeTicks;
    final countOrDuration = _isSeries
        ? (seasons.isNotEmpty
              ? l10n.seriesSeasons(seasons.length)
              : null)
        : (runtimeTicks != null ? _formatDuration(runtimeTicks) : null);
    final metaParts = <String>[
      if (year != null) '$year',
      if (ratingChip.isNotEmpty) ratingChip,
    ];
    if (countOrDuration != null) metaParts.add(countOrDuration);
    // 0 = Overview, 1 = Episodios (series), 2 = Tráilers, 3 = Más como este.
    final episodesTab = _isSeries ? 1 : -1;
    final trailersTab = _isSeries ? 2 : 1;
    final moreTab = _isSeries ? 3 : 2;

    Widget poster(double width) {
      final url = widget.serverUrl == null
          ? null
          : itemImageUrl(widget.serverUrl!, display, maxWidth: 400);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: url == null
                ? ColoredBox(
                    color: Colors.white10,
                    child: Center(
                      child: Text(
                        (display.name ?? '?').isEmpty
                            ? '?'
                            : display.name!.substring(0, 1),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 48,
                        ),
                      ),
                    ),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Colors.white10),
                  ),
          ),
        ),
      );
    }

    Widget resumeBlock() {
      final target = verTarget;
      if (_isSeries) {
        if (target == null) return const SizedBox.shrink();
        final pos = target.indexNumber;
        final seas = target.parentIndexNumber;
        final epLabel = (seas != null && pos != null)
            ? 'S$seas:E$pos'
            : (target.name ?? '');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.resume,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              '$epLabel: ${target.name ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (verProgress != null) ...[
              const SizedBox(height: 8),
              _ProgressLine(progress: verProgress),
            ],
            if ((target.overview ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                target.overview!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ],
        );
      }
      if (movieProgress == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.resume,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _ProgressLine(progress: movieProgress),
        ],
      );
    }

    final header = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  poster(120),
                  const SizedBox(width: 16),
                  Expanded(child: resumeBlock()),
                ],
              ),
              const SizedBox(height: 16),
              _netflixTitle(l10n, display, compact),
              const SizedBox(height: 8),
              Text(
                metaParts.join(' | '),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 200, child: Column(children: [poster(200), const SizedBox(height: 12), resumeBlock()])),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _netflixTitle(l10n, display, compact),
                    const SizedBox(height: 8),
                    Text(
                      metaParts.join(' | '),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _playOrRequest(l10n, verTarget),
                  ],
                ),
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 24, 36, 0),
          child: header,
        ),
        if (compact) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: _playOrRequest(l10n, verTarget),
          ),
        ],
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SeriesTabButton(
                      label: l10n.overview,
                      selected: _tab == 0,
                      selectedColor: widget.accent,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    if (_isSeries) ...[
                      const SizedBox(width: 28),
                      _SeriesTabButton(
                        label: l10n.episodes.toUpperCase(),
                        selected: _tab == episodesTab,
                        selectedColor: widget.accent,
                        onTap: () => setState(() => _tab = episodesTab),
                      ),
                    ],
                    const SizedBox(width: 28),
                    _SeriesTabButton(
                      label: l10n.trailersAndMore.toUpperCase(),
                      selected: _tab == trailersTab,
                      selectedColor: widget.accent,
                      onTap: () => setState(() => _tab = trailersTab),
                    ),
                    const SizedBox(width: 28),
                    _SeriesTabButton(
                      label: l10n.moreLikeThis.toUpperCase(),
                      selected: _tab == moreTab,
                      selectedColor: widget.accent,
                      onTap: () => setState(() => _tab = moreTab),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: Colors.white24),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (_tab == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 0, 36, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.overview.isNotEmpty)
                  Text(
                    widget.overview,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 16),
                _NetflixMetaRow(
                  label: l10n.starring,
                  value: detailPeopleNames(widget.people.take(4).toList()),
                ),
                const SizedBox(height: 10),
                _NetflixMetaRow(
                  label: l10n.createdBy,
                  value: detailPeopleByType(widget.people, 'Creator').isNotEmpty
                      ? detailPeopleByType(widget.people, 'Creator')
                      : detailPeopleByType(widget.people, 'Director'),
                ),
                const SizedBox(height: 10),
                _NetflixMetaRow(
                  label: l10n.genres,
                  value: localizeGenres(widget.genres, l10n).join(', '),
                ),
              ],
            ),
          )
        else if (_tab == episodesTab && _isSeries)
          _EpisodesTab(
            seasons: effectiveSeasons,
            season: season,
            episodes: seasonEpisodes,
            isLoading: allEpisodes.isEmpty &&
                ref
                    .watch(seriesEpisodesProvider(_seriesId))
                    .isLoading,
            l10n: l10n,
            prime: false,
            onSeasonChanged: (id) => setState(() => _seasonId = id),
            onEpisodeTap: (episode) => widget.onPlayEpisode?.call(episode),
          )
        else if (_tab == trailersTab)
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 8, 36, 36),
            child: _WideDetailButton(
              label: l10n.watchTrailer,
              icon: Icons.movie_outlined,
              onTap: widget.onTrailer,
            ),
          )
        else if (widget.relatedItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _RelatedSection(
              items: widget.relatedItems.take(10).toList(),
              serverUrl: widget.serverUrl,
              title: l10n.moreLikeThis,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 8, 36, 36),
            child: Text(
              l10n.noResults,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
      ],
    );
  }

  Widget _netflixTitle(
    AppLocalizations l10n,
    BaseItemDto display,
    bool compact,
  ) {
    final brand = widget.studios.isNotEmpty
        ? widget.studios.first.trim().toUpperCase()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (brand != null && brand.isNotEmpty)
          Text(
            brand,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _DetailTitle(
                title: display.name ?? '',
                logoUrl: widget.logoUrl,
                compact: compact,
              ),
            ),
            if ((display.communityRating ?? 0) > 0) ...[
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    display.communityRating!.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Botón de play cuadrado rojo estilo Netflix.
class _NetflixPlayButton extends StatelessWidget {
  const _NetflixPlayButton({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
      ),
    );
  }
}

/// Fila etiqueta/valor de la pestaña Overview de Netflix.
class _NetflixMetaRow extends StatelessWidget {
  const _NetflixMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}

/// Cuerpo Jellyfin clásico para pelis y series: título, nota/fecha/badges,
/// géneros, sinopsis con póster a la derecha, metadatos a la izquierda,
/// fila de botones y Cast & crew con fotos.
class _JellyfinDetailBody extends ConsumerStatefulWidget {
  const _JellyfinDetailBody({
    required this.item,
    required this.serverUrl,
    required this.overview,
    required this.genres,
    required this.people,
    required this.studios,
    required this.isFavorite,
    required this.relatedItems,
    required this.onPlay,
    required this.onTrailer,
    required this.onFavorite,
    this.series,
    this.onPlayEpisode,
    this.seerrMedia,
  });

  /// Item a mostrar (peli o serie). Si [series] no es null, modo serie.
  final BaseItemDto item;
  final BaseItemDto? series;
  final String? serverUrl;
  final String overview;
  final List<String> genres;
  final List<BaseItemPerson> people;
  final List<String> studios;
  final bool isFavorite;
  final List<BaseItemDto> relatedItems;
  final VoidCallback onPlay;
  final VoidCallback onTrailer;
  final VoidCallback onFavorite;
  final void Function(BaseItemDto episode)? onPlayEpisode;
  final SeerrMedia? seerrMedia;

  @override
  ConsumerState<_JellyfinDetailBody> createState() =>
      _JellyfinDetailBodyState();
}

class _JellyfinDetailBodyState extends ConsumerState<_JellyfinDetailBody> {
  bool? _played;
  String? _seasonId;

  bool get _isSeries => widget.series != null;
  BaseItemDto get _display => widget.series ?? widget.item;
  String get _seriesId => widget.series?.id ?? '';

  @override
  void initState() {
    super.initState();
    _played = _display.userData?.played;
  }

  Future<void> _toggleWatched() async {
    final itemId = _display.id;
    final userId = ref.read(currentUserIdProvider);
    final client = ref.read(jellyfinClientProvider);
    if (itemId == null || itemId.isEmpty || userId == null || client == null) {
      return;
    }
    final next = !(_played ?? false);
    setState(() => _played = next);
    try {
      if (next) {
        await client
            .getPlaystateApi()
            .markPlayedItem(itemId: itemId, userId: userId);
      } else {
        await client
            .getPlaystateApi()
            .markUnplayedItem(itemId: itemId, userId: userId);
      }
      ref.invalidate(itemDetailProvider(itemId));
    } catch (_) {
      if (mounted) setState(() => _played = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 760;
    final display = _display;
    final rating = display.communityRating;
    final premiere = display.premiereDate;
    final dateLabel = premiere != null
        ? DateFormat.yMMMd(l10n.localeName).format(premiere.toLocal())
        : (display.productionYear?.toString() ?? '');
    final badges = _formatBadges(display);
    final directorNames = detailPeopleByType(widget.people, 'Director');
    final totalTicks = display.runTimeTicks;
    final posTicks = display.userData?.playbackPositionTicks ?? 0;
    final watchedTicks = totalTicks != null && totalTicks > 0 && posTicks > 0
        ? totalTicks - posTicks
        : totalTicks;
    final endsLabel = watchedTicks != null && watchedTicks > 0
        ? DateFormat.Hm().format(
            DateTime.now().add(
              Duration(microseconds: watchedTicks ~/ 10),
            ),
          )
        : null;

    final posterWidth = compact ? 140.0 : 220.0;
    final posterUrl = widget.serverUrl == null
        ? null
        : itemImageUrl(widget.serverUrl!, display, maxWidth: 400);

    final seasons = _seriesId.isEmpty
        ? const <BaseItemDto>[]
        : ref.watch(seriesSeasonsProvider(_seriesId)).value ??
            const <BaseItemDto>[];
    final allEpisodes = _seriesId.isEmpty
        ? const <BaseItemDto>[]
        : ref.watch(seriesEpisodesProvider(_seriesId)).value ??
            const <BaseItemDto>[];
    final episodeSeasons =
        seasons.where((s) => s.indexNumber != 0).toList();
    final effectiveSeasons = episodeSeasons.isNotEmpty
        ? episodeSeasons
        : seasons;
    BaseItemDto? season;
    if (effectiveSeasons.isNotEmpty) {
      season =
          effectiveSeasons.where((s) => s.id == _seasonId).firstOrNull ??
          effectiveSeasons.first;
    }

    final watched = _played ?? display.userData?.played ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 24, 36, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                display.name ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 28 : 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (rating != null && rating > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  if (dateLabel.isNotEmpty)
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  for (final badge in badges) _MetaChip(text: badge),
                ],
              ),
              if (widget.genres.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  localizeGenres(widget.genres, l10n).join(' / '),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (directorNames.trim().isNotEmpty)
                          _JellyfinMetaRow(
                            label: l10n.directedBy.toUpperCase(),
                            value: directorNames,
                          ),
                        if (!_isSeries && totalTicks != null) ...[
                          const SizedBox(height: 10),
                          _JellyfinMetaRow(
                            label: l10n.runs.toUpperCase(),
                            value: _formatDuration(totalTicks),
                          ),
                        ],
                        if (!_isSeries && endsLabel != null) ...[
                          const SizedBox(height: 10),
                          _JellyfinMetaRow(
                            label: l10n.ends.toUpperCase(),
                            value: endsLabel,
                          ),
                        ],
                        if (widget.overview.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.overview,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: posterWidth,
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: posterUrl == null
                            ? const ColoredBox(color: Colors.white10)
                            : Image.network(
                                posterUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const ColoredBox(color: Colors.white10),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (widget.seerrMedia != null)
                    SizedBox(
                      width: 320,
                      child: _DetailActions(
                        item: display,
                        l10n: l10n,
                        isFavorite: widget.isFavorite,
                        downloading: false,
                        onTrailer: _noop,
                        onFavorite: widget.onFavorite,
                        onDownload: _noop,
                        seerrMedia: widget.seerrMedia,
                      ),
                    )
                  else
                    _JellyfinActionButton(
                      icon: Icons.play_arrow,
                      label: l10n.play,
                      onTap: () {
                        final target = _isSeries
                            ? _verTargetEpisode(allEpisodes)
                            : null;
                        if (target != null) {
                          widget.onPlayEpisode?.call(target);
                        } else {
                          widget.onPlay();
                        }
                      },
                    ),
                  _JellyfinActionButton(
                    icon: Icons.movie_outlined,
                    label: l10n.watchTrailer,
                    onTap: widget.onTrailer,
                  ),
                  if (widget.seerrMedia == null)
                    _JellyfinActionButton(
                      icon: watched ? Icons.check : Icons.check_outlined,
                      label: l10n.watched,
                      selected: watched,
                      onTap: _toggleWatched,
                    ),
                  _JellyfinActionButton(
                    icon: widget.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: l10n.favorite,
                    selected: widget.isFavorite,
                    onTap: widget.onFavorite,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (_isSeries)
          _EpisodesTab(
            seasons: effectiveSeasons,
            season: season,
            episodes: _episodesForSeason(allEpisodes, season),
            isLoading: allEpisodes.isEmpty &&
                ref.watch(seriesEpisodesProvider(_seriesId)).isLoading,
            l10n: l10n,
            prime: false,
            onSeasonChanged: (id) => setState(() => _seasonId = id),
            onEpisodeTap: (episode) => widget.onPlayEpisode?.call(episode),
          ),
        if (widget.people.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 4, 36, 12),
            child: Text(
              l10n.castAndCrew,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 208,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 36),
              itemCount: widget.people.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _CastCard(
                person: widget.people[i],
                serverUrl: widget.serverUrl,
              ),
            ),
          ),
          const SizedBox(height: 36),
        ] else
          const SizedBox(height: 36),
      ],
    );
  }
}

/// Fila etiqueta/valor de la columna izquierda Jellyfin.
class _JellyfinMetaRow extends StatelessWidget {
  const _JellyfinMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

/// Botón gris de la fila de acciones Jellyfin.
class _JellyfinActionButton extends StatelessWidget {
  const _JellyfinActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de reparto con foto (`/Persons`) y nombre; abre la ficha si hay id.
class _CastCard extends StatelessWidget {
  const _CastCard({required this.person, required this.serverUrl});

  final BaseItemPerson person;
  final String? serverUrl;

  @override
  Widget build(BuildContext context) {
    final name = (person.name ?? '').trim();
    final base = serverUrl;
    final photoUrl = base == null || name.isEmpty
        ? null
        : _personPhotoUrl(base, name);
    return GestureDetector(
      onTap: person.id == null || person.id!.isEmpty
          ? null
          : () => context.push(
              '/home/person/${person.id}',
              extra: BaseItemDto(
                id: person.id,
                name: name,
                type: BaseItemKind.person,
              ),
            ),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: photoUrl == null
                    ? _CastFallback(name: name)
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _CastFallback(name: name),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name.isEmpty ? '—' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            if ((person.role ?? '').trim().isNotEmpty)
              Text(
                person.role!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Inicial sobre fondo neutro cuando no hay foto.
class _CastFallback extends StatelessWidget {
  const _CastFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF2A2F36),
      child: Center(
        child: Text(
          name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white54, fontSize: 40),
        ),
      ),
    );
  }
}
