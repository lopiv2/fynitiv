import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import 'age_rating_badge.dart';
import 'included_badge.dart';
import 'round_icon_button.dart';
import 'watch_now_button.dart';

/// Altura del panel de extensión que aparece bajo la tarjeta al hacer hover
/// (estilo Prime).
const double kCardHoverExtensionHeight = 240;

/// Cuánto crece el ancho de la tarjeta al expandirse (estilo Prime: la
/// tarjeta se agranda ligeramente además de mostrar el panel).
const double kCardExpandScale = 1.3;

/// Duración de la animación de expansión/colapso de la tarjeta.
const Duration kCardExpandDuration = Duration(milliseconds: 200);

/// Envuelve una tarjeta de contenido y le añade el comportamiento de hover:
///
/// - En cualquier skin aparece un icono de play sobre el elemento.
/// - Si [showExtension] está activado (skin estilo Prime), al hacer hover la
///   tarjeta se "clona" en un [Overlay] como una única columna (imagen +
///   panel negro), que crece desde el tamaño original hacia un tamaño
///   ampliado. Imagen y panel son hermanos dentro del mismo [Column], así
///   que SIEMPRE comparten exactamente el mismo ancho — no hay dos anchos
///   independientes que sincronizar ni transformaciones que perseguir.
class HoverPlayCard extends StatefulWidget {
  const HoverPlayCard({
    super.key,
    required this.child,
    required this.title,
    required this.onPlay,
    this.showExtension = false,
    this.onTrailer,
    this.onFavorites,
    this.onHoverChanged,
    this.onPointerSignal,
    this.overlayBelowEntry,
    this.resume = false,
    this.ageRating,
    this.year,
    this.runTimeTicks,
    this.overview,
  });

  /// Contenido de la tarjeta (imagen, texto, etc.).
  final Widget child;

  /// Nombre del contenido (se muestra en el panel de extensión).
  final String title;

  /// Acción al pulsar reproducir (o la tarjeta).
  final VoidCallback onPlay;

  /// Muestra el panel de extensión negro al hacer hover.
  final bool showExtension;

  /// Acción al pulsar el botón de trailer del panel de extensión.
  final VoidCallback? onTrailer;

  /// Acción al pulsar el botón de favoritos del panel de extensión.
  final VoidCallback? onFavorites;

  /// Notifica cuando el hover entra/sale de la tarjeta (o su panel).
  final ValueChanged<bool>? onHoverChanged;

  /// Reenvia eventos de rueda al scroll vertical de la pagina que contiene la
  /// tarjeta. Es necesario porque la hovercard vive en un Overlay superior.
  final ValueChanged<PointerSignalEvent>? onPointerSignal;

  /// Overlay que debe quedar por encima de esta hovercard (por ejemplo, las
  /// flechas activas de la fila). El z-order se fija al insertar la entrada.
  final OverlayEntry? Function()? overlayBelowEntry;

  /// Si el elemento es de "Continuar viendo", el botón del panel muestra
  /// "Reanudar" en lugar de "Ver ahora".
  final bool resume;

  /// Edad recomendada del contenido (ej. "PG-13").
  final String? ageRating;

  /// Año de producción del contenido.
  final int? year;

  /// Duración en ticks de Jellyfin (100 ns).
  final int? runTimeTicks;

  /// Sinopsis / descripción del contenido.
  final String? overview;

  @override
  State<HoverPlayCard> createState() => _HoverPlayCardState();
}

/// Expone el estado de hover a sus descendientes (p. ej. para quitar el
/// radio de las esquinas inferiores de la imagen cuando la tarjeta está
/// expandida en el Overlay).
class HoverPlayScope extends InheritedWidget {
  const HoverPlayScope({
    super.key,
    required this.hovered,
    required super.child,
  });

  final bool hovered;

  static HoverPlayScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HoverPlayScope>();
  }

  @override
  bool updateShouldNotify(HoverPlayScope oldWidget) =>
      hovered != oldWidget.hovered;
}

/// Recorta la tarjeta con las dos esquinas superiores siempre redondeadas.
/// Solo las inferiores varían: cuando la tarjeta está expandida (hovercard
/// visible en el Overlay) pasan a ser rectas; en su posición normal del grid
/// conservan el radio completo.
class HoverPlayRadius extends StatelessWidget {
  const HoverPlayRadius({super.key, required this.radius, required this.child});

  /// Radio normal (esquinas redondeadas) cuando no hay hover.
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hovered = HoverPlayScope.of(context)?.hovered ?? false;
    return ClipRRect(
      borderRadius: hovered
          ? BorderRadius.vertical(top: Radius.circular(radius))
          : BorderRadius.circular(radius),
      child: child,
    );
  }
}

class _HoverPlayCardState extends State<HoverPlayCard> {
  bool _hovered = false;
  final GlobalKey _cardKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;

  /// Posición global (esquina superior-izquierda) de la tarjeta en su
  /// tamaño ORIGINAL, sin expandir. Solo cambia por scroll, nunca por la
  /// propia animación de expansión (por eso basta con re-medir la posición,
  /// no el tamaño, en cada frame mientras hay hover).
  final ValueNotifier<Offset> _origin = ValueNotifier(Offset.zero);
  bool _tracking = false;

  /// Tamaño original de la tarjeta (sin expandir), capturado al mostrar el
  /// overlay. Es la base sobre la que se calculan el ancho y el
  /// desplazamiento vertical al expandir.
  Size _originSize = Size.zero;

  void _setHovered(bool value) {
    if (value) {
      _hideTimer?.cancel();
      if (!_hovered) {
        _hovered = true;
        widget.onHoverChanged?.call(true);
        if (widget.showExtension) _showOverlay();
        if (mounted) setState(() {});
      }
    } else {
      _hideTimer?.cancel();
      if (_hovered) {
        _hovered = false;
        _removeOverlay();
        if (mounted) setState(() {});
        widget.onHoverChanged?.call(false);
      }
    }
  }

  /// Oculta el panel tras un pequeño retardo. Permite que el cursor pase de
  /// la tarjeta al panel sin que desaparezca (el panel cancela el retardo).
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _setHovered(false);
    });
  }

  /// Convierte la posición global de la tarjeta a coordenadas LOCALES del
  /// propio [Overlay]. `Positioned` dentro del Overlay interpreta left/top
  /// como relativos a su propio Stack, no a la pantalla — si se le pasan
  /// coordenadas globales sin convertir, la tarjeta aparece desplazada hacia
  /// abajo (y/o a la derecha) tanto como mida todo lo que hay por encima del
  /// Overlay (AppBar, padding del Scaffold, etc.).
  Offset _toOverlayLocal(Offset globalOffset) {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) return globalOffset;
    return overlayBox.globalToLocal(globalOffset);
  }

  void _showOverlay() {
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    _originSize = box.size;
    _origin.value = _toOverlayLocal(box.localToGlobal(Offset.zero));

    _removeOverlay();
    final entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<Offset>(
        valueListenable: _origin,
        builder: (context, origin, _) {
          return _ExpandedHoverCard(
            origin: origin,
            originWidth: _originSize.width,
            originHeight: _originSize.height,
            image: widget.child,
            title: widget.title,
            onPlay: widget.onPlay,
            onTrailer: widget.onTrailer,
            onFavorites: widget.onFavorites,
            resume: widget.resume,
            ageRating: widget.ageRating,
            year: widget.year,
            runTimeTicks: widget.runTimeTicks,
            overview: widget.overview,
            onPointerSignal: widget.onPointerSignal ?? _pagePointerSignal,
            onEnter: () => _hideTimer?.cancel(),
            onExit: _scheduleHide,
          );
        },
      ),
    );
    _overlayEntry = entry;
    Overlay.of(context).insert(entry, below: widget.overlayBelowEntry?.call());
    _startTracking();
  }

  void _pagePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    final position = Scrollable.maybeOf(context)?.position;
    position?.pointerScroll(event.scrollDelta.dy);
  }

  /// Re-mide solo la POSICIÓN (no el tamaño) de la tarjeta original cada
  /// frame mientras hay hover, para seguir el scroll de la fila/página. El
  /// tamaño expandido lo controla únicamente `_ExpandedHoverCard`, así que
  /// no hay dos fuentes de verdad para el ancho compitiendo entre sí.
  void _startTracking() {
    _tracking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackFrame());
  }

  void _trackFrame() {
    if (!_tracking || !mounted || !_hovered || _overlayEntry == null) return;
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.attached) {
      final newOrigin = _toOverlayLocal(box.localToGlobal(Offset.zero));
      if (newOrigin != _origin.value) _origin.value = newOrigin;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackFrame());
  }

  void _stopTracking() => _tracking = false;

  void _removeOverlay() {
    _stopTracking();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _stopTracking();
    _hideTimer?.cancel();
    _removeOverlay();
    _origin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mientras la tarjeta está expandida en el Overlay, la original se deja
    // invisible pero SIN quitarla del layout (Opacity, no un if): así el
    // hueco del grid no colapsa y no hay salto de posición para las tarjetas
    // vecinas.
    final hideOriginal = _hovered && widget.showExtension;
    return HoverPlayScope(
      hovered: false,
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _scheduleHide(),
        child: GestureDetector(
          onTap: widget.onPlay,
          child: KeyedSubtree(
            key: _cardKey,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(opacity: hideOriginal ? 0 : 1, child: widget.child),
                if (_hovered && !widget.showExtension)
                  Positioned.fill(child: IgnorePointer(child: _PlayOverlay())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La tarjeta "clonada" que vive en el Overlay: imagen + panel dentro del
/// mismo [Column], creciendo desde el tamaño original hacia el ampliado.
/// Al ser hermanos del mismo Column con `CrossAxisAlignment.stretch`, imagen
/// y panel SIEMPRE tienen el mismo ancho — no existen dos medidas que puedan
/// desincronizarse.
class _ExpandedHoverCard extends StatefulWidget {
  const _ExpandedHoverCard({
    required this.origin,
    required this.originWidth,
    required this.originHeight,
    required this.image,
    required this.title,
    required this.onPlay,
    required this.onEnter,
    required this.onExit,
    required this.onPointerSignal,
    this.onTrailer,
    this.onFavorites,
    this.resume = false,
    this.ageRating,
    this.year,
    this.runTimeTicks,
    this.overview,
  });

  final Offset origin;
  final double originWidth;
  final double originHeight;
  final Widget image;
  final String title;
  final VoidCallback onPlay;
  final VoidCallback onEnter;
  final VoidCallback onExit;
  final ValueChanged<PointerSignalEvent>? onPointerSignal;
  final VoidCallback? onTrailer;
  final VoidCallback? onFavorites;
  final bool resume;
  final String? ageRating;
  final int? year;
  final int? runTimeTicks;
  final String? overview;

  @override
  State<_ExpandedHoverCard> createState() => _ExpandedHoverCardState();
}

class _ExpandedHoverCardState extends State<_ExpandedHoverCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Arranca colapsada (tamaño original) y se expande un frame después,
    // para que el AnimatedContainer anime el crecimiento en vez de aparecer
    // ya expandida de golpe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _expanded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = _expanded ? kCardExpandScale : 1.0;
    final width = widget.originWidth * scale;
    // La imagen mantiene su aspect ratio (viene fijado dentro de widget.image
    // vía AspectRatio), así que su alto crece EXACTAMENTE con el mismo
    // factor que el ancho. Se calcula ese extra de alto para centrar el
    // crecimiento de la imagen en torno a su punto medio original: la mitad
    // del extra se resta arriba (por eso "sube") y la otra mitad se suma
    // abajo — el panel se añade después, sin tocar este cálculo.
    final imageHeight = widget.originHeight * scale;
    final extraImageHeight = imageHeight - widget.originHeight;
    final extraWidth = width - widget.originWidth;
    final top = widget.origin.dy - (extraImageHeight / 2);

    // Crecimiento centrado por defecto (mitad hacia cada lado). Si eso saca
    // la tarjeta fuera de la pantalla por la izquierda o la derecha, se
    // "reparte" el hueco disponible en vez de cortarla — pegándola al borde
    // correspondiente, igual que hacen Prime/Netflix con las tarjetas de los
    // extremos del carrusel.
    final screenWidth = MediaQuery.sizeOf(context).width;
    var left = widget.origin.dx - (extraWidth / 2);
    if (left < 0) {
      left = 0;
    } else if (left + width > screenWidth) {
      left = screenWidth - width;
    }

    return AnimatedPositioned(
      duration: kCardExpandDuration,
      curve: Curves.easeOut,
      left: left,
      top: top,
      width: width,
      child: MouseRegion(
        onEnter: (_) => widget.onEnter(),
        onExit: (_) => widget.onExit(),
        child: Listener(
          onPointerSignal: widget.onPointerSignal,
          child: AnimatedContainer(
            duration: kCardExpandDuration,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: _expanded
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: HoverPlayScope(
              // Fuerza el radio "recto abajo" en la imagen mientras está
              // expandida, para que se funda visualmente con el panel negro.
              hovered: _expanded,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: widget.onPlay,
                    child: Stack(
                      children: [
                        widget.image,
                        if (_expanded)
                          Positioned.fill(
                            child: IgnorePointer(child: _PlayOverlay()),
                          ),
                      ],
                    ),
                  ),
                  // El panel crece en altura de 0 al tamaño real: al ser hijo
                  // del mismo Column, hereda el ancho ya estirado (stretch),
                  // así que nunca necesita que se le pase un `width` aparte.
                  AnimatedSize(
                    duration: kCardExpandDuration,
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _expanded
                        ? _HoverPanel(
                            title: widget.title,
                            onPlay: widget.onPlay,
                            onTrailer: widget.onTrailer,
                            onFavorites: widget.onFavorites,
                            resume: widget.resume,
                            ageRating: widget.ageRating,
                            year: widget.year,
                            runTimeTicks: widget.runTimeTicks,
                            overview: widget.overview,
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Oscurece la tarjeta y muestra un botón circular de play centrado.
class _PlayOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: Container(
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
        ),
      ),
    );
  }
}

/// Panel negro que aparece bajo la imagen, con el nombre del contenido y los
/// botones de acción. Ya NO recibe un `width` explícito: hereda el ancho del
/// [Column] padre (`CrossAxisAlignment.stretch`), que es el mismo que usa la
/// imagen justo encima — por construcción, nunca pueden desalinearse.
class _HoverPanel extends StatelessWidget {
  const _HoverPanel({
    required this.title,
    required this.onPlay,
    this.onTrailer,
    this.onFavorites,
    this.resume = false,
    this.ageRating,
    this.year,
    this.runTimeTicks,
    this.overview,
  });

  final String title;
  final VoidCallback onPlay;
  final VoidCallback? onTrailer;
  final VoidCallback? onFavorites;

  /// Muestra "Reanudar" en el botón si el elemento es de "Continuar viendo".
  final bool resume;

  final String? ageRating;
  final int? year;
  final int? runTimeTicks;
  final String? overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      child: SizedBox(
        height: kCardHoverExtensionHeight,
        child: Container(
          // Opaco por completo: al superponerse sobre un grid denso (p. ej.
          // All Movies), un fondo semitransparente dejaba ver el contenido de
          // debajo y daba aspecto de texto duplicado.
          color: const Color(0xFF000000),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              IncludedBadge(label: l10n.includedWithJellyfin, scale: 0.9),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WatchNowButton(
                    label: resume ? l10n.resume : l10n.watchNow,
                    onTap: onPlay,
                  ),
                  const SizedBox(width: 10),
                  RoundIconButton(
                    icon: Icons.play_circle_outline,
                    tooltip: l10n.watchTrailer,
                    onTap: onTrailer ?? () {},
                  ),
                  const SizedBox(width: 6),
                  RoundIconButton(
                    icon: Icons.add,
                    tooltip: l10n.addToFavorites,
                    onTap: onFavorites ?? () {},
                  ),
                ],
              ),
              if (ageRating != null ||
                  year != null ||
                  runTimeTicks != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ageRating != null && ageRating!.trim().isNotEmpty) ...[
                      AgeRatingBadge(rating: ageRating!),
                      const SizedBox(width: 8),
                    ],
                    if (year != null) ...[
                      Text(
                        '$year',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (runTimeTicks != null) const SizedBox(width: 8),
                    ],
                    if (runTimeTicks != null)
                      Text(
                        _formatDuration(runTimeTicks!),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ],
              if (overview != null && overview!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  overview!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Formatea los ticks de Jellyfin (100 ns) como duración legible: "1h 30m".
String _formatDuration(int ticks) {
  final minutes = (ticks ~/ 600000000); // 600.000.000 ticks = 1 minuto
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
