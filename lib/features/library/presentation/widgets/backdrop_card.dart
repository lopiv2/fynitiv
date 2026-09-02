import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/card_badge_resolver.dart';
import '../../../../core/widgets/hover_play_card.dart';
import '../../../../core/widgets/logo_image.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../../../core/widgets/prime_card_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/image_url.dart';
import 'poster_fallback.dart';

/// Tarjeta horizontal (16:9) que usa la miniatura (Thumb) del item, para filas
/// tipo "Continuar viendo" cuando el skin prefiere imagen panorámica (Prime).
class BackdropCard extends ConsumerStatefulWidget {
  const BackdropCard({
    super.key,
    required this.item,
    required this.serverUrl,
    this.onTap,
    this.onImageTap,
    this.cardLogo,
    this.hoverExtension = false,
    this.useSeriesPoster = false,
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
  final ValueChanged<bool>? onHoverChanged;
  final ValueChanged<PointerSignalEvent>? onPointerSignal;
  final OverlayEntry? Function()? overlayBelowEntry;

  @override
  ConsumerState<BackdropCard> createState() => _BackdropCardState();
}

class _BackdropCardState extends ConsumerState<BackdropCard> {
  bool _isHovered = false;

  void _setHovered(bool v) {
    if (_isHovered == v) return;
    setState(() => _isHovered = v);
  }

  Widget _cachedImage(String url, Widget Function() onError) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 640,
      maxWidthDiskCache: 640,
      fadeInDuration: const Duration(milliseconds: 150),
      useOldImageOnUrlChange: true,
      errorBuilder: (_, _, _) => onError(),
      placeholder: (_, _) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Backdrop 16:9: siempre miniatura (Thumb) primero; Backdrop es fallback de Thumb.
    String? displayUrl;
    String? fallbackPrimaryUrl;
    String? fallbackBackdropUrl;
    if (widget.useSeriesPoster &&
        widget.item.type == BaseItemKind.episode &&
        widget.item.seriesId != null &&
        widget.item.seriesId!.isNotEmpty &&
        widget.serverUrl != null) {
      final tag = widget.item.seriesPrimaryImageTag;
      displayUrl = tag != null && tag.isNotEmpty
          ? '${widget.serverUrl}/Items/${widget.item.seriesId}/Images/Primary?maxWidth=300&tag=$tag'
          : '${widget.serverUrl}/Items/${widget.item.seriesId}/Images/Primary?maxWidth=300';
    } else {
      displayUrl = widget.serverUrl != null ? itemThumbUrl(widget.serverUrl!, widget.item) : null;
      fallbackBackdropUrl = widget.serverUrl != null ? itemBackdropUrl(widget.serverUrl!, widget.item) : null;
      fallbackPrimaryUrl = widget.serverUrl != null ? itemImageUrl(widget.serverUrl!, widget.item) : null;
    }
    final progress = widget.item.userData?.playedPercentage;
    final skin = ref.watch(skinControllerProvider).value;
    final radius = skin?.cardBorderRadius ?? 10;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final logoSize = skin?.cardLogoSize ?? 18;
    final showExtension = widget.hoverExtension && (skin?.cardHoverExtension ?? false);
    final marqueeEnabled = skin?.titleMarqueeOnHover ?? false;
    final l10n = AppLocalizations.of(context);
    final rawLabel = l10n != null ? resolvePrimeBadge(widget.item, l10n) : null;
    final badgeLabel = (skin?.showCardBadge ?? false) ? rawLabel : null;
    final artist = (widget.item.artists?.firstOrNull?.trim().isNotEmpty == true
            ? widget.item.artists!.first.trim()
            : (widget.item.albumArtist?.trim().isNotEmpty == true
                ? widget.item.albumArtist!.trim()
                : widget.item.albumArtists?.firstOrNull?.name?.trim() ?? ''))
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
          (widget.item.type == BaseItemKind.book || widget.item.type == BaseItemKind.audioBook)) {
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

    final fallback = PosterFallback(item: widget.item, color: fallbackColor);
    final Widget image;
    if (displayUrl != null) {
      image = _cachedImage(
        displayUrl,
        () => fallbackBackdropUrl != null
            ? _cachedImage(
                fallbackBackdropUrl,
                () => fallbackPrimaryUrl != null
                    ? _cachedImage(fallbackPrimaryUrl, () => fallback)
                    : fallback,
              )
            : fallbackPrimaryUrl != null
                ? _cachedImage(fallbackPrimaryUrl, () => fallback)
                : fallback,
      );
    } else {
      if (fallbackBackdropUrl != null) {
        image = _cachedImage(
          fallbackBackdropUrl,
          () => fallbackPrimaryUrl != null
              ? _cachedImage(fallbackPrimaryUrl, () => fallback)
              : fallback,
        );
      } else if (fallbackPrimaryUrl != null) {
        image = _cachedImage(fallbackPrimaryUrl, () => fallback);
      } else {
        image = fallback;
      }
    }

    final cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HoverPlayRadius(
          radius: radius * 6,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                if (badgeLabel != null)
                  Positioned(
                    top: 0,
                    right: -2,
                    child: PrimeCardBadge(label: badgeLabel),
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
                if (widget.cardLogo != null && widget.cardLogo!.isNotEmpty)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: LogoImage(logo: widget.cardLogo!, height: logoSize),
                  ),
              ],
            ),
          ),
        ),
        if (!showExtension) ...[
          const SizedBox(height: 6),
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
        onHoverChanged: (v) {
          _setHovered(v);
          widget.onHoverChanged?.call(v);
        },
        onPointerSignal: widget.onPointerSignal,
        overlayBelowEntry: widget.overlayBelowEntry,
        resume: (widget.item.userData?.playbackPositionTicks ?? 0) > 0,
        ageRating: widget.item.officialRating,
        year: widget.item.productionYear,
        runTimeTicks: widget.item.runTimeTicks,
        overview: widget.item.overview,
        child: cardContent,
      ),
    );
  }
}
