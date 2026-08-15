import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import 'age_rating_badge.dart';
import 'included_badge.dart';
import 'round_icon_button.dart';
import 'watch_now_button.dart';

/// Altura del panel de extensión que aparece bajo la tarjeta al hacer hover
/// (estilo Prime). El panel se superpone al contenido que haya debajo.
const double kCardHoverExtensionHeight = 240;

/// Envuelve una tarjeta de contenido y le añade el comportamiento de hover:
///
/// - En cualquier skin aparece un icono de play sobre el elemento.
/// - Si [showExtension] está activado (skin estilo Prime), al hacer hover se
///   muestra además un panel negro bajo la tarjeta, con el mismo ancho, que
///   incluye el nombre del contenido y un botón de reproducir en el estilo
///   "Ver ahora" del slider de novedades. El panel se dibuja en un [Overlay]
///   para superponerse al contenido de debajo (estilo Amazon Prime) y se
///   reposiciona automáticamente al hacer scroll.
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

  /// Notifica cuando el hover entra/sale de la tarjeta (o su panel). Permite
  /// que la fila reordene el pintado para que la tarjeta escalada se
  /// superponga a las vecinas.
  final ValueChanged<bool>? onHoverChanged;

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

/// Expone el estado de hover y el ancho de la tarjeta a sus descendientes
/// (p. ej. para quitar el radio de las esquinas al hacer hover).
class HoverPlayScope extends InheritedWidget {
  const HoverPlayScope({
    super.key,
    required this.hovered,
    required this.cardWidth,
    required super.child,
  });

  final bool hovered;
  final double cardWidth;

  static HoverPlayScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HoverPlayScope>();
  }

  @override
  bool updateShouldNotify(HoverPlayScope oldWidget) =>
      hovered != oldWidget.hovered || cardWidth != oldWidget.cardWidth;
}

/// Recorta la tarjeta con las dos esquinas superiores siempre redondeadas.
/// Solo las inferiores varían: al hacer hover (hovercard visible) pasan a ser
/// rectas y sin hover conservan el radio.
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
  final ValueNotifier<Rect> _panelRect = ValueNotifier(
    const Rect.fromLTWH(0, 0, 0, 0),
  );
  bool _tracking = false;

  /// Anchura de la tarjeta, capturada en el build a partir de las
  /// restricciones reales del layout. Es la anchura exacta del elemento.
  double _cardWidth = 0;

  void _setHovered(bool value) {
    if (value) {
      _hideTimer?.cancel();
      if (!_hovered) {
        _hovered = true;
        if (widget.showExtension) _showOverlay();
        if (mounted) setState(() {});
        widget.onHoverChanged?.call(true);
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

  /// Oculta el panel tras un pequeño retardo. Permite que el cursor pase de la
  /// tarjeta al panel sin que desaparezca (el panel cancela el retardo).
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _setHovered(false);
    });
  }

  void _showOverlay() {
    _removeOverlay();
    final entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<Rect>(
        valueListenable: _panelRect,
        builder: (context, rect, _) {
          if (rect.width <= 0) return const SizedBox.shrink();
          return Positioned(
            left: rect.left - 10,
            top: rect.top - 110,
            width: rect.width,
            height: rect.height,
            child: _HoverPanel(
              width: _cardWidth,
              title: widget.title,
              onPlay: widget.onPlay,
              onTrailer: widget.onTrailer,
              onFavorites: widget.onFavorites,
              resume: widget.resume,
              ageRating: widget.ageRating,
              year: widget.year,
              runTimeTicks: widget.runTimeTicks,
              overview: widget.overview,
              onEnter: () {
                _hideTimer?.cancel();
                if (mounted && _hovered) setState(() {});
              },
              onExit: _scheduleHide,
            ),
          );
        },
      ),
    );
    _overlayEntry = entry;
    Overlay.of(context).insert(entry);
    _startTracking();
  }

  /// Mide el borde inferior-izquierdo de la tarjeta (siguiendo su escala visual)
  /// y coloca el panel bajo él, con el ancho del elemento. El ancho se mantiene
  /// en el de layout para que el panel no se extienda más allá de la tarjeta.
  void _measurePanelRect() {
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    try {
      // Borde inferior-izquierdo global de la tarjeta (incluye la escala del
      // ScaleButton). El -1 deja la parte superior pegada al elemento.
      final bottomLeft = box.localToGlobal(Offset(0, box.size.height));
      final bottomRight = box.localToGlobal(
        Offset(box.size.width, box.size.height),
      );
      final scaledWidth = bottomRight.dx - bottomLeft.dx;
      final rect = Rect.fromLTWH(
        bottomLeft.dx,
        bottomLeft.dy - 1,
        scaledWidth,
        kCardHoverExtensionHeight,
      );
      if (rect != _panelRect.value) _panelRect.value = rect;
    } catch (_) {
      // Transformación no disponible aún (layout en curso); se reintenta en el
      // siguiente frame del rastreo.
    }
  }

  /// Re-mide el panel cada frame mientras hay hover para seguir la animación
  /// de escala del ScaleButton y el scroll de la fila/página.
  void _startTracking() {
    _tracking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackFrame());
  }

  void _trackFrame() {
    if (!_tracking || !mounted || !_hovered || _overlayEntry == null) return;
    _measurePanelRect();
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
    _panelRect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Anchura real que ocupa la tarjeta en el layout.
        _cardWidth = constraints.maxWidth;
        return HoverPlayScope(
          hovered: _hovered,
          cardWidth: _cardWidth,
          child: MouseRegion(
            onEnter: (_) => _setHovered(true),
            onExit: (_) => _scheduleHide(),
            child: Stack(
              key: _cardKey,
              clipBehavior: Clip.hardEdge,
              children: [
                widget.child,
                // Icono de play al hacer hover. Con el panel de extensión
                // (Prime) es redundante, ya que la hovercard ya lo muestra.
                if (_hovered && !widget.showExtension)
                  Positioned.fill(child: IgnorePointer(child: _PlayOverlay())),
              ],
            ),
          ),
        );
      },
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

/// Panel negro que aparece bajo la tarjeta, con el nombre del contenido y los
/// botones de acción en el mismo estilo que los del slider de novedades.
class _HoverPanel extends StatelessWidget {
  const _HoverPanel({
    required this.width,
    required this.title,
    required this.onPlay,
    required this.onEnter,
    required this.onExit,
    this.onTrailer,
    this.onFavorites,
    this.resume = false,
    this.ageRating,
    this.year,
    this.runTimeTicks,
    this.overview,
  });

  final double width;
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

  /// Se llama al entrar el cursor en el panel (cancela el retardo de ocultado).
  final VoidCallback onEnter;

  /// Se llama al salir el cursor del panel (programa el ocultado).
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MouseRegion(
      onEnter: (_) => onEnter(),
      onExit: (_) => onExit(),
      child: SizedBox(
        width: width,
        height: kCardHoverExtensionHeight,
        child: Container(
          // Opaco por completo: al superponerse sobre un grid denso (p. ej.
          // All Movies), un borde transparente dejaba ver el contenido de
          // debajo y daba aspecto de texto duplicado/subrayado.
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
              // Insignia "Se incluye con Jellyfin" (la misma del slider),
              // entre el nombre del elemento y los botones de acción.
              IncludedBadge(label: l10n.includedWithJellyfin, scale: 0.9),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // El mismo botón "Ver ahora" del slider de novedades: misma
                  // lógica (abre el reproductor) y mismo estilo. En "Continuar
                  // viendo" muestra "Reanudar".
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
              // Fila de metadatos: edad recomendada, año y duración.
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
              // Descripción del contenido, bajo los metadatos.
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
