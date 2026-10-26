import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/detail_layout.dart';
import '../../../core/skin/skin.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/app_hover.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/detail_primitives.dart';
import '../../../core/widgets/hover_play_glyph.dart';
import '../../../core/widgets/included_badge.dart';
import '../../../core/widgets/library_page_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/genre_localizer.dart';
import '../../downloads/application/download_manager_provider.dart';
import '../../library/application/image_url.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/widgets/content_row.dart';
import '../../player/application/playback_provider.dart';
import '../application/ereader_providers.dart';
import '../data/book_format.dart';
import '../data/comic_info.dart';
import '../data/epub_metadata.dart';

/// Pantalla de informacion con composicion inspirada en Prime Video.
class BookDetailScreen extends ConsumerStatefulWidget {
  const BookDetailScreen({super.key, required this.item, this.skin});

  final BaseItemDto item;

  /// Skin forzado para el detalle. Si es `null` se usa el skin global.
  /// Permite previsualizar el detalle con otro skin sin cambiarlo.
  final Skin? skin;

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  final GlobalKey _detailsKey = GlobalKey();
  final GlobalKey _relatedKey = GlobalKey();
  BaseItemDto? _resolvedItem;
  bool _detailsSelected = false;
  bool? _isFavorite;

  BaseItemDto get item => _resolvedItem ?? widget.item;

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

  /// Cola Prime del detalle compuesta según `layout.sections` (fase 2).
  /// `synopsis`+`credits` van fusionados en `_AdditionalInformation`;
  /// `media`/`extras` no tienen bloque propio en libros porque la descarga y
  /// el fichero ya viven en la cabecera y en la sinopsis.
  List<Widget> _primeTail({
    required BuildContext context,
    required DetailLayout layout,
    required AppLocalizations l10n,
    required AsyncValue<List<BaseItemDto>> related,
    required String? serverUrl,
    required BaseItemDto item,
    required String overview,
    required List<String> genres,
    required bool compact,
    required double? imdbRating,
    required List<BaseItemPerson> people,
    required List<String> studios,
    required List<String> audioLanguages,
    required List<String> subtitleLanguages,
    required BookMetadata? epubMeta,
    required ComicMetadata? comicMeta,
    required bool metadataLoading,
    required String? fileName,
    required int? fileSize,
  }) {
    final tail = <Widget>[];
    var infoAdded = false;
    void addInfo() {
      if (infoAdded) return;
      infoAdded = true;
      if (!layout.showOverview && !layout.showCredits) return;
      tail.add(
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
              isBook: true,
              fileMetadata: epubMeta,
              comicMetadata: comicMeta,
              metadataLoading: metadataLoading,
              fileName: fileName,
              fileSize: fileSize,
            ),
          ),
        ),
      );
    }

    for (final section in layout.sections) {
      switch (section) {
        case DetailSection.header:
          break; // La cabecera ya va arriba, fuera de la cola.
        case DetailSection.tabs:
          if (layout.showTabs) {
            tail.addAll([
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
            ]);
          }
        case DetailSection.related:
          if (layout.showRelated && (related.value?.isNotEmpty ?? false)) {
            tail.add(
              Padding(
                key: _relatedKey,
                padding: const EdgeInsets.only(bottom: 24),
                child: _RelatedSection(
                  items: related.value!.take(10).toList(),
                  serverUrl: serverUrl,
                  onTap: (relatedItem) => context.push(
                    '/ereader/details/${relatedItem.id}',
                    extra: relatedItem,
                  ),
                ),
              ),
            );
          }
        case DetailSection.synopsis:
        case DetailSection.credits:
          addInfo();
        case DetailSection.media:
        case DetailSection.extras:
          break; // Sin bloque propio en libros.
      }
    }
    return tail;
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
    // Los libros normalmente no tienen backdrop; si no lo hay, usamos la
    // imagen primaria (portada) como cabecera.
    final hasBackdrop = item.backdropImageTags?.isNotEmpty ?? false;
    final imageUrl = serverUrl == null
        ? null
        : hasBackdrop
        ? itemBackdropUrl(serverUrl, item, maxWidth: 1800)
        : itemImageUrl(serverUrl, item, maxWidth: 1200);
    final logoUrl = serverUrl == null
        ? null
        : itemLogoUrl(serverUrl, item, maxWidth: 700);
    final overview = (item.overview ?? '').trim();
    final serverGenres = item.genres ?? const <String>[];
    final serverSeries = (item.seriesName ?? '').trim();
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
    // Jellyfin puede no traer los metadatos del libro/cómic; se leen del
    // fichero (OPF del EPUB o ComicInfo.xml del cómic) como respaldo solo si
    // al servidor le falta algo.
    final bookFormat = bookFormatOf(item);
    final isComic =
        bookFormat == 'cbz' ||
        bookFormat == 'cb7' ||
        bookFormat == 'cbt' ||
        bookFormat == 'cbr' ||
        bookFormat == 'rar';
    final needsFileMetadata =
        (bookFormat == 'epub' || isComic) &&
        (people.isEmpty ||
            studios.isEmpty ||
            _isbnOf(item).isEmpty ||
            serverSeries.isEmpty ||
            serverGenres.isEmpty);
    final epubMetadataAsync = needsFileMetadata && bookFormat == 'epub'
        ? ref.watch(epubMetadataProvider(widget.item.id ?? ''))
        : const AsyncValue<BookMetadata?>.data(null);
    final comicMetadataAsync = needsFileMetadata && isComic
        ? ref.watch(comicMetadataProvider(widget.item.id ?? ''))
        : const AsyncValue<ComicMetadata?>.data(null);
    final epubMeta = epubMetadataAsync.value;
    final comicMeta = comicMetadataAsync.value;
    final List<String> embeddedGenres;
    if (comicMeta?.genre?.trim().isNotEmpty ?? false) {
      embeddedGenres = [comicMeta!.genre!.trim()];
    } else if (epubMeta != null && epubMeta.subjects.isNotEmpty) {
      embeddedGenres = epubMeta.subjects.take(2).toList();
    } else {
      embeddedGenres = const [];
    }
    final genres = serverGenres.isNotEmpty
        ? serverGenres.take(2).toList()
        : embeddedGenres;
    final fileInfoAsync = ref.watch(bookFileInfoProvider(widget.item.id ?? ''));
    final fileInfo = fileInfoAsync.value ?? bookFileInfoOf(item);
    final fileName = fileInfo.fileName;
    final fileSize = fileInfo.sizeBytes;
    final related = ref.watch(similarItemsProvider(item));
    final isFavorite = _isFavorite ?? item.userData?.isFavorite ?? false;
    // Detalle modular (fase 2): el skin puede forzarse por parámetro para
    // previsualizar; el layout decide secciones y orden según (skin, tipo).
    final effectiveSkin =
        widget.skin ?? ref.watch(skinControllerProvider).value;
    final layout = detailLayoutFor(skin: effectiveSkin, kind: item.type);
    // Detalle de serie estilo Disney (solo ese skin; el resto mantiene Prime).
    final isDisneySeries =
        item.type == BaseItemKind.series && effectiveSkin?.id == 'disney_plus';
    // El detalle vive dentro del shell: reserva el alto de la barra superior
    // cuando el skin global la dibuja solapada (p. ej. Prime). El SafeArea ya
    // cubre el inset del sistema, así que se descuenta.
    final barTop =
        libraryPageTopPadding(context, effectiveSkin) -
        MediaQuery.of(context).padding.top;

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
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: barTop),
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
                        ..._primeTail(
                          context: context,
                          layout: layout,
                          l10n: l10n,
                          related: related,
                          serverUrl: serverUrl,
                          item: item,
                          overview: overview,
                          genres: genres,
                          compact: compact,
                          imdbRating: imdbRating,
                          people: people,
                          studios: studios,
                          audioLanguages: audioLanguages,
                          subtitleLanguages: subtitleLanguages,
                          epubMeta: epubMeta,
                          comicMeta: comicMeta,
                          metadataLoading:
                              epubMetadataAsync.isLoading ||
                              comicMetadataAsync.isLoading,
                          fileName: fileName,
                          fileSize: fileSize,
                        ),
                      ],
                    ],
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
    this.onTap,
  });

  final List<BaseItemDto> items;
  final String? serverUrl;
  final void Function(BaseItemDto item)? onTap;

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
      onItemTap: onTap != null
          ? onTap!
          : (item) => context.push('/player/${item.id}', extra: item),
      onItemImageTap: onTap != null
          ? onTap!
          : (item) => context.push('/home/details/${item.id}', extra: item),
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
    this.isBook = false,
    this.fileMetadata,
    this.comicMetadata,
    this.metadataLoading = false,
    this.fileName,
    this.fileSize,
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
  final bool isBook;
  final BookMetadata? fileMetadata;
  final ComicMetadata? comicMetadata;
  final bool metadataLoading;
  final String? fileName;
  final int? fileSize;

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
                DetailInfoValue(text: '${item.productionYear}')
              else if ((fileMetadata?.date?.trim().isNotEmpty ?? false))
                DetailInfoValue(text: fileMetadata!.date!.trim()),
              if (item.runTimeTicks != null)
                DetailInfoValue(text: _formatDuration(item.runTimeTicks!)),
              if (imdbRating != null)
                DetailInfoValue(
                  text: 'IMDb ${imdbRating!.toStringAsFixed(1)}/10',
                ),
              if (item.isHD == true) const DetailTag(text: 'HD'),
            ],
          ),
          if (fileName != null || fileSize != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 6,
              children: [
                if (fileName != null)
                  DetailCreditRow(
                    label: l10n.eReaderFileName,
                    value: fileName!,
                  ),
                if (fileSize != null)
                  DetailCreditRow(
                    label: l10n.eReaderFileSize,
                    value: _formatBytes(fileSize!),
                  ),
              ],
            ),
          ],
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
    final creditRows = <Widget>[];
    if (isBook) {
      // Serie: servidor, Calibre (OPF) o ComicInfo, con nº si lo hay.
      final serverSeries = (item.seriesName ?? '').trim();
      final embeddedSeries = (comicMetadata?.series?.trim().isNotEmpty ?? false)
          ? comicMetadata!.series!.trim()
          : (fileMetadata?.series?.trim() ?? '');
      final seriesNumber = (comicMetadata?.number?.trim().isNotEmpty ?? false)
          ? comicMetadata!.number!.trim()
          : (fileMetadata?.seriesIndex?.trim() ?? '');
      final series = serverSeries.isNotEmpty ? serverSeries : embeddedSeries;
      if (series.isNotEmpty) {
        creditRows.add(
          DetailCreditRow(
            label: l10n.eReaderSeries,
            value: seriesNumber.isNotEmpty ? '$series #$seriesNumber' : series,
          ),
        );
      }
      if (people.isNotEmpty) {
        for (final entry in _groupPeople(people)) {
          creditRows.add(
            DetailCreditRow(
              label: _bookRoleLabel(l10n, entry.key),
              value: entry.value.join(', '),
            ),
          );
        }
      } else {
        // Sin `people` del servidor: `artists`, autores del OPF o de
        // ComicInfo (`Writer` y dibujantes).
        final serverAuthors = (item.artists ?? const <String>[])
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList();
        final authors = serverAuthors.isNotEmpty
            ? serverAuthors
            : (fileMetadata != null && fileMetadata!.authors.isNotEmpty
                  ? fileMetadata!.authors
                  : (comicMetadata?.authors ?? const <String>[]));
        if (authors.isNotEmpty) {
          creditRows.add(
            DetailCreditRow(
              label: l10n.eReaderAuthor,
              value: authors.join(', '),
            ),
          );
        }
      }
      final publisher = studios.isNotEmpty
          ? studios.join(', ')
          : (fileMetadata?.publisher?.trim().isNotEmpty ?? false)
          ? fileMetadata!.publisher!.trim()
          : (comicMetadata?.publisher?.trim() ?? '');
      if (publisher.isNotEmpty) {
        creditRows.add(
          DetailCreditRow(label: l10n.eReaderPublisher, value: publisher),
        );
      }
      final serverIsbn = _isbnOf(item);
      final isbn = serverIsbn.isNotEmpty
          ? serverIsbn
          : (fileMetadata?.isbn ?? '');
      if (isbn.isNotEmpty) {
        creditRows.add(DetailCreditRow(label: l10n.eReaderIsbn, value: isbn));
      }
      final language = fileMetadata?.language?.trim() ?? '';
      if (language.isNotEmpty) {
        creditRows.add(DetailCreditRow(label: l10n.language, value: language));
      }
    } else {
      creditRows.addAll([
        DetailCreditRow(
          label: l10n.director,
          value: detailPeopleByType(people, 'Director'),
        ),
        DetailCreditRow(
          label: l10n.producers,
          value: detailPeopleByType(people, 'Producer'),
        ),
        DetailCreditRow(
          label: l10n.castLabel,
          value: detailPeopleNames(people),
        ),
        DetailCreditRow(label: l10n.studio, value: studios.join(', ')),
      ]);
    }
    final credits = DetailInfoCard(
      title: l10n.creatorsAndCast,
      child: isBook && metadataLoading && creditRows.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: AppLoader()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < creditRows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  creditRows[i],
                ],
              ],
            ),
    );
    // Los libros/cómics no tienen pistas de audio ni subtítulos: no se muestran.
    if (isBook) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [details, const SizedBox(height: 18), credits],
      );
    }
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

/// Agrupa los nombres por tipo de persona (Autor, Ilustrador, ...), en el
/// orden en que aparecen, para volcar todos los créditos del libro/cómic.
List<MapEntry<String, List<String>>> _groupPeople(List<BaseItemPerson> people) {
  final grouped = <String, List<String>>{};
  for (final person in people) {
    final name = (person.name ?? '').trim();
    if (name.isEmpty) continue;
    final type = person.type?.value ?? 'Unknown';
    grouped.putIfAbsent(type, () => <String>[]).add(name);
  }
  return grouped.entries.toList();
}

/// Etiqueta traducida del rol del libro/cómic; si no se conoce, el original.
String _bookRoleLabel(AppLocalizations l10n, String type) {
  return switch (type) {
    'Author' => l10n.eReaderAuthor,
    'Writer' => l10n.eReaderWriter,
    'Illustrator' => l10n.eReaderIllustrator,
    'Penciller' => l10n.eReaderPenciller,
    'Inker' => l10n.eReaderInker,
    'Colorist' => l10n.eReaderColorist,
    'Letterer' => l10n.eReaderLetterer,
    'CoverArtist' => l10n.eReaderCoverArtist,
    'Editor' => l10n.eReaderEditor,
    'Translator' => l10n.eReaderTranslator,
    'Artist' => l10n.eReaderArtist,
    _ => type,
  };
}

/// ISBN del libro/cómic (en `ProviderIds` o en `Tags` con prefijo "ISBN:").
String _isbnOf(BaseItemDto item) {
  final ids = item.providerIds;
  if (ids != null) {
    for (final entry in ids.entries) {
      if (entry.key.toLowerCase().contains('isbn') &&
          entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }
  }
  for (final tag in item.tags ?? const <String>[]) {
    if (tag.toLowerCase().startsWith('isbn') && tag.contains(':')) {
      return tag.substring(tag.indexOf(':') + 1).trim();
    }
  }
  return '';
}

/// Tamaño en bytes legible (B/KB/MB/GB/TB).
String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final decimals = unit == 0 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}

String detailDownloadFilename(String name) {
  final safeName = name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '${safeName.isEmpty ? 'video' : safeName}.mkv';
}

class _DetailActions extends StatelessWidget {
  const _DetailActions({
    required this.item,
    required this.l10n,
    required this.isFavorite,
    required this.downloading,
    required this.onFavorite,
    required this.onDownload,
  });

  final BaseItemDto item;
  final AppLocalizations l10n;
  final bool isFavorite;
  final bool downloading;
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
        // Botón de lectura (lector básico PDF/EPUB/CBZ).
        _WideDetailButton(
          label: l10n.eReaderRead,
          icon: Icons.menu_book_outlined,
          primary: true,
          onTap: () => context.push('/ereader/read/${item.id}', extra: item),
        ),
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
    required this.onFavorite,
    required this.onDownload,
  });

  final BaseItemDto item;
  final String overview;
  final List<String> genres;
  final AppLocalizations l10n;
  final bool isFavorite;
  final bool downloading;
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
            child: Center(child: HoverPlayGlyph()),
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
