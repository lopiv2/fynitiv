import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/hover_invert.dart';
import '../../../../core/widgets/scale_button.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/image_url.dart';

/// Carrusel de banners horizontales genérico (estilo Disney+/Prime).
///
/// Reutilizable por cualquier skin mediante sus parámetros: borde, altura,
/// alineación de puntos, tamaño del logo, etc.
class FeaturedSlider extends StatefulWidget {
  const FeaturedSlider({
    super.key,
    required this.title,
    required this.items,
    required this.serverUrl,
    this.maxItems = 10,
    this.autoPlayInterval = const Duration(seconds: 6),
    this.showBorder = false,
    this.borderColor = Colors.white,
    this.borderWidth = 1.5,
    this.heightFactor = 0.38,
    this.minHeight = 280,
    this.maxHeight = 440,
    this.dotAlignment = SliderDotAlignment.right,
    this.logoWidthFactor = kDefaultLogoWidthFactor,
    this.showArrows = false,
    this.showIncludedBadge = false,
    this.showJellyfinLogo = false,
    this.hoverReveal = false,
    this.showActions = false,
    this.transition = SliderTransition.slide,
    this.arrowsOnHover = false,
    this.showTitle = true,
    this.showAgeRating = false,
    this.contentScale = 1.0,
  });

  /// Tamaño por defecto del logo (fracción del ancho del banner).
  static const double kDefaultLogoWidthFactor = 0.32;

  final String title;
  final List<BaseItemDto> items;
  final String? serverUrl;

  /// Máximo número de banners mostrados.
  final int maxItems;

  /// Intervalo de avance automático. `null` desactiva el auto-play.
  final Duration? autoPlayInterval;

  /// Muestra un borde alrededor de cada banner.
  final bool showBorder;
  final Color borderColor;
  final double borderWidth;

  /// Factor de altura relativo al ancho disponible.
  final double heightFactor;
  final double minHeight;
  final double maxHeight;

  /// Dónde colocar los puntos de navegación.
  final SliderDotAlignment dotAlignment;

  /// Anchura máxima del logo del título relativa al ancho del banner.
  final double logoWidthFactor;

  /// Muestra flechas a los lados para ir al anterior/siguiente banner
  /// (con ciclo: del primero vuelve al último y viceversa).
  final bool showArrows;

  /// Muestra la insignia "Se incluye con Jellyfin" bajo el logo.
  final bool showIncludedBadge;

  /// Muestra el logo de Jellyfin en pequeño sobre el logo del título.
  final bool showJellyfinLogo;

  /// En escritorio, al pasar el ratón el logo se desliza hacia arriba y se
  /// revela la descripción del elemento.
  final bool hoverReveal;

  /// Muestra los botones de acción (Ver ahora, +, i) bajo el logo.
  final bool showActions;

  /// Tipo de transición entre banners (deslizamiento o desvanecimiento).
  final SliderTransition transition;

  /// Muestra las flechas solo al pasar el ratón sobre el slider.
  final bool arrowsOnHover;

  /// Muestra el título sobre el slider.
  final bool showTitle;

  /// Muestra la edad recomendada del contenido en un recuadro de color,
  /// ocultando el año y el tipo de contenido.
  final bool showAgeRating;

  /// Escala del conjunto (logo, botones, insignia y descripción) del banner.
  final double contentScale;

  @override
  State<FeaturedSlider> createState() => _FeaturedSliderState();
}

class _FeaturedSliderState extends State<FeaturedSlider> {
  late final PageController _controller;
  Timer? _timer;
  int _currentPage = 0;
  bool _sliderHovered = false;

  List<BaseItemDto> get _banners => widget.items.take(widget.maxItems).toList();

  bool get _useFade => widget.transition == SliderTransition.fade;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant FeaturedSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlayInterval != widget.autoPlayInterval) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    final interval = widget.autoPlayInterval;
    if (interval == null || _banners.length < 2) return;
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _banners.length;
      if (_useFade) {
        setState(() => _currentPage = next);
      } else {
        if (!_controller.hasClients) return;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _goToPage(int index) {
    if (index == _currentPage) return;
    if (_useFade) {
      setState(() => _currentPage = index);
    } else {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Va al banner anterior (del primero salta al último).
  void _goToPrev() {
    if (_banners.length < 2) return;
    final target = (_currentPage - 1 + _banners.length) % _banners.length;
    _goToPage(target);
  }

  /// Va al banner siguiente (del último salta al primero).
  void _goToNext() {
    if (_banners.length < 2) return;
    final target = (_currentPage + 1) % _banners.length;
    _goToPage(target);
  }

  bool get _arrowsVisible =>
      widget.showArrows &&
      _banners.length > 1 &&
      (!widget.arrowsOnHover || _sliderHovered);

  /// Flecha lateral con fade: visible al hacer hover sobre el slider.
  Widget _buildArrow({
    required IconData icon,
    required VoidCallback onTap,
    required Alignment align,
    required EdgeInsets padding,
  }) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_arrowsVisible,
        child: AnimatedOpacity(
          opacity: _arrowsVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Align(
            alignment: align,
            child: Padding(
              padding: padding,
              child: _SliderArrow(icon: icon, onTap: onTap),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDots() {
    final dots = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _banners.length; i++)
          _SliderDot(active: i == _currentPage, onTap: () => _goToPage(i)),
      ],
    );

    switch (widget.dotAlignment) {
      case SliderDotAlignment.left:
        return Positioned(left: 40, bottom: 14, child: dots);
      case SliderDotAlignment.center:
        return Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [dots],
          ),
        );
      case SliderDotAlignment.right:
        return Positioned(right: 40, bottom: 14, child: dots);
    }
  }

  Widget _bannerCard(BaseItemDto item) => _SliderBannerCard(
    item: item,
    serverUrl: widget.serverUrl,
    showBorder: widget.showBorder,
    borderColor: widget.borderColor,
    borderWidth: widget.borderWidth,
    logoWidthFactor: widget.logoWidthFactor,
    showIncludedBadge: widget.showIncludedBadge,
    showJellyfinLogo: widget.showJellyfinLogo,
    hoverReveal: widget.hoverReveal,
    showActions: widget.showActions,
    showAgeRating: widget.showAgeRating,
    contentScale: widget.contentScale,
  );

  /// Capa de banners: PageView (deslizamiento) o AnimatedSwitcher (fade).
  Widget _buildBannerLayer() {
    if (_useFade) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentPage),
          child: _bannerCard(_banners[_currentPage]),
        ),
      );
    }
    return PageView.builder(
      controller: _controller,
      itemCount: _banners.length,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        _startAutoPlay();
      },
      itemBuilder: (context, i) => _bannerCard(_banners[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final height = (constraints.maxWidth * widget.heightFactor).clamp(
              widget.minHeight,
              widget.maxHeight,
            );
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  _timer?.cancel();
                } else if (notification is ScrollEndNotification) {
                  _startAutoPlay();
                }
                return false;
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => _sliderHovered = true),
                onExit: (_) => setState(() => _sliderHovered = false),
                child: SizedBox(
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildBannerLayer(),
                      _buildDots(),
                      if (widget.showArrows && _banners.length > 1) ...[
                        _buildArrow(
                          icon: Icons.chevron_left,
                          onTap: _goToPrev,
                          align: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 10),
                        ),
                        _buildArrow(
                          icon: Icons.chevron_right,
                          onTap: _goToNext,
                          align: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 10),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Tarjeta de banner horizontal de una película/serie.
class _SliderBannerCard extends ConsumerStatefulWidget {
  const _SliderBannerCard({
    required this.item,
    required this.serverUrl,
    required this.showBorder,
    required this.borderColor,
    required this.borderWidth,
    required this.logoWidthFactor,
    required this.showIncludedBadge,
    required this.showJellyfinLogo,
    required this.hoverReveal,
    required this.showActions,
    required this.showAgeRating,
    required this.contentScale,
  });

  final BaseItemDto item;
  final String? serverUrl;
  final bool showBorder;
  final Color borderColor;
  final double borderWidth;
  final double logoWidthFactor;
  final bool showIncludedBadge;
  final bool showJellyfinLogo;
  final bool hoverReveal;
  final bool showActions;
  final bool showAgeRating;
  final double contentScale;

  @override
  ConsumerState<_SliderBannerCard> createState() => _SliderBannerCardState();
}

class _SliderBannerCardState extends ConsumerState<_SliderBannerCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  String? get _logoUrl {
    final server = widget.serverUrl;
    return server != null ? itemLogoUrl(server, widget.item) : null;
  }

  bool get _hasOverview => (widget.item.overview ?? '').isNotEmpty;
  bool get _reveal => widget.hoverReveal && _hasOverview;

  /// Edad recomendada del contenido (ej. "PG-13", "R", "+18"), si tiene.
  String? get _ageRating {
    final rating = (widget.item.officialRating ?? '').trim();
    return rating.isNotEmpty ? rating : null;
  }

  Widget _titleText({double? fontSize}) {
    final skin = ref.read(skinControllerProvider).value;
    return Text(
      widget.item.name ?? '',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: skin?.textPrimary ?? Colors.white,
        fontSize: (fontSize ?? 32) * widget.contentScale,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(blurRadius: 8, color: Colors.black54, offset: Offset(0, 1)),
        ],
      ),
    );
  }

  Widget _buildLogoSlide(BoxConstraints constraints) {
    final s = widget.contentScale;
    final logoUrl = _logoUrl;
    return AnimatedSlide(
      offset: _reveal && _hovered ? const Offset(0, -0.3) : Offset.zero,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: logoUrl != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showJellyfinLogo) ...[
                  Image.asset(
                    'assets/images/jellyfin-logo.png',
                    height: 20 * s,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 6 * s),
                ],
                SizedBox(
                  width: constraints.maxWidth * widget.logoWidthFactor,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 110 * s),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.network(
                        logoUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : _titleText(fontSize: 20),
                        errorBuilder: (_, _, _) => _titleText(fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _titleText(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = ref.watch(skinControllerProvider).value;
    final radius = skin?.cardBorderRadius ?? 10;
    final fallbackColor = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final item = widget.item;
    final serverUrl = widget.serverUrl;
    final backdrop = serverUrl != null
        ? itemBackdropUrl(serverUrl, item)
        : null;
    final poster = serverUrl != null ? itemImageUrl(serverUrl, item) : null;
    final hasBackdrop =
        backdrop != null && (item.backdropImageTags?.isNotEmpty ?? false);

    final year = item.productionYear;
    final genres = item.genres ?? const <String>[];
    final rating = item.communityRating;
    final s = widget.contentScale;
    final showYear = !widget.showAgeRating && year != null;
    final showGenres = !widget.showAgeRating && genres.isNotEmpty;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(radius + 2),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            if (hasBackdrop)
              Image.network(
                backdrop,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _SliderFallback(posterUrl: poster, color: fallbackColor),
              )
            else
              _SliderFallback(posterUrl: poster, color: fallbackColor),
            // Degradado para legibilidad del texto.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.55, 1.0],
                  colors: [
                    Colors.transparent,
                    Color(0x33000000),
                    Color(0xE6000000),
                  ],
                ),
              ),
            ),
            // Capa táctil / foco. Va bajo el contenido para que los elementos
            // interactivos (botones de acción) reciban el hover y el tap.
            Positioned.fill(
              child: ScaleButton(
                selectedScale: 1.02,
                borderRadius: BorderRadius.circular(radius + 2),
                onPressed: () {},
                child: const SizedBox.expand(),
              ),
            ),
            // Columna izquierda: logo/título, botones de acción, insignia y
            // descripción (solo al pasar el ratón). Al hacer hover se desliza
            // hacia arriba únicamente el logo/título (con el logo de Jellyfin).
            Positioned(
              left: 70,
              top: 24,
              bottom: widget.hoverReveal ? 80 : 130,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // El hover solo se detecta sobre el logo/título: el
                    // MouseRegion envuelve al AnimatedSlide (fuera) para que su
                    // área no se mueva al deslizarse y no parpadee.
                    if (widget.hoverReveal)
                      MouseRegion(
                        onEnter: (_) => _setHovered(true),
                        onExit: (_) => _setHovered(false),
                        child: _buildLogoSlide(constraints),
                      )
                    else
                      _buildLogoSlide(constraints),
                    // Descripción revelada al pasar el ratón, bajo el logo y
                    // sobre los botones. Se desliza suavemente desde abajo
                    // mientras aparece. Flexible para que nunca desborde.
                    Flexible(
                      fit: FlexFit.loose,
                      child: AnimatedSlide(
                        offset: _reveal && _hovered
                            ? Offset.zero
                            : const Offset(0, 0.15),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: _reveal && _hovered ? 1 : 0,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOut,
                          child: _reveal && _hovered
                              ? Padding(
                                  padding: EdgeInsets.only(top: 4 * s),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth * 0.4,
                                    ),
                                    child: Text(
                                      item.overview!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            skin?.textSecondary ??
                                            Colors.white70,
                                        fontSize: 13 * s,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    if (widget.showActions) ...[
                      SizedBox(height: 12 * s),
                      _ActionButtons(
                        scale: s,
                        watchLabel: AppLocalizations.of(context)!.watchNow,
                        favoritesTooltip: AppLocalizations.of(
                          context,
                        )!.addToFavorites,
                        detailsTooltip: AppLocalizations.of(context)!.details,
                      ),
                    ],
                    if (widget.showIncludedBadge) ...[
                      SizedBox(height: 10 * s),
                      _IncludedBadge(
                        scale: s,
                        label: AppLocalizations.of(
                          context,
                        )!.includedWithJellyfin,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              left: 28,
              right: 28,
              bottom: 34,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rating != null || showYear || showGenres)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (rating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFF5C518),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (showYear)
                            Text(
                              '$year',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (showGenres) ...[
                            const SizedBox(width: 12),
                            Text(
                              genres.take(3).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (!widget.hoverReveal && (item.overview ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        item.overview!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: (skin?.textSecondary ?? Colors.white70),
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Edad recomendada del contenido, abajo a la derecha.
            if (widget.showAgeRating && _ageRating != null)
              Positioned(
                right: 28,
                bottom: 34,
                child: _AgeRatingBadge(rating: _ageRating!),
              ),
          ],
        ),
      ),
    );

    final cardContent = !widget.showBorder
        ? card
        : Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius + 2),
              border: Border.all(
                color: widget.borderColor,
                width: widget.borderWidth,
              ),
            ),
            child: card,
          );

    return cardContent;
  }
}

/// Botones de acción del banner: "Ver ahora", añadir (+) e información (i).
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.watchLabel,
    required this.favoritesTooltip,
    required this.detailsTooltip,
    this.scale = 1.0,
  });

  final String watchLabel;
  final String favoritesTooltip;
  final String detailsTooltip;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {},
          child: Container(
            height: 34 * s,
            padding: EdgeInsets.symmetric(horizontal: 14 * s),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4 * s),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow, color: Colors.black, size: 20 * s),
                SizedBox(width: 4 * s),
                Text(
                  watchLabel,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13 * s,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 36 * s),
        _RoundIconButton(
          icon: Icons.add,
          tooltip: favoritesTooltip,
          scale: s,
          onTap: () {},
        ),
        SizedBox(width: 8 * s),
        _RoundIconButton(
          icon: Icons.info_outline,
          tooltip: detailsTooltip,
          scale: s,
          onTap: () {},
        ),
      ],
    );
  }
}

/// Botón circular gris con un icono. Al pasar el ratón se invierten los
/// colores (fondo blanco e icono oscuro) y se muestra un [Tooltip].
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.scale = 1.0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Tooltip(
      message: tooltip,
      verticalOffset: 24 * s,
      child: HoverInvert(
        builder: (context, hovered) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            width: 34 * s,
            height: 34 * s,
            decoration: BoxDecoration(
              color: hovered ? Colors.white : Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: hovered ? Colors.grey.shade800 : Colors.white,
              size: 20 * s,
            ),
          ),
        ),
      ),
    );
  }
}

/// Recuadro de edad recomendada del contenido, coloreado según el rango.
class _AgeRatingBadge extends StatelessWidget {
  const _AgeRatingBadge({required this.rating});

  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _ageRatingColor(rating),
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
    );
  }
}

/// Color del recuadro según la edad recomendada del contenido.
Color _ageRatingColor(String rating) {
  final r = rating.trim().toUpperCase();
  final numMatch = RegExp(r'(\d+)').firstMatch(r);
  if (numMatch != null) {
    final age = int.parse(numMatch.group(1)!);
    if (age >= 18) return const Color(0xFFE53935); // rojo
    if (age >= 16) return const Color(0xFFFB8C00); // naranja
    if (age >= 12) return const Color(0xFFFDD835); // amarillo
    if (age >= 7) return const Color(0xFF43A047); // verde
    return const Color(0xFF43A047);
  }
  if (r.contains('MA') ||
      r.contains('NC-17') ||
      r.contains('NC17') ||
      r == 'R' ||
      r.contains('18')) {
    return const Color(0xFFE53935);
  }
  if (r.contains('14') || r.contains('PG-13') || r.contains('PG13')) {
    return const Color(0xFFFB8C00);
  }
  if (r.contains('PG') || r.contains('12') || r.contains('16')) {
    return const Color(0xFFFDD835);
  }
  if (r.contains('G') || r.contains('TV-Y') || r.contains('EC')) {
    return const Color(0xFF43A047);
  }
  return const Color(0xFF546E7A); // azul grisáceo por defecto
}

/// Insignia "Se incluye con Jellyfin": check azul en círculo + texto.
class _IncludedBadge extends ConsumerWidget {
  const _IncludedBadge({required this.label, this.scale = 1.0});

  final String label;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent =
        ref.watch(skinControllerProvider).value?.accent ??
        const Color(0xFF00A8E1);
    final s = scale;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18 * s,
          height: 18 * s,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          child: Icon(Icons.check, color: Colors.white, size: 12 * s),
        ),
        SizedBox(width: 6 * s),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13 * s,
            fontWeight: FontWeight.w500,
            shadows: const [
              Shadow(
                blurRadius: 4,
                color: Colors.black54,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Botón de flecha para navegar entre banners.
class _SliderArrow extends StatelessWidget {
  const _SliderArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white38),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

/// Punto del slider de navegación.
class _SliderDot extends ConsumerWidget {
  const _SliderDot({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent =
        ref.watch(skinControllerProvider).value?.accent ??
        const Color(0xFF2B7FFF);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: active ? 22 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: active ? accent : Colors.white38,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Fallback cuando no hay imagen de fondo disponible: muestra el póster (o un
/// color) sin la inicial del nombre.
class _SliderFallback extends StatelessWidget {
  const _SliderFallback({required this.color, this.posterUrl});

  final String? posterUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (posterUrl != null)
          Image.network(
            posterUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ColoredBox(color: color),
          )
        else
          ColoredBox(color: color),
        const ColoredBox(color: Color(0x66000000)),
      ],
    );
  }
}
