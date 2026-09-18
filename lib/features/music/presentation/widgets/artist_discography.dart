import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/responsive_carousel.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../library/application/image_url.dart';

/// Filtro del carrusel de discografía (como la imagen de referencia).
enum DiscographyFilter { popular, albums, singlesEps }

/// Hasta 6 pistas se considera sencillo/EP (Jellyfin no expone tipo de álbum).
bool isSingleOrEp(BaseItemDto album) => (album.childCount ?? 999) <= 6;

int _playCount(BaseItemDto album) => album.userData?.playCount ?? 0;

int _year(BaseItemDto album) => album.productionYear ?? 0;

/// Ordena/filtra los álbumes según el chip activo. Populares = más
/// escuchados; el resto por año descendente.
List<BaseItemDto> filterDiscography(
  List<BaseItemDto> all,
  DiscographyFilter filter,
) {
  switch (filter) {
    case DiscographyFilter.popular:
      final sorted = List<BaseItemDto>.of(all);
      sorted.sort((a, b) {
        final plays = _playCount(b).compareTo(_playCount(a));
        if (plays != 0) return plays;
        return _year(b).compareTo(_year(a));
      });
      return sorted;
    case DiscographyFilter.albums:
      return all.where((a) => !isSingleOrEp(a)).toList();
    case DiscographyFilter.singlesEps:
      return all.where(isSingleOrEp).toList();
  }
}

/// Etiqueta de tipo para el subtítulo ("Álbum", "Sencillo", "EP").
String discographyTypeLabel(AppLocalizations l10n, BaseItemDto album) {
  final count = album.childCount;
  if (count != null && count <= 1) return l10n.discographySingle;
  if (count != null && count <= 6) return l10n.discographyEp;
  return l10n.searchTypeAlbum;
}

/// Tarjeta cuadrada de álbum (portada + título + "año · tipo"), como la
/// referencia. Tap = pantalla del álbum.
class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.album,
    required this.serverUrl,
    this.width = 170,
  });

  final BaseItemDto album;
  final String? serverUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final id = album.id ?? '';
    final coverUrl = serverUrl == null || id.isEmpty
        ? null
        : itemImageUrl(serverUrl!, album, maxWidth: 400);
    final year = album.productionYear;
    final subtitle = [
      if (year != null) '$year',
      discographyTypeLabel(l10n, album),
    ].join(' · ');
    return AppHover(
      effect: AppHoverEffect.scale,
      config: AppHoverConfig.scaleOnly(
        scale: 1.05,
        radius: BorderRadius.circular(12),
      ),
      onTap: id.isEmpty
          ? () {}
          : () => context.push('/music/album/$id', extra: album),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: coverUrl == null
                    ? Container(
                        color: const Color(0xFF2A2A2A),
                        child: const Icon(
                          Icons.album_rounded,
                          color: Colors.white70,
                          size: 48,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        maxWidthDiskCache: 400,
                        fadeInDuration: const Duration(milliseconds: 150),
                        useOldImageOnUrlChange: true,
                        errorBuilder: (_, _, _) => Container(
                          color: const Color(0xFF2A2A2A),
                          child: const Icon(
                            Icons.album_rounded,
                            color: Colors.white70,
                            size: 48,
                          ),
                        ),
                        placeholder: (_, _) =>
                            Container(color: const Color(0xFF2A2A2A)),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.name ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: kCardTitleFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: kCardSubtitleFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chips de filtro (pill seleccionada en blanco, resto oscuras).
class DiscographyChips extends StatelessWidget {
  const DiscographyChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DiscographyFilter selected;
  final ValueChanged<DiscographyFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _Chip(
          label: l10n.discographyPopular,
          selected: selected == DiscographyFilter.popular,
          onTap: () => onChanged(DiscographyFilter.popular),
        ),
        const SizedBox(width: 8),
        _Chip(
          label: l10n.albums,
          selected: selected == DiscographyFilter.albums,
          onTap: () => onChanged(DiscographyFilter.albums),
        ),
        const SizedBox(width: 8),
        _Chip(
          label: l10n.discographySinglesEps,
          selected: selected == DiscographyFilter.singlesEps,
          onTap: () => onChanged(DiscographyFilter.singlesEps),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppHover(
      effect: AppHoverEffect.highlight,
      config: const AppHoverConfig(
        highlightNormal: Color(0xFF2A2A2A),
        highlightHovered: Color(0xFF3A3A3A),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected ? Colors.white : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Sección "Discografía": título + Mostrar todos (estilo ver más de Amazon)
/// + chips + carrusel. Widget normal (no sliver) para usar en ListView o
/// dentro de SliverToBoxAdapter.
class DiscographySection extends ConsumerStatefulWidget {
  const DiscographySection({
    super.key,
    required this.albums,
    required this.isLoading,
    required this.serverUrl,
    required this.onRetry,
    required this.onShowAll,
  });

  /// Álbumes ya resueltos (vacío + sin carga = sección oculta).
  final List<BaseItemDto> albums;
  final bool isLoading;
  final String? serverUrl;
  final VoidCallback onRetry;
  final void Function(List<BaseItemDto> visible) onShowAll;

  @override
  ConsumerState<DiscographySection> createState() => _DiscographySectionState();
}

class _DiscographySectionState extends ConsumerState<DiscographySection> {
  DiscographyFilter _filter = DiscographyFilter.popular;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.isLoading && widget.albums.isEmpty) {
      return const SizedBox(height: 220, child: Center(child: AppLoader()));
    }
    if (widget.albums.isEmpty) return const SizedBox.shrink();
    final visible = filterDiscography(widget.albums, _filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${l10n.discography} (${widget.albums.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: kSectionTitleFontSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => widget.onShowAll(visible),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    l10n.showAll,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: DiscographyChips(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              l10n.noAlbums,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          )
        else
          ResponsiveCarousel(
            itemCount: visible.length,
            spacing: 16,
            extraHeight: 62,
            itemBuilder: (context, i, cardWidth) => AlbumCard(
              album: visible[i],
              serverUrl: widget.serverUrl,
              width: cardWidth,
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
