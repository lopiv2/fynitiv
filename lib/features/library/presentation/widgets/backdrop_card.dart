import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/hover_play_card.dart';
import '../../../../core/widgets/logo_image.dart';
import '../../application/image_url.dart';
import 'poster_fallback.dart';

/// Tarjeta horizontal (16:9) que usa la miniatura (Thumb) del item, para filas
/// tipo "Continuar viendo" cuando el skin prefiere imagen panorámica (Prime).
class BackdropCard extends ConsumerWidget {
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

  /// Logotipo superpuesto abajo a la derecha (asset o ruta de archivo).
  final String? cardLogo;

  /// Permite el panel de extensión al hacer hover (estilo Prime). Solo debe
  /// activarse en filas horizontales, no en grids.
  final bool hoverExtension;

  /// Para "A continuación": usa el póster de la serie en lugar del capítulo.
  final bool useSeriesPoster;

  /// Notifica el hover de la tarjeta (para reordenar el pintado en la fila).
  final ValueChanged<bool>? onHoverChanged;
  final ValueChanged<PointerSignalEvent>? onPointerSignal;
  final OverlayEntry? Function()? overlayBelowEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? thumbUrl = serverUrl != null ? itemThumbUrl(serverUrl!, item) : null;
    String? posterUrl = serverUrl != null ? itemImageUrl(serverUrl!, item) : null;
    // Para "A continuación": usar póster de la serie en lugar del capítulo
    if (useSeriesPoster &&
        item.type == BaseItemKind.episode &&
        item.seriesId != null &&
        item.seriesId!.isNotEmpty &&
        serverUrl != null) {
      final tag = item.seriesPrimaryImageTag;
      posterUrl = tag != null && tag.isNotEmpty
          ? '$serverUrl/Items/${item.seriesId}/Images/Primary?maxWidth=300&tag=$tag'
          : '$serverUrl/Items/${item.seriesId}/Images/Primary?maxWidth=300';
      thumbUrl = null;
    }
    final progress = item.userData?.playedPercentage;
    final skin = ref.watch(skinControllerProvider).value;
    final radius = skin?.cardBorderRadius ?? 10;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final logoSize = skin?.cardLogoSize ?? 18;
    final showExtension = hoverExtension && (skin?.cardHoverExtension ?? false);
    // Título y subtítulo para Novedades (cualquier skin).
    final artist = (item.artists?.firstOrNull?.trim().isNotEmpty == true
            ? item.artists!.first.trim()
            : (item.albumArtist?.trim().isNotEmpty == true
                ? item.albumArtist!.trim()
                : item.albumArtists?.firstOrNull?.name?.trim() ?? ''))
        .trim();
    String cardTitle = item.name ?? '';
    String? subtitle;
    if (artist.isNotEmpty) {
      subtitle = artist;
    } else if (item.type == BaseItemKind.episode) {
      final season = item.parentIndexNumber;
      final epNum = item.indexNumber;
      final epName = item.name?.trim() ?? '';
      final series = item.seriesName?.trim() ?? '';
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
    } else if (item.type == BaseItemKind.series) {
      final year = item.productionYear;
      if (year != null) subtitle = '$year';
    } else if (item.type == BaseItemKind.movie) {
      final year = item.productionYear;
      if (year != null) subtitle = '$year';
    } else {
      final people = item.people;
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
          (item.type == BaseItemKind.book || item.type == BaseItemKind.audioBook)) {
        final fallbackName = item.people?.firstOrNull?.name?.trim();
        if (fallbackName != null && fallbackName.isNotEmpty) {
          subtitle = fallbackName;
        }
        if (subtitle == null) {
          final studio = item.studios?.firstOrNull?.name?.trim();
          if (studio != null && studio.isNotEmpty) subtitle = studio;
        }
      }
      if (subtitle != null && subtitle.isEmpty) subtitle = null;
    }

    // Prefiere la miniatura (Thumb); si el item no tiene (o falla), usa el
    // póster en la misma proporción 16:9; si tampoco hay, muestra la letra.
    final fallback = PosterFallback(item: item, color: fallbackColor);
    final Widget image;
    if (thumbUrl != null) {
      image = Image.network(
        thumbUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => posterUrl != null
            ? Image.network(
                posterUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : fallback,
      );
    } else if (posterUrl != null) {
      image = Image.network(
        posterUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = fallback;
    }

    return HoverPlayCard(
      title: cardTitle,
      subtitle: subtitle,
      onPlay: onTap ?? () {},
      onImageTap: onImageTap,
      showExtension: showExtension,
      onHoverChanged: onHoverChanged,
      onPointerSignal: onPointerSignal,
      overlayBelowEntry: overlayBelowEntry,
      resume: (item.userData?.playbackPositionTicks ?? 0) > 0,
      ageRating: item.officialRating,
      year: item.productionYear,
      runTimeTicks: item.runTimeTicks,
      overview: item.overview,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Al hacer hover (hovercard visible) las esquinas pasan a ser
          // rectas; solo sin hover conservan el radio redondeado.
          HoverPlayRadius(
            radius: radius * 6,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  // Barra de progreso de reproducción (Continuar viendo),
                  // superpuesta en la parte inferior de la tarjeta.
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
                  // Logotipo superpuesto abajo a la derecha.
                  if (cardLogo != null && cardLogo!.isNotEmpty)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: LogoImage(logo: cardLogo!, height: logoSize),
                    ),
                ],
              ),
            ),
          ),
          // Con el panel de extensión (Prime) el título no se muestra bajo la
          // imagen: aparece en el propio panel al hacer hover, evitando que
          // se vea dos veces.
          if (!showExtension) ...[
            const SizedBox(height: 6),
            Text(
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
      ),
    );
  }
}
