import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/home_scroll.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/hover_play_card.dart';
import '../../../../core/widgets/logo_image.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/image_url.dart';
import 'poster_fallback.dart';

/// Tarjeta de póster de un item (estilo Prime/Disney).
class PosterCard extends ConsumerStatefulWidget {
  const PosterCard({
    super.key,
    required this.item,
    required this.serverUrl,
    this.onTap,
    this.onImageTap,
    this.cardLogo,
    this.hoverExtension = false,
    this.useSeriesPoster = false,
    this.showBottomVignette = false,
    this.bottomVignetteHeight = 56,
    this.bottomVignetteOpacity = 0.72,
    this.showMetaOverlay = false,
    this.metaAlignment = RowMetaAlign.left,
    this.imageSource = RowImageSource.primary,
    this.showNewBadge = false,
    this.showStackLogo = false,
    this.logoPosition = RowLogoPosition.top,
    this.logoSize,
    this.hideTitle = false,
    this.hideYear = false,
    this.showHoverOverlay = true,
    this.cardBorderRadius,
    this.hoverScale,
    this.onHoverChanged,
    this.onPointerSignal,
    this.overlayBelowEntry,
  });

  final BaseItemDto item;
  final String? serverUrl;
  final VoidCallback? onTap;
  final VoidCallback? onImageTap;
  final String? cardLogo;
  final bool hoverExtension;
  final bool useSeriesPoster;
  final bool showBottomVignette;
  final double bottomVignetteHeight;
  final double bottomVignetteOpacity;
  final bool showMetaOverlay;
  final RowMetaAlign metaAlignment;
  final RowImageSource imageSource;
  final bool showNewBadge;
  final bool showStackLogo;
  final RowLogoPosition logoPosition;
  final double? logoSize;
  final bool hideTitle;
  final bool hideYear;
  final bool showHoverOverlay;
  final double? cardBorderRadius;
  final double? hoverScale;
  final ValueChanged<bool>? onHoverChanged;
  final ValueChanged<PointerSignalEvent>? onPointerSignal;
  final OverlayEntry? Function()? overlayBelowEntry;

  @override
  ConsumerState<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends ConsumerState<PosterCard> {
  bool _isHovered = false;

  void _setHovered(bool v) {
    if (_isHovered == v) return;
    setState(() => _isHovered = v);
  }

  @override
  Widget build(BuildContext context) {
    String? logoUrl;
    if (widget.showStackLogo && widget.serverUrl != null) {
      logoUrl = itemLogoUrl(widget.serverUrl!, widget.item);
    }
    String? url;
    if (widget.useSeriesPoster &&
        widget.item.type == BaseItemKind.episode &&
        widget.item.seriesId != null &&
        widget.item.seriesId!.isNotEmpty &&
        widget.serverUrl != null) {
      final tag = widget.item.seriesPrimaryImageTag;
      url = tag != null && tag.isNotEmpty
          ? '${widget.serverUrl}/Items/${widget.item.seriesId}/Images/Primary?maxWidth=1000&tag=$tag'
          : '${widget.serverUrl}/Items/${widget.item.seriesId}/Images/Primary?maxWidth=1000';
    } else if (widget.serverUrl != null) {
      switch (widget.imageSource) {
        case RowImageSource.thumb:
          url = itemThumbUrl(widget.serverUrl!, widget.item);
          break;
        case RowImageSource.backdrop:
          url = itemBackdropUrl(widget.serverUrl!, widget.item);
          break;
        case RowImageSource.primary:
          url = itemImageUrl(widget.serverUrl!, widget.item, maxWidth: 1000);
          break;
      }
    } else {
      url = null;
    }
    final progress = widget.item.userData?.playedPercentage;
    final skin = ref.watch(skinControllerProvider).value;
    final radius = widget.cardBorderRadius ?? skin?.cardBorderRadius ?? 10;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final logoSize = skin?.cardLogoSize ?? 18;
    final showExtension =
        widget.hoverExtension && (skin?.cardHoverExtension ?? false);
    final marqueeEnabled = skin?.titleMarqueeOnHover ?? false;
    final resume = (widget.item.userData?.playbackPositionTicks ?? 0) > 0;
    final artist =
        (widget.item.artists?.firstOrNull?.trim().isNotEmpty == true
                ? widget.item.artists!.first.trim()
                : (widget.item.albumArtist?.trim().isNotEmpty == true
                      ? widget.item.albumArtist!.trim()
                      : widget.item.albumArtists?.firstOrNull?.name?.trim() ??
                            ''))
            .trim();
    String cardTitle = widget.item.name ?? '';
    String? subtitle;
    if (artist.isNotEmpty) {
      subtitle = artist;
    } else if (widget.item.type == BaseItemKind.episode) {
      final season = widget.item.parentIndexNumber;
      final epNum = widget.item.indexNumber;
      final epName = widget.item.name?.trim() ?? '';
      final series = widget.item.seriesName?.trim() ?? '';
      String? se;
      if (season != null && epNum != null) {
        se = 'S$season:E$epNum';
      } else if (season != null) {
        se = 'S$season';
      } else if (epNum != null) {
        se = 'E$epNum';
      }
      if (se != null) {
        subtitle = epName.isNotEmpty ? '$se - $epName' : se;
        if (series.isNotEmpty) cardTitle = series;
      } else if (epName.isNotEmpty && series.isNotEmpty) {
        subtitle = epName;
        cardTitle = series;
      }
    } else if (widget.item.type == BaseItemKind.series) {
      final year = widget.item.productionYear;
      if (year != null) subtitle = '$year';
    } else if (widget.item.type == BaseItemKind.movie) {
      final year = widget.item.productionYear;
      if (year != null) subtitle = '$year';
    } else {
      final people = widget.item.people;
      if (people != null && people.isNotEmpty) {
        const priority = [
          PersonKind.author,
          PersonKind.writer,
          PersonKind.creator,
          PersonKind.illustrator,
          PersonKind.artist,
        ];
        for (final kind in priority) {
          final match = people.where((p) => p.type == kind).firstOrNull;
          if (match?.name?.trim().isNotEmpty == true) {
            subtitle = match!.name!.trim();
            break;
          }
        }
      }
      if (subtitle == null &&
          (widget.item.type == BaseItemKind.book ||
              widget.item.type == BaseItemKind.audioBook)) {
        final fallbackName = widget.item.people?.firstOrNull?.name?.trim();
        if (fallbackName != null && fallbackName.isNotEmpty) {
          subtitle = fallbackName;
        }
        if (subtitle == null) {
          final studio = widget.item.studios?.firstOrNull?.name?.trim();
          if (studio != null && studio.isNotEmpty) subtitle = studio;
        }
      }
      if (subtitle != null && subtitle.isEmpty) subtitle = null;
    }
    if (widget.hideTitle) {
      cardTitle = '';
    }
    if (widget.hideYear && subtitle != null) {
      final y = widget.item.productionYear?.toString();
      if (y != null && subtitle == y) subtitle = null;
    }
    // --- ContinueRow overlays: new badge & isNew ---
    bool isNew = false;
    if (widget.showNewBadge) {
      final now = DateTime.now();
      final created = widget.item.dateCreated;
      if (created != null && now.difference(created).inDays <= 90) {
        isNew = true;
      } else {
        final premiere = widget.item.premiereDate;
        if (premiere != null &&
            premiere.isBefore(now.add(const Duration(days: 30))) &&
            now.difference(premiere).inDays <= 365) {
          isNew = true;
        } else {
          final year = widget.item.productionYear;
          if (year != null && (year == now.year || year == now.year + 1)) {
            isNew = true;
          }
        }
      }
    }
    String? newBadgeLabel;
    if (isNew && widget.showNewBadge) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        switch (widget.item.type) {
          case BaseItemKind.movie:
            newBadgeLabel = l10n.newMovie;
            break;
          case BaseItemKind.series:
          case BaseItemKind.season:
          case BaseItemKind.episode:
            newBadgeLabel = l10n.newSeries;
            break;
          default:
            newBadgeLabel = null;
        }
      }
    }

    final fallback = PosterFallback(item: widget.item, color: fallbackColor);
    Widget imageWidget;
    if (url != null) {
      imageWidget = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        // 1000px (nativa habitual de pósters): las tarjetas llegan a 300px
        // lógicos (x2 con homeCardScale) y el hover las amplía.
        memCacheWidth: 1000,
        maxWidthDiskCache: 1000,
        fadeInDuration: const Duration(milliseconds: 150),
        useOldImageOnUrlChange: true,
        errorBuilder: (_, _, _) =>
            PosterFallback(item: widget.item, color: fallbackColor),
        placeholder: (_, _) => const SizedBox.shrink(),
      );
    } else {
      imageWidget = fallback;
    }

    final cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: HoverPlayRadius(
              radius: radius * 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  if (widget.showBottomVignette)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: widget.bottomVignetteHeight,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(
                                  alpha: widget.bottomVignetteOpacity.clamp(
                                    0.0,
                                    1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (newBadgeLabel != null)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          newBadgeLabel,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (widget.showStackLogo && logoUrl != null)
                    Positioned(
                      left: 8,
                      right: 8,
                      top: widget.logoPosition == RowLogoPosition.top
                          ? 8
                          : null,
                      bottom: widget.logoPosition == RowLogoPosition.bottom
                          ? (widget.showMetaOverlay ? 64 : 8)
                          : null,
                      child: widget.logoPosition == RowLogoPosition.center
                          ? Center(
                              child: Image.network(
                                logoUrl,
                                height: widget.logoSize ?? 36,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            )
                          : Image.network(
                              logoUrl,
                              height: widget.logoSize ?? 28,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (_, _, _) =>
                                  const SizedBox.shrink(),
                            ),
                    ),
                  if (widget.showMetaOverlay)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 92,
                      child: const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xCC000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.showMetaOverlay)
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 22,
                      child: Column(
                        crossAxisAlignment: switch (widget.metaAlignment) {
                          RowMetaAlign.left => CrossAxisAlignment.start,
                          RowMetaAlign.center => CrossAxisAlignment.center,
                          RowMetaAlign.right => CrossAxisAlignment.end,
                        },
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MetaLine(
                            ageRating: (widget.item.officialRating ?? '')
                                .trim(),
                            year: widget.item.productionYear,
                            genres: widget.item.genres ?? const <String>[],
                            hideYear: widget.hideYear,
                            fallback: subtitle,
                            align: widget.metaAlignment,
                          ),
                        ],
                      ),
                    ),
                  if (progress != null && progress > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: (progress / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: Colors.black38,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  if (!widget.showMetaOverlay &&
                      widget.cardLogo != null &&
                      widget.cardLogo!.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: LogoImage(
                        logo: widget.cardLogo!,
                        height: logoSize,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!showExtension && !widget.showMetaOverlay) ...[
          const SizedBox(height: 6),
          if (!widget.hideTitle)
            marqueeEnabled
                ? MarqueeText(
                    text: cardTitle,
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    isHovered: _isHovered,
                    enabled: true,
                  )
                : Text(
                    cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textPrimary, fontSize: 13),
                  ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: skin?.textSecondary ?? Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ],
    );

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: HoverPlayCard(
        title: cardTitle,
        subtitle: subtitle,
        onPlay: widget.onTap ?? () {},
        onImageTap: widget.onImageTap,
        showExtension: showExtension,
        showPlayOverlay: widget.showHoverOverlay,
        hoverScale: widget.hoverScale,
        onHoverChanged: (v) {
          _setHovered(v);
          widget.onHoverChanged?.call(v);
        },
        onPointerSignal: widget.onPointerSignal,
        overlayBelowEntry: widget.overlayBelowEntry,
        resume: resume,
        ageRating: widget.item.officialRating,
        year: widget.item.productionYear,
        runTimeTicks: widget.item.runTimeTicks,
        overview: widget.item.overview,
        child: cardContent,
      ),
    );
  }
}

/// Línea de meta inferior estilo Disney+ para el overlay sobre la imagen:
/// pastilla de edad + año • géneros (ej. "12+  2026 • Acción, Ciencia ficción").
/// Si no hay edad/año/géneros, muestra [fallback] (año/artista calculado).
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.ageRating,
    required this.year,
    required this.genres,
    required this.hideYear,
    required this.fallback,
    this.align = RowMetaAlign.left,
  });

  final String ageRating;
  final int? year;
  final List<String> genres;
  final bool hideYear;
  final String? fallback;
  final RowMetaAlign align;

  @override
  Widget build(BuildContext context) {
    final textAlign = switch (align) {
      RowMetaAlign.left => TextAlign.left,
      RowMetaAlign.center => TextAlign.center,
      RowMetaAlign.right => TextAlign.right,
    };
    final rowAlign = switch (align) {
      RowMetaAlign.left => MainAxisAlignment.start,
      RowMetaAlign.center => MainAxisAlignment.center,
      RowMetaAlign.right => MainAxisAlignment.end,
    };
    final parts = <String>[];
    if (!hideYear && year != null) parts.add('$year');
    final genreText = genres.take(3).join(', ');
    if (genreText.isNotEmpty) parts.add(genreText);
    if (parts.isEmpty && ageRating.isEmpty) {
      if (fallback == null || fallback!.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(
        fallback!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 9,
          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: rowAlign,
      children: [
        if (ageRating.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A42),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              ageRating,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (parts.isNotEmpty) const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            parts.join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: const TextStyle(
              color: Color.fromARGB(179, 247, 245, 245),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
            ),
          ),
        ),
      ],
    );
  }
}
