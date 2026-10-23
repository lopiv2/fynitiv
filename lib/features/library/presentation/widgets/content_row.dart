import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/navigation/platform_mode.dart';
import '../../../../core/skin/home_scroll.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/skin/skin_scope.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../core/widgets/horizontal_scroll_behavior.dart';
import '../../../../core/widgets/scroll_title.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/genre_localizer.dart';
import '../../application/image_url.dart';
import '../../application/library_providers.dart';
import 'backdrop_card.dart';
import 'poster_card.dart';

/// Fila horizontal de tarjetas con un título (estilo Prime/Disney).
///
/// La rueda del ratón sigue desplazando la página (arriba/abajo); para
/// desplazar la fila en horizontal se muestran flechas al hacer hover y se
/// puede arrastrar con el ratón.
class ContentRow extends ConsumerStatefulWidget {
  const ContentRow({
    super.key,
    required this.title,
    required this.items,
    required this.serverUrl,
    this.height = 270,
    this.cardWidth = 150,
    this.itemSpacing,
    this.useBackdrop = false,
    this.useSeriesPoster = false,
    this.cardLogo,
    this.cardLogoFor,
    this.onItemTap,
    this.onItemImageTap,
    this.onSeeMore,
    this.showTitle = true,
    this.showBottomVignette = false,
    this.bottomVignetteHeight = 56,
    this.bottomVignetteOpacity = 0.72,
    this.showMetaOverlay = false,
    this.metaAlignment = RowMetaAlign.left,
    this.imageSource,
    this.showNewBadge = false,
    this.showStackLogo = false,
    this.logoPosition = RowLogoPosition.top,
    this.logoSize,
    this.hideTitle = false,
    this.hideYear = false,
    this.showHoverOverlay = true,
    this.showPlayIcon = true,
    this.highlightTitleOnHover = false,
    this.cardBorderRadius,
    this.hoverScale,
    this.spotlight = false,
    this.spotlightScale = 1.35,
    this.cardScale = 1.0,
    this.isNextPoster = false,
    this.hasNext = false,
    this.cornerBadge,
    this.cornerBadgeFor,
    this.excludePlaceholders = true,
    this.imageUrlFor,
    this.showHoverIncludedBadge = true,
    this.hoverActionLabel,
    this.cornerLogosFor,
  });

  final String title;
  final List<BaseItemDto> items;
  final String? serverUrl;

  /// Excluye stubs/placeholders (`.disc` de Radarr/Sonarr) de la fila. Se
  /// desactiva en "Próximamente", que es donde deben verse.
  final bool excludePlaceholders;

  /// URL de imagen explícita por item (contenido externo, p. ej. TMDB).
  final String? Function(BaseItemDto item)? imageUrlFor;

  /// Muestra "Se incluye con Jellyfin" en el panel de hover de las tarjetas.
  /// Se pone a `false` en filas de contenido externo (Seerr).
  final bool showHoverIncludedBadge;

  /// Texto del botón principal del hover de las tarjetas. `null` = por defecto
  /// ("Reanudar"/"Ver ahora"). Permite p. ej. "Solicitar" en Seerr.
  final String? hoverActionLabel;

  /// Logos de plataformas por item, para la esquina de la tarjeta.
  final List<String> Function(BaseItemDto item)? cornerLogosFor;

  /// Alto de la fila.
  final double height;

  /// Ancho de cada tarjeta (póster vertical).
  final double cardWidth;

  /// Espacio horizontal entre elementos. Si es `null` usa el del skin
  /// (`itemSpacing`, 12 por defecto; backdrop antes 20).
  final double? itemSpacing;

  /// Muestra tarjetas horizontales (backdrop 16:9) en lugar de pósteres.
  final bool useBackdrop;

  /// Para episodios (A continuación): usa el póster principal de la serie en
  /// lugar del capítulo, como pide el diseño.
  final bool useSeriesPoster;

  /// Logotipo superpuesto abajo a la derecha de cada tarjeta (asset o ruta).
  final String? cardLogo;

  /// Logo de tarjeta calculado por item, para contenido externo.
  final String? Function(BaseItemDto item)? cardLogoFor;

  /// Se invoca al pulsar una tarjeta de la fila.
  final void Function(BaseItemDto item)? onItemTap;

  /// Accion al pulsar la imagen expandida de una tarjeta.
  final void Function(BaseItemDto item)? onItemImageTap;

  /// Acción de "Ver más >" en el título de la fila. Si es null no se muestra.
  final VoidCallback? onSeeMore;

  /// Oculta el titulo cuando la fila ya tiene una cabecera propia.
  final bool showTitle;

  /// Muestra viñeta inferior en cada tarjeta (configurable por HomeScroll).
  final bool showBottomVignette;

  /// Altura de la viñeta inferior.
  final double bottomVignetteHeight;

  /// Opacidad máxima del degradado inferior.
  final double bottomVignetteOpacity;

  /// Si `true`, el meta (título) se muestra en stack abajo sobre la imagen.
  final bool showMetaOverlay;

  /// Alineación horizontal del meta overlay (izquierda/centro/derecha).
  final RowMetaAlign metaAlignment;

  /// Origen de imagen para esta fila (null = default poster/thumb).
  final RowImageSource? imageSource;

  /// Muestra el banner “Nueva película/serie”.
  final bool showNewBadge;

  /// Muestra el logo de la película/serie sobre la imagen.
  final bool showStackLogo;

  /// Posición del logo en el stack (top/center/bottom). Meta siempre abajo.
  final RowLogoPosition logoPosition;

  /// Altura en px del logo overlay. `null` = default de la tarjeta.
  final double? logoSize;

  /// Si `true` y este row es backdrop, el siguiente es poster → spacing doble (legacy).
  /// Ahora también backdrop→backdrop duplica (ver hasNext). Mantener por compat.
  final bool isNextPoster;

  /// Si `true`, hay siguiente fila visible. Si este es backdrop y hay siguiente, duplica rowSpacing.
  /// Cubre backdrop→poster y backdrop→backdrop (ambos x2), poster→poster x1.
  final bool hasNext;

  /// Oculta el título bajo la tarjeta.
  final bool hideTitle;

  /// Oculta el año bajo el título.
  final bool hideYear;

  /// Si es `false` no muestra la capa oscura (alpha) al hacer hover.
  /// Independiente de [showPlayIcon]: puede haber play sin oscurecer.
  final bool showHoverOverlay;

  /// Si es `false` no muestra el botón de play al hacer hover.
  final bool showPlayIcon;

  /// Si es `true`, el título bajo la tarjeta se remarca en intensidad
  /// (atenuado en reposo, plena intensidad + negrita en hover).
  final bool highlightTitleOnHover;

  /// Radio de borde de las tarjetas de esta fila (poster y backdrop).
  /// Si es `null` se usa el global del skin.
  final double? cardBorderRadius;

  /// Escala del hover/expansión de las tarjetas de esta fila.
  /// `null` => default (1.3 para HoverPlayCard, 1.04 para TV).
  final double? hoverScale;

  /// Efecto spotlight estilo Netflix TV: la tarjeta con hover/foco crece
  /// ([spotlightScale]) y despliega debajo meta + sinopsis. A demanda.
  final bool spotlight;

  /// Escala de la tarjeta destacada cuando [spotlight] es `true`.
  final double spotlightScale;

  /// Escala de las tarjetas de la fila (viene del scroll). Multiplica el
  /// ancho fijado por el skin y el alto de fila.
  final double cardScale;

  /// Badge opcional superpuesto en la esquina de cada tarjeta (ej. icono
  /// estacional). Se reenvía a [PosterCard]/[BackdropCard].
  final Widget? cornerBadge;

  /// Badge por item, para contenido externo (p. ej. estado de una petición de
  /// Seerr). Tiene prioridad sobre [cornerBadge].
  final Widget? Function(BaseItemDto item)? cornerBadgeFor;

  @override
  ConsumerState<ContentRow> createState() => _ContentRowState();
}

class _ContentRowState extends ConsumerState<ContentRow> {
  final ScrollController _controller = ScrollController();
  final LayerLink _rowLink = LayerLink();
  final GlobalKey _rowKey = GlobalKey();
  OverlayEntry? _arrowOverlay;
  Timer? _arrowHideTimer;
  ScrollPosition? _pageScrollPosition;

  /// Índice de la tarjeta con hover (para reordenar el pintado y que la
  /// tarjeta escalada se superponga a las vecinas). -1 = ninguna.
  int _hoveredIndex = -1;

  /// Índice de la tarjeta con foco TV (para el spotlight sin ratón).
  /// Separado del hover para no disparar overlays de flechas en TV.
  int _focusedIndex = -1;

  /// Alto extra reservado bajo la fila para la tira de info del spotlight
  /// (meta + sinopsis de 3 líneas).
  static const double _spotlightExtra = 100;

  /// Las flechas se muestran mientras el puntero está sobre la fila o sobre
  /// una hovercard expandida.
  bool _rowHovered = false;

  /// Estado del arrastre con el botón del medio del ratón (scroll horizontal).
  bool _middleDragging = false;
  double _lastDragX = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    // Precalienta la caché de imágenes con las primeras tarjetas para que
    // al hacer scroll lateral ya estén decodificadas.
    WidgetsBinding.instance.addPostFrameCallback((_) => _precacheFirst());
  }

  @override
  void didUpdateWidget(covariant ContentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items ||
        oldWidget.serverUrl != widget.serverUrl ||
        oldWidget.imageSource != widget.imageSource ||
        oldWidget.useBackdrop != widget.useBackdrop) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _precacheFirst());
    }
  }

  @override
  void dispose() {
    _arrowHideTimer?.cancel();
    _arrowOverlay?.remove();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (mounted) {
      setState(() {});
      _arrowOverlay?.markNeedsBuild();
    }
  }

  /// URL de imagen de un item con la misma lógica que las tarjetas, para
  /// precalentar la caché sin duplicar peticiones.
  String? _imageUrlFor(BaseItemDto item) {
    final explicit = widget.imageUrlFor?.call(item);
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final serverUrl = widget.serverUrl;
    if (serverUrl == null) return null;
    if (widget.useSeriesPoster && item.type == BaseItemKind.episode) {
      final seriesUrl = seriesPosterUrl(serverUrl, item);
      if (seriesUrl != null) return seriesUrl;
    }
    final source = widget.imageSource;
    if (widget.useBackdrop && source == null) {
      return singleCardImageUrl(serverUrl, item, CardImageKind.thumb);
    }
    return singleCardImageUrl(
      serverUrl,
      item,
      switch (source) {
        RowImageSource.thumb => CardImageKind.thumb,
        RowImageSource.backdrop => CardImageKind.backdrop,
        RowImageSource.primary || null => CardImageKind.primary,
      },
    );
  }

  /// Precalienta las 8 primeras tarjetas en la caché compartida de
  /// `cached_network_image` (disco + memoria). Se ignoran errores: si falla,
  /// la tarjeta pintará su fallback al hacerse visible.
  void _precacheFirst() {
    if (!mounted) return;
    final items = _items;
    if (widget.serverUrl == null || items.isEmpty) return;
    final ctx = context;
    final count = items.length < 8 ? items.length : 8;
    for (var i = 0; i < count; i++) {
      final url = _imageUrlFor(items[i]);
      if (url == null || url.isEmpty) continue;
      precacheImage(
        CachedNetworkImageProvider(
          url,
          maxWidth: widget.useBackdrop
              ? kLandscapeMaxWidth
              : kPosterMaxWidth,
        ),
        ctx,
        onError: (_, _) {},
      );
    }
  }

  /// Actualiza el índice de la tarjeta con foco TV (spotlight sin ratón).
  /// No toca flechas ni overlays: solo escala + tira de info.
  void _onCardFocus(int index, bool value) {
    if (!widget.spotlight) return;
    final next = value ? index : -1;
    if (_focusedIndex != next && mounted) {
      setState(() => _focusedIndex = next);
    }
  }

  /// Índice destacado por el spotlight (hover o foco TV), o -1 si ninguno.
  /// Con CardHoverExtension el panel Prime ya ocupa el foco: el spotlight
  /// se inhibe para no componer expansiones.
  int get _spotlightIndex {
    if (!widget.spotlight) return -1;
    final items = _items;
    final hovered = _hoveredIndex >= 0 && _hoveredIndex < items.length
        ? _hoveredIndex
        : -1;
    if (hovered != -1) return hovered;
    final focused = _focusedIndex >= 0 && _focusedIndex < items.length
        ? _focusedIndex
        : -1;
    return focused;
  }

  /// Tira de info del spotlight (foto): meta + sinopsis bajo la tarjeta.
  Widget _buildSpotlightInfo(BaseItemDto item, double width) {
    final l10n = AppLocalizations.of(context);
    final segments = <String>[];
    final genreList = item.genres ?? const <String>[];
    final genreText = l10n == null
        ? genreList.take(2).join(' • ')
        : localizeGenres(genreList.take(2), l10n).join(' • ');
    if (genreText.isNotEmpty) segments.add(genreText);
    if (!widget.hideYear && item.productionYear != null) {
      segments.add('${item.productionYear}');
    }
    if (item.type == BaseItemKind.series) {
      final seasons = item.childCount ?? 0;
      if (seasons > 0 && l10n != null) {
        segments.add(l10n.seriesSeasons(seasons));
      }
    }
    final age = (item.officialRating ?? '').trim();
    if (age.isNotEmpty) segments.add(age);
    final hasSubtitles = (item.mediaStreams ?? const <MediaStream>[]).any(
      (m) => m.type == MediaStreamType.subtitle,
    );
    final overview = (item.overview ?? '').trim();
    const metaStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (segments.isNotEmpty || hasSubtitles)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (segments.isNotEmpty)
                  Flexible(
                    child: Text(
                      segments.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: metaStyle,
                    ),
                  ),
                if (hasSubtitles) ...[
                  if (segments.isNotEmpty)
                    const Text(' • ', style: metaStyle),
                  const Icon(
                    Icons.closed_caption_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ],
            ),
          if (overview.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              overview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Ancho de cada tarjeta (el fijado por el skin, por [cardScale]).
  double get _cardWidth => widget.cardWidth * widget.cardScale;

  /// Altura de la fila, derivada dinámicamente del ancho de tarjeta para que
  /// las tarjetas midan lo fijado. Con backdrop (16:9) la altura es la de la
  /// imagen; sin backdrop se mantiene el alto del skin. El hueco entre filas
  /// lo controla [rowSpacing].
  double get _rowHeight {
    final skin =
        SkinScope.maybeOf(context) ?? ref.watch(skinControllerProvider).value;
    final showExtension = skin?.cardHoverExtension ?? false;
    final hasBelowText =
        !widget.hideTitle && !widget.showMetaOverlay && !showExtension;
    if (widget.useBackdrop) {
      final imageH = _cardWidth * 9 / 16;
      // Texto bajo la imagen (título 12 + subtítulo 10 + gaps 4+1 ≈ 27)
      // Antes era solo imageH y provocaba overflow de ~18px (Column:334)
      // Disney+ en Seguir viendo añade "Tiempo restante" (+14px)
      final extraForRemaining =
          (skin?.id == 'disney_plus' && hasBelowText) ? 14 : 0;
      return imageH + (hasBelowText ? 28 : 0) + extraForRemaining;
    }
    // Póster: widget.height ya incluye título/subtítulo, añadir extra para Disney+
    if (skin?.id == 'disney_plus' && hasBelowText) {
      return widget.height * widget.cardScale + 14;
    }
    return widget.height * widget.cardScale;
  }

  /// Separación entre tarjetas.
  double get _spacing {
    if (widget.itemSpacing != null) return widget.itemSpacing!;
    // Fallback al skin (12 por defecto) o valores legacy por tipo.
    final skinSpacing =
        (SkinScope.maybeOf(context) ??
                ref.watch(skinControllerProvider).value)
            ?.itemSpacing;
    if (skinSpacing != null) return skinSpacing;
    return widget.useBackdrop ? 20 : 12;
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final target = (_controller.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollPage(double direction, double viewportWidth) {
    _scrollBy(direction * viewportWidth * 0.8);
  }

  void _onPagePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    _pageScrollPosition?.pointerScroll(event.scrollDelta.dy);
  }

  /// Inicia el arrastre con el botón del medio del ratón (scroll horizontal).
  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kMiddleMouseButton != 0) {
      _middleDragging = true;
      _lastDragX = event.position.dx;
    }
  }

  /// Desplaza la fila horizontalmente mientras se arrastra con el botón medio.
  void _onPointerMove(PointerMoveEvent event) {
    if (!_middleDragging) return;
    final delta = event.position.dx - _lastDragX;
    _lastDragX = event.position.dx;
    if (delta != 0) _scrollBy(-delta);
  }

  /// Finaliza el arrastre con el botón del medio.
  void _onPointerUp(PointerUpEvent event) {
    _middleDragging = false;
  }

  /// Actualiza el índice de la tarjeta con hover.
  void _onCardHover(int index, bool value) {
    final next = value ? index : -1;
    if (_hoveredIndex != next || _rowHovered != value) {
      setState(() {
        _hoveredIndex = next;
        if (value) _rowHovered = true;
      });
    }
    if (value) {
      _showArrowOverlay();
      // La hovercard se inserta inmediatamente despues de esta notificacion
      // (con `below:` la entrada de flechas, que ya está por encima).
      // Refrescar al final del frame evita carreras durante la transicion
      // entre dos tarjetas con hover.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hoveredIndex == index) _showArrowOverlay();
      });
    }
  }

  void _showArrowOverlay() {
    _arrowHideTimer?.cancel();
    // Reutilizar la entrada existente: destruir y recrear el overlay en cada
    // hover genera churn en el árbol de semántica y el bridge de
    // accesibilidad de Windows rechaza los updates en cada pasada del ratón
    // (`Failed to update ui::AXTree ... will not be in the tree`, bug
    // upstream flutter/flutter#182444). El z-order sobre las hovercards se
    // mantiene porque esta entrada siempre se inserta antes que cualquier
    // hovercard (que se inserta con `below:` esta entrada).
    final existing = _arrowOverlay;
    if (existing != null) {
      existing.markNeedsBuild();
      return;
    }
    final entry = OverlayEntry(
      builder: (_) {
        final rowBox = _rowKey.currentContext?.findRenderObject() as RenderBox?;
        final width = rowBox?.size.width ?? MediaQuery.sizeOf(context).width;
        return CompositedTransformFollower(
          link: _rowLink,
          showWhenUnlinked: false,
          child: MouseRegion(
            hitTestBehavior: HitTestBehavior.deferToChild,
            onEnter: (_) => _arrowHideTimer?.cancel(),
            onExit: (_) => _scheduleArrowOverlayHide(),
            child: SizedBox(
              width: width,
              height: _rowHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: 6,
                    top: (_rowHeight - 44) / 2,
                    child: _scrollArrow(
                      icon: Icons.chevron_left,
                      enabled:
                          _controller.hasClients &&
                          _controller.offset >
                              _controller.position.minScrollExtent,
                      onPressed: () =>
                          _scrollPage(-1, MediaQuery.sizeOf(context).width),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: (_rowHeight - 44) / 2,
                    child: _scrollArrow(
                      icon: Icons.chevron_right,
                      enabled:
                          _controller.hasClients &&
                          _controller.offset <
                              _controller.position.maxScrollExtent,
                      onPressed: () =>
                          _scrollPage(1, MediaQuery.sizeOf(context).width),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _arrowOverlay = entry;
    Overlay.of(context).insert(entry);
  }

  /// Devuelve la entrada de flechas para que la hovercard se inserte como
  /// referencia `below` (las flechas quedan por encima sin recrear nada).
  OverlayEntry? _prepareArrowOverlayForHover() {
    _showArrowOverlay();
    return _arrowOverlay;
  }

  void _scheduleArrowOverlayHide() {
    _arrowHideTimer?.cancel();
    _arrowHideTimer = Timer(const Duration(milliseconds: 180), () {
      if (_hoveredIndex == -1) {
        _arrowOverlay?.remove();
        _arrowOverlay = null;
        if (mounted) setState(() => _rowHovered = false);
      }
    });
  }

  Widget _scrollArrow({
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _rowHovered && enabled ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_rowHovered || !enabled,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 28),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          ),
        ),
      ),
    );
  }

  /// Items de la fila, excluyendo stubs/placeholders salvo que se pida lo
  /// contrario (fila "Próximamente").
  List<BaseItemDto> get _items =>
      widget.excludePlaceholders ? excludePlaceholders(widget.items) : widget.items;

  /// Construye las tarjetas en un único [Stack] horizontal. El orden de pintado
  /// se reordena para que la tarjeta con hover/foco sea la última (y quede por
  /// encima de las vecinas al escalar con el [ScaleButton]).
  List<Widget> _buildStackedItems() {
    final items = _items;
    final spotIndex = _spotlightIndex;
    final indices = List<int>.generate(items.length, (i) => i);
    indices.sort((a, b) {
      if (a == _hoveredIndex || a == spotIndex) return 1;
      if (b == _hoveredIndex || b == spotIndex) return -1;
      return a.compareTo(b);
    });
    final step = _cardWidth + _spacing;
    final isTv =
        (ref.watch(platformModeProvider).value ?? PlatformMode.mobile) ==
        PlatformMode.tv;
    // Con spotlight la fila escala (la tarjeta no debe componer su 1.3).
    final cardHoverScale = widget.spotlight ? 1.0 : widget.hoverScale;
    return [
      for (final i in indices)
        Positioned(
          key: ValueKey('content_card_$i'),
          left: i * step,
          top: 0,
          width: _cardWidth,
          child: _wrapForTv(
            isTv: isTv,
            index: i,
            onTap: widget.onItemTap == null
                ? null
                : () => widget.onItemTap!(items[i]),
            child: AnimatedScale(
              // Sin spotlight el wrapper es identidad (sin cambio visual).
              scale: widget.spotlight && i == spotIndex
                  ? widget.spotlightScale
                  : 1.0,
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: widget.useBackdrop
                  ? BackdropCard(
                    item: items[i],
                    serverUrl: widget.serverUrl,
                    cardLogo:
                        widget.cardLogoFor?.call(items[i]) ?? widget.cardLogo,
                    hoverExtension: true,
                    useSeriesPoster: widget.useSeriesPoster,
                    showBottomVignette: widget.showBottomVignette,
                    bottomVignetteHeight: widget.bottomVignetteHeight,
                    bottomVignetteOpacity: widget.bottomVignetteOpacity,
                    showMetaOverlay: widget.showMetaOverlay,
                    metaAlignment: widget.metaAlignment,
                    imageSource: widget.imageSource ?? RowImageSource.thumb,
                    imageUrl: widget.imageUrlFor?.call(items[i]),
                    showHoverIncludedBadge: widget.showHoverIncludedBadge,
                    hoverActionLabel: widget.hoverActionLabel,
                    cornerLogos: widget.cornerLogosFor?.call(items[i]),
                    showNewBadge: widget.showNewBadge,
                    showStackLogo: widget.showStackLogo,
                    logoPosition: widget.logoPosition,
                    logoSize: widget.logoSize,
                    hideTitle: widget.hideTitle,
                    hideYear: widget.hideYear,
                    showHoverOverlay: widget.showHoverOverlay,
                    showPlayIcon: widget.showPlayIcon,
                    highlightTitleOnHover: widget.highlightTitleOnHover,
                    cardBorderRadius: widget.cardBorderRadius,
                    hoverScale: cardHoverScale,
                    onTap: widget.onItemTap == null
                        ? null
                        : () => widget.onItemTap!(items[i]),
                    onImageTap: widget.onItemImageTap == null
                        ? null
                        : () => widget.onItemImageTap!(items[i]),
                    onHoverChanged: (v) => _onCardHover(i, v),
                    onPointerSignal: _onPagePointerSignal,
                    overlayBelowEntry: _prepareArrowOverlayForHover,
                    cornerBadge:
                        widget.cornerBadgeFor?.call(items[i]) ??
                        widget.cornerBadge,
                  )
                : PosterCard(
                    item: items[i],
                    serverUrl: widget.serverUrl,
                    cardLogo:
                        widget.cardLogoFor?.call(items[i]) ?? widget.cardLogo,
                    hoverExtension: true,
                    useSeriesPoster: widget.useSeriesPoster,
                    showBottomVignette: widget.showBottomVignette,
                    bottomVignetteHeight: widget.bottomVignetteHeight,
                    bottomVignetteOpacity: widget.bottomVignetteOpacity,
                    showMetaOverlay: widget.showMetaOverlay,
                    metaAlignment: widget.metaAlignment,
                    imageSource: widget.imageSource ?? RowImageSource.primary,
                    imageUrl: widget.imageUrlFor?.call(items[i]),
                    showHoverIncludedBadge: widget.showHoverIncludedBadge,
                    hoverActionLabel: widget.hoverActionLabel,
                    cornerLogos: widget.cornerLogosFor?.call(items[i]),
                    showNewBadge: widget.showNewBadge,
                    showStackLogo: widget.showStackLogo,
                    logoPosition: widget.logoPosition,
                    logoSize: widget.logoSize,
                    hideTitle: widget.hideTitle,
                    hideYear: widget.hideYear,
                    showHoverOverlay: widget.showHoverOverlay,
                    showPlayIcon: widget.showPlayIcon,
                    highlightTitleOnHover: widget.highlightTitleOnHover,
                    cardBorderRadius: widget.cardBorderRadius,
                    hoverScale: cardHoverScale,
                    onTap: widget.onItemTap == null
                        ? null
                        : () => widget.onItemTap!(items[i]),
                    onImageTap: widget.onItemImageTap == null
                        ? null
                        : () => widget.onItemImageTap!(items[i]),
                    onHoverChanged: (v) => _onCardHover(i, v),
                    onPointerSignal: _onPagePointerSignal,
                    overlayBelowEntry: _prepareArrowOverlayForHover,
                    cornerBadge:
                        widget.cornerBadgeFor?.call(items[i]) ??
                        widget.cornerBadge,
                  ),
            ),
          ),
        ),
    ];
  }

  Widget _wrapForTv({
    required bool isTv,
    required int index,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    if (onTap == null) return child;
    return AppHover(
      effect: AppHoverEffect.scale,
      config: AppHoverConfig.scaleOnly(
        scale: widget.hoverScale ?? 1.04,
        radius: BorderRadius.circular(12),
      ),
      onTap: onTap,
      onFocusChange: (v) => _onCardFocus(index, v),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();

    // Separación vertical entre filas, definida por el skin.
    // Si este es backdrop y hay siguiente fila → doble spacing (backdrop→poster y backdrop→backdrop).
    // Si es poster→poster o poster→backdrop → simple. Última fila sin siguiente → simple.
    final baseRowSpacing =
        (SkinScope.maybeOf(context) ??
                ref.watch(skinControllerProvider).value)
            ?.rowSpacing ??
        24;
    final hasNextEffective = widget.hasNext || widget.isNextPoster;
    final rowSpacing = (widget.useBackdrop && hasNextEffective)
        ? baseRowSpacing * 2
        : baseRowSpacing;
    _pageScrollPosition = Scrollable.maybeOf(context)?.position;

    // Spotlight (foto): al destacar una tarjeta la fila crece para la tira
    // de info (meta + sinopsis) bajo ella. Animado en ambas direcciones.
    final spotIndex = _spotlightIndex;
    final spotActive = widget.spotlight && spotIndex != -1;
    final displayH = _rowHeight + (spotActive ? _spotlightExtra : 0);
    final step = _cardWidth + _spacing;
    final spotW = _cardWidth * widget.spotlightScale;
    final spotLeft = spotActive
        ? (spotIndex * step - (spotW - _cardWidth) / 2)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ScrollTitle(
              title: widget.title,
              onSeeMore: widget.onSeeMore,
            ),
          ),
          const SizedBox(height: 12),
        ],
        FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: displayH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Listener de bajo nivel: captura el arrastre con el botón del
                // medio del ratón para desplazar la fila en horizontal. La rueda
                // (PointerScrollEvent) no se intercepta, así que sigue haciendo
                // scroll vertical de página.
                MouseRegion(
                  onEnter: (_) {
                    setState(() => _rowHovered = true);
                    _showArrowOverlay();
                  },
                  onExit: (_) => _scheduleArrowOverlayHide(),
                  child: CompositedTransformTarget(
                    key: _rowKey,
                    link: _rowLink,
                    child: Listener(
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      behavior: HitTestBehavior.translucent,
                      child: ScrollConfiguration(
                        behavior: const HorizontalScrollBehavior(),
                        child: SingleChildScrollView(
                          controller: _controller,
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SizedBox(
                            width:
                                _items.length * _cardWidth +
                                (_items.length - 1) * _spacing,
                            height: displayH,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ..._buildStackedItems(),
                                // Tira de info del spotlight: sigue el scroll
                                // horizontal al vivir dentro del contenido.
                                if (spotActive)
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    left: spotLeft,
                                    top: _rowHeight + 10,
                                    width: spotW,
                                    child: _buildSpotlightInfo(
                                      _items[spotIndex],
                                      spotW,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: rowSpacing),
      ],
    );
  }
}
