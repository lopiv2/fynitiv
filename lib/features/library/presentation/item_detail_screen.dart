import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/ad_free_easter_egg_dialog.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/included_badge.dart';
import '../../../l10n/app_localizations.dart';
import '../../player/application/playback_provider.dart';
import '../application/image_url.dart';
import '../application/library_providers.dart';
import 'widgets/content_row.dart';

/// Pantalla de informacion con composicion inspirada en Prime Video.
class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key, required this.item});

  final BaseItemDto item;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  final GlobalKey _detailsKey = GlobalKey();
  final GlobalKey _relatedKey = GlobalKey();
  BaseItemDto? _resolvedItem;
  bool _detailsSelected = false;
  bool? _isFavorite;
  bool _downloading = false;
  bool _trailerLoading = false;
  Player? _trailerPlayer;
  VideoController? _trailerVideoController;
  String? _trailerError;

  BaseItemDto get item => _resolvedItem ?? widget.item;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.item.userData?.isFavorite;
  }

  @override
  void dispose() {
    _trailerPlayer?.dispose();
    super.dispose();
  }

  Future<void> _openTrailer() async {
    if (_trailerLoading || _trailerPlayer != null) return;
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
    final player = _trailerPlayer;
    _trailerPlayer = null;
    _trailerVideoController = null;
    _trailerLoading = false;
    _trailerError = null;
    if (mounted) setState(() {});
    await player?.dispose();
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
    if (_downloading || itemId == null || itemId.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _downloading = true);
    try {
      final session = await ref.read(playbackSessionProvider(itemId).future);
      if (session == null) throw StateError('No playback session');
      final directory = await getDownloadsDirectory();
      if (directory == null) throw StateError('No downloads directory');
      final filename = _downloadFilename(item.name ?? 'video');
      final path = '${directory.path}${Platform.pathSeparator}$filename';
      await Dio().download(session.streamUrl, path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.gamesDownloaded}: $path')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.gamesNoFile)));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
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

  List<String> _streamLabels(MediaStreamType type) {
    return (item.mediaStreams ?? const <MediaStream>[])
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
    final l10n = AppLocalizations.of(context)!;
    final serverUrl = ref.watch(authServerUrlProvider);
    final imageUrl = serverUrl == null
        ? null
        : itemBackdropUrl(serverUrl, item, maxWidth: 1800);
    final logoUrl = serverUrl == null
        ? null
        : itemLogoUrl(serverUrl, item, maxWidth: 700);
    final overview = (item.overview ?? '').trim();
    final genres = item.genres?.take(2).toList() ?? const <String>[];
    final imdbRating = item.communityRating;
    final people = item.people ?? const <BaseItemPerson>[];
    final studios =
        item.studios
            ?.map((studio) => studio.name ?? '')
            .where((name) => name.isNotEmpty)
            .toList() ??
        const <String>[];
    final audioLanguages = _streamLabels(MediaStreamType.audio);
    final subtitleLanguages = _streamLabels(MediaStreamType.subtitle);
    final related = ref.watch(similarItemsProvider(item));
    final isFavorite = _isFavorite ?? item.userData?.isFavorite ?? false;
    final wideScreen = MediaQuery.sizeOf(context).width >= 760;
    // Detalle de serie estilo Disney (solo ese skin; el resto mantiene Prime).
    // Más adelante se hará modular por pantalla como HomeScroll.
    final skin = ref.watch(skinControllerProvider).value;
    final isDisneySeries =
        item.type == BaseItemKind.series && skin?.id == 'disney_plus';

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
                        padding: const EdgeInsets.fromLTRB(28, 8, 24, 0),
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
                      if (isDisneySeries)
                        _DisneySeriesBody(
                          item: item,
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
                        SizedBox(
                          height: compact ? 100 : constraints.maxHeight * 0.27,
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
                                  downloading: _downloading,
                                  onTrailer: _openTrailer,
                                  onFavorite: _toggleFavorite,
                                  onDownload: _downloadItem,
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
                                        downloading: _downloading,
                                        onTrailer: _openTrailer,
                                        onFavorite: _toggleFavorite,
                                        onDownload: _downloadItem,
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
  const _RelatedSection({required this.items, required this.serverUrl});

  final List<BaseItemDto> items;
  final String? serverUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ContentRow(
      title: l10n.related,
      items: items,
      serverUrl: serverUrl,
      cardWidth: 320,
      height: 215,
      useBackdrop: true,
      showTitle: false,
      onItemTap: (item) => context.push('/player/${item.id}', extra: item),
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
    final details = _InfoCard(
      title: item.name ?? '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final genre in genres) _LinkText(text: genre),
              if (item.officialRating != null)
                _InfoValue(text: item.officialRating!),
              if (item.productionYear != null)
                _InfoValue(text: '${item.productionYear}'),
              if (item.runTimeTicks != null)
                _InfoValue(text: _formatDuration(item.runTimeTicks!)),
              if (imdbRating != null)
                _InfoValue(text: 'IMDb ${imdbRating!.toStringAsFixed(1)}/10'),
              if (item.isHD == true) const _Tag(text: 'HD'),
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
    final l10n = AppLocalizations.of(context)!;
    final credits = _InfoCard(
      title: l10n.creatorsAndCast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CreditRow(
            label: l10n.director,
            value: _peopleByType(people, 'Director'),
          ),
          const SizedBox(height: 14),
          _CreditRow(
            label: l10n.producers,
            value: _peopleByType(people, 'Producer'),
          ),
          const SizedBox(height: 14),
          _CreditRow(label: l10n.castLabel, value: _peopleNames(people)),
          const SizedBox(height: 14),
          _CreditRow(label: l10n.studio, value: studios.join(', ')),
        ],
      ),
    );
    final audio = _InfoCard(
      title: l10n.audioLanguages,
      child: _LanguageInfo(
        icon: Icons.audiotrack_outlined,
        text: audioLanguages.isEmpty
            ? l10n.noAudioTracks
            : audioLanguages.join(', '),
      ),
    );
    final subtitles = _InfoCard(
      title: l10n.subtitlesLabel,
      child: _LanguageInfo(
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xE611151B),
        border: Border.all(color: Colors.white38),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 16),
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageInfo extends StatelessWidget {
  const _LanguageInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 10),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 16,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppLocalizations.of(context)!.more,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            decoration: TextDecoration.underline,
          ),
        ),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        decoration: TextDecoration.underline,
      ),
    );
  }
}

class _InfoValue extends StatelessWidget {
  const _InfoValue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF454A51),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

String _peopleByType(List<BaseItemPerson> people, String type) {
  return people
      .where((person) => person.type?.name.toLowerCase() == type.toLowerCase())
      .map((person) => person.name ?? '')
      .where((name) => name.isNotEmpty)
      .join(', ');
}

String _peopleNames(List<BaseItemPerson> people) {
  return people
      .map((person) => person.name ?? '')
      .where((name) => name.isNotEmpty)
      .take(20)
      .join(', ');
}

String _downloadFilename(String name) {
  final safeName = name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '${safeName.isEmpty ? 'video' : safeName}.mkv';
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

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.item,
    required this.l10n,
    required this.isFavorite,
    required this.downloading,
    required this.onTrailer,
    required this.onFavorite,
    required this.onDownload,
  });

  final BaseItemDto item;
  final AppLocalizations l10n;
  final bool isFavorite;
  final bool downloading;
  final VoidCallback onTrailer;
  final VoidCallback onFavorite;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _DetailActionButton(
              icon: Icons.play_circle_outline,
              onTap: onTrailer,
            ),
            _DetailActionButton(
              icon: isFavorite ? Icons.favorite : Icons.add,
              onTap: onFavorite,
            ),
            _DetailActionButton(
              icon: Icons.download_outlined,
              onTap: downloading ? () {} : onDownload,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _WideDetailButton(
          label: l10n.watchNow,
          icon: Icons.play_arrow,
          primary: true,
          onTap: () => context.push('/player/${item.id}', extra: item),
        ),
        const SizedBox(height: 14),
        _WideDetailButton(
          label: l10n.adFreeEasterEggButton,
          onTap: () => showAdFreeEasterEggDialog(context),
        ),
        const SizedBox(height: 14),
        _WideDetailButton(label: l10n.moreOptionsToEnjoy, onTap: _noop),
        const SizedBox(height: 14),
        IncludedBadge(label: l10n.includedWithJellyfin, fontSize: 14),
        const SizedBox(height: 8),
        Text(
          l10n.termsApply,
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      ],
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
            for (final genre in genres) _DetailMeta(text: genre),
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
  const _DetailActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
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

class _WideDetailButton extends StatelessWidget {
  const _WideDetailButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? Colors.white : const Color(0xFF363B43),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: primary ? Colors.black : Colors.white,
                size: 28,
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: TextStyle(
                color: primary ? Colors.black : Colors.white,
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

  @override
  ConsumerState<_DisneySeriesBody> createState() => _DisneySeriesBodyState();
}

class _DisneySeriesBodyState extends ConsumerState<_DisneySeriesBody> {
  /// 0 = Episodios, 1 = Sugerencias, 2 = Extras, 3 = Detalles.
  int _tab = 0;
  String? _seasonId;

  BaseItemDto get _series => widget.item;

  void _playEpisode(BaseItemDto episode) {
    final id = episode.id;
    if (id == null || id.isEmpty || !mounted) return;
    context.push('/player/$id', extra: episode);
  }

  /// VER: episodio a medias > siguiente sin ver > primer episodio.
  BaseItemDto? _verTarget(List<BaseItemDto> episodes) {
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

  List<BaseItemDto> _episodesFor(List<BaseItemDto> all, BaseItemDto? season) {
    if (season == null) return all;
    final byId = all
        .where((e) => season.id != null && e.seasonId == season.id)
        .toList();
    if (byId.isNotEmpty) return byId;
    return all.where((e) => e.parentIndexNumber == season.indexNumber).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final compact = MediaQuery.sizeOf(context).width < 760;
    final seriesId = _series.id ?? '';
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

    final rating = (_series.officialRating ?? '').trim();
    final year = _series.productionYear;
    final metaParts = <String>[
      if (year != null) '$year',
      if (seasons.isNotEmpty) l10n.seriesSeasons(seasons.length),
      ...widget.genres.take(2),
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
              if (_series.isHD == true) const _Tag(text: 'HD'),
              if (widget.subtitleLanguages.isNotEmpty) const _Tag(text: 'CC'),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Row(
            children: [
              _VerButton(
                label: verIsResume ? l10n.resume : l10n.watchNow,
                onTap: verTarget == null
                    ? _noop
                    : () => _playEpisode(verTarget),
              ),
              const SizedBox(width: 12),
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
                    label: l10n.episodes.toUpperCase(),
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 32),
                  _SeriesTabButton(
                    label: l10n.suggestions.toUpperCase(),
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const SizedBox(width: 32),
                  _SeriesTabButton(
                    label: l10n.extras.toUpperCase(),
                    selected: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                  const SizedBox(width: 32),
                  _SeriesTabButton(
                    label: l10n.details.toUpperCase(),
                    selected: _tab == 3,
                    onTap: () => setState(() => _tab = 3),
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
          _EpisodesTab(
            seasons: effectiveSeasons,
            season: season,
            episodes: seasonEpisodes,
            isLoading:
                allEpisodes.isEmpty &&
                ref.watch(seriesEpisodesProvider(seriesId)).isLoading,
            l10n: l10n,
            onSeasonChanged: (id) => setState(() => _seasonId = id),
            onEpisodeTap: _playEpisode,
          )
        else if (_tab == 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _RelatedSection(
              items: widget.related.take(10).toList(),
              serverUrl: widget.serverUrl,
            ),
          )
        else if (_tab == 2)
          _ExtrasTab(
            episodes: allEpisodes
                .where((e) => e.parentIndexNumber == 0)
                .toList(),
            l10n: l10n,
            onEpisodeTap: _playEpisode,
          )
        else
          Padding(
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: selected
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white, width: 3),
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
    required this.onSeasonChanged,
    required this.onEpisodeTap,
  });

  final List<BaseItemDto> seasons;
  final BaseItemDto? season;
  final List<BaseItemDto> episodes;
  final bool isLoading;
  final AppLocalizations l10n;
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
            _EpisodeWrap(episodes: episodes, onEpisodeTap: onEpisodeTap),
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
    required this.onEpisodeTap,
  });

  final List<BaseItemDto> episodes;
  final AppLocalizations l10n;
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
      child: _EpisodeWrap(episodes: episodes, onEpisodeTap: onEpisodeTap),
    );
  }
}

/// Parrilla de capítulos sin alto fijo: cada tarjeta mide lo que su contenido
/// y las filas quedan pegadas (runSpacing 0).
class _EpisodeWrap extends StatelessWidget {
  const _EpisodeWrap({required this.episodes, required this.onEpisodeTap});

  final List<BaseItemDto> episodes;
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
              onTap: () => onEpisodeTap(episodes[i]),
            ),
          ),
      ],
    );
  }
}

/// Tarjeta de capítulo: miniatura 16:9, "N. Título", sinopsis y duración.
class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.episode,
    required this.index,
    required this.onTap,
  });

  final BaseItemDto episode;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overview = (episode.overview ?? '').trim();
    final ticks = episode.runTimeTicks;
    final progress = episode.userData?.playedPercentage;
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
            child: _EpisodeHoverThumb(episode: episode, progress: progress),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$index. ${episode.name ?? ''}'.trim().toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (overview.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            overview,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
        if (ticks != null) ...[
          const SizedBox(height: 4),
          Text(
            '(${_formatDuration(ticks)})',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Contenido hover de la miniatura: imagen + progreso y, al hover/foco,
/// oscurecido con icono de play (lee [AppHoverScope] del AppHover padre).
class _EpisodeHoverThumb extends StatelessWidget {
  const _EpisodeHoverThumb({required this.episode, required this.progress});

  final BaseItemDto episode;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final hovered = AppHoverScope.of(context)?.hovered ?? false;
    final watched = progress ?? 0;
    return Stack(
      fit: StackFit.expand,
      children: [
        _ThumbImage(episode: episode),
        if (watched > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              value: (watched / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.black38,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
            ),
          ),
        if (hovered)
          const ColoredBox(
            color: Color(0x59000000),
            child: Center(child: _HoverPlayIcon()),
          ),
      ],
    );
  }
}

/// Círculo blanco con play central, como el overlay de las filas.
class _HoverPlayIcon extends StatelessWidget {
  const _HoverPlayIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 32,
      ),
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
