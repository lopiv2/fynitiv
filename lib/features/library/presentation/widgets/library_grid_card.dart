import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/image_url.dart';
import '../../application/library_providers.dart';

/// Fondo panorámico de la tarjeta Disney: backdrop, thumb o primary.
String? _libraryBgUrl(String serverUrl, BaseItemDto view) {
  if ((view.backdropImageTags ?? const []).isNotEmpty) {
    return itemBackdropUrl(serverUrl, view, maxWidth: 800);
  }
  bool hasTag(Map<String, String>? tags, String type) {
    if (tags == null) return false;
    return tags.keys.any((k) => k.toLowerCase() == type);
  }

  final tags = view.imageTags;
  if (hasTag(tags, ImageType.thumb.name)) {
    return itemThumbUrl(serverUrl, view, maxWidth: 800);
  }
  if (hasTag(tags, ImageType.primary.name)) {
    return itemImageUrl(serverUrl, view, maxWidth: 600);
  }
  return null;
}

/// Icono según el tipo de colección (mismo criterio que la sidebar).
IconData libraryViewIcon(BaseItemDto view) {
  switch (view.collectionType) {
    case CollectionType.movies:
      return Icons.movie_outlined;
    case CollectionType.tvshows:
      return Icons.tv_outlined;
    case CollectionType.music:
      return Icons.music_note_outlined;
    case CollectionType.books:
      return Icons.menu_book_outlined;
    case CollectionType.livetv:
      return Icons.live_tv_outlined;
    case CollectionType.playlists:
      return Icons.queue_music_outlined;
    case CollectionType.boxsets:
      return Icons.collections_bookmark_outlined;
    default:
      return Icons.video_library_outlined;
  }
}

/// Subtítulo con el conteo de la biblioteca (títulos, series, horas de
/// grabación…), mismo criterio que el diálogo de bibliotecas de escritorio.
String libraryCountSubtitle(
  WidgetRef ref,
  BaseItemDto view,
  AppLocalizations l10n,
) {
  final count = ref.watch(libraryItemCountProvider(view.id ?? '')).value ?? 0;
  final isGrab = (view.name ?? '').toLowerCase().contains('grabac');
  final hours = isGrab
      ? ref.watch(libraryDvrHoursProvider(view.id ?? '')).value
      : null;
  if (isGrab && hours != null && hours > 0) {
    return l10n.libraryCountHours(hours);
  }
  switch (view.collectionType) {
    case CollectionType.movies:
      return l10n.libraryCountTitles(count);
    case CollectionType.tvshows:
      return l10n.libraryCountSeries(count);
    case CollectionType.music:
      return l10n.libraryCountSongs(count);
    case CollectionType.livetv:
      return l10n.libraryCountChannels(count);
    case CollectionType.books:
      return l10n.libraryCountFiles(count);
    case CollectionType.playlists:
      return l10n.libraryCountLists(count);
    case CollectionType.boxsets:
      return l10n.libraryCountCollections(count);
    default:
      final name = (view.name ?? '').toLowerCase();
      if (name.contains('grabac') && hours != null) {
        return l10n.libraryCountHours(hours);
      }
      if (name.contains('colecc')) {
        return l10n.libraryCountCollections(count);
      }
      return l10n.libraryCountItems(count);
  }
}

/// Tarjeta genérica de biblioteca (grid): icono, nombre y conteo.
///
/// Usa el Hover universal ([AppHover]) con glow LED azul, que además gestiona
/// el foco para TV/mando (Enter / Select / botón A) y el `ensureVisible`.
class LibraryGridCard extends ConsumerWidget {
  const LibraryGridCard({
    super.key,
    required this.view,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.subtitle,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
  });

  final BaseItemDto view;
  final VoidCallback onTap;

  /// Marca la biblioteca activa (muestra check en lugar del chevron).
  final bool selected;

  /// Icono a mostrar. Por defecto [libraryViewIcon] según la colección.
  final IconData? icon;

  /// Subtítulo a mostrar. Por defecto se calcula el conteo con providers.
  final String? subtitle;

  /// Nodo de foco externo (ej. modal TV con foco inicial gestionado).
  final FocusNode? focusNode;

  /// Pide foco automáticamente al montarse.
  final bool autofocus;

  /// Notifica cambios de foco.
  final ValueChanged<bool>? onFocusChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveSubtitle = subtitle ?? libraryCountSubtitle(ref, view, l10n);
    final effectiveIcon = icon ?? libraryViewIcon(view);
    // Solo Disney: siempre cuerpo Disney (con imagen o con degradado).
    final skin = ref.watch(skinControllerProvider).value;
    final serverUrl = ref.watch(authServerUrlProvider);
    final isDisney = skin?.id == 'disney_plus';
    final bgUrl = (isDisney && serverUrl != null)
        ? _libraryBgUrl(serverUrl, view)
        : null;
    return AppHover(
      onTap: onTap,
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: onFocusChange,
      effect: AppHoverEffect.scaleHighlightOutline,
      config: AppHoverConfig.scaleHighlightOutline(
        radius: BorderRadius.circular(16),
        highlightNormal: const Color(0xFF2A2E3A).withValues(alpha: 0.85),
        highlightHovered: const Color(0xFF1E2633),
        outlineColor: Colors.white.withValues(alpha: 0.06),
        outlineHoveredColor: Colors.white,
        outlineHoveredWidth: 1.8,
      ),
      child: isDisney
          ? _DisneyBody(
              view: view,
              bgUrl: bgUrl,
              subtitle: effectiveSubtitle,
              selected: selected,
            )
          : _ClassicBody(
              view: view,
              icon: effectiveIcon,
              subtitle: effectiveSubtitle,
              selected: selected,
            ),
    );
  }
}

/// Layout clásico: icono arriba, nombre y conteo abajo a la izquierda.
class _ClassicBody extends StatelessWidget {
  const _ClassicBody({
    required this.view,
    required this.icon,
    required this.subtitle,
    required this.selected,
  });

  final BaseItemDto view;
  final IconData icon;
  final String subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF3E4352),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(icon, color: Colors.white70, size: 18),
              ),
              const Spacer(),
              Builder(
                builder: (innerContext) {
                  final active =
                      AppHoverScope.of(innerContext)?.hovered ?? false;
                  if (selected) {
                    return const Icon(
                      Icons.check,
                      color: Color(0xFF3B82F6),
                      size: 16,
                    );
                  }
                  if (active) return const SizedBox.shrink();
                  return const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF9CA3AF),
                    size: 16,
                  );
                },
              ),
            ],
          ),
          const Spacer(),
          Text(
            view.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Variante Disney: imagen de fondo a todo bleed o, si la biblioteca no
/// trae imagen, degradado de la paleta curada (estable por biblioteca).
/// Nombre centrado grande con el conteo debajo en ambos casos.
class _DisneyBody extends StatelessWidget {
  const _DisneyBody({
    required this.view,
    required this.bgUrl,
    required this.subtitle,
    required this.selected,
  });

  final BaseItemDto view;
  final String? bgUrl;
  final String subtitle;
  final bool selected;

  static const _titleShadows = [
    Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 2)),
    Shadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
  ];

  /// Paleta curada estilo Disney para bibliotecas sin imagen.
  static const _fallbackGradients = [
    [Color(0xFF0B1030), Color(0xFF1A2568)],
    [Color(0xFF062A3A), Color(0xFF00A0D1)],
    [Color(0xFF2B0B30), Color(0xFF7B2FF7)],
    [Color(0xFF3A0B1E), Color(0xFFE0407A)],
    [Color(0xFF0B2E1F), Color(0xFF00B389)],
    [Color(0xFF1F0B2E), Color(0xFF4A00E0)],
  ];

  /// Degradado estable por biblioteca (sin parpadeos en rebuilds).
  List<Color> get _fallbackPair {
    final key = view.id ?? view.name ?? '';
    final idx = key.hashCode.abs() % _fallbackGradients.length;
    return _fallbackGradients[idx];
  }

  Widget _fallbackBackground() {
    final pair = _fallbackPair;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pair[0], pair[1]],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = bgUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (bg != null)
          CachedNetworkImage(
            imageUrl: bg,
            fit: BoxFit.cover,
            memCacheWidth: 800,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => const SizedBox.shrink(),
            errorBuilder: (_, _, _) => _fallbackBackground(),
          )
        else
          _fallbackBackground(),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.05),
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.88),
              ],
              stops: const [0.35, 0.7, 1.0],
            ),
          ),
        ),
        if (selected)
          const Positioned(
            top: 10,
            right: 10,
            child: Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 20),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Solo si no viene arte con título de Jellyfin (fondo degradado).
              if (bg == null) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    8.0,
                    8.0,
                    8.0,
                    MediaQuery.of(context).size.height * 0.05,
                  ),
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) =>
                        const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.white70, Color(0xFF9CA3AF)],
                        ).createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        ),
                    child: Text(
                      view.name ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        //shadows: _titleShadows,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  shadows: _titleShadows,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
