import 'package:flutter/material.dart';

/// Texto con efecto marquee al hacer hover, solo si hay overflow.
///
/// Comportamiento estilo Jellyfin Android TV / Fire TV:
/// - Si el texto cabe, se muestra normal con ellipsis.
/// - Si hace overflow y [isHovered] es true y [enabled] es true,
///   el texto se desplaza de derecha a izquierda en bucle infinito.
/// - Cuando la última letra sale por la izquierda, vuelve a entrar por la
///   derecha sin saltos bruscos (dos copias con separación).
class MarqueeText extends StatefulWidget {
  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    required this.isHovered,
    this.enabled = true,
    this.textAlign = TextAlign.left,
    this.velocity = 35,
    this.gap = 40,
    this.pauseDuration = const Duration(milliseconds:  500),
  });

  final String text;
  final TextStyle style;
  final bool isHovered;
  final bool enabled;
  final TextAlign textAlign;

  /// Velocidad en píxeles por segundo.
  final double velocity;

  /// Separación entre la copia final y la inicial en el bucle.
  final double gap;

  /// Pausa antes de empezar a desplazar en cada ciclo.
  final Duration pauseDuration;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _needsMarquee = false;
  double _textWidth = 0;
  double _containerWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _evaluateAndMaybeStart(double containerWidth) {
    if (!widget.enabled || !widget.isHovered) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 0;
      return;
    }
    if (!_needsMarquee) return;
    if (_textWidth <= 0 || containerWidth <= 0) return;

    final distance = _textWidth + widget.gap;
    final durationMs = (distance / widget.velocity * 1000).round();
    final duration = Duration(milliseconds: durationMs);

    // Si ya está animando con la misma distancia, no reiniciar.
    if (_controller.duration == duration && _controller.isAnimating) return;

    _controller.duration = duration;
    // Animar de 0 a -distance en bucle.
    _animation = Tween<double>(begin: 0, end: -distance).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    // Pausa inicial antes de arrancar (estilo Jellyfin TV).
    Future.delayed(widget.pauseDuration, () {
      if (!mounted) return;
      if (!widget.isHovered || !_needsMarquee || !widget.enabled) return;
      if (_controller.isAnimating) return;
      // Si el usuario salió del hover durante la pausa, no arrancar.
      _controller.repeat();
    });
  }

  void _stop() {
    if (_controller.isAnimating) _controller.stop();
    // Reset suave: volver a 0 sin animar para que no quede a medias.
    _controller.value = 0;
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.isHovered != widget.isHovered ||
        oldWidget.enabled != widget.enabled) {
      // Reevaluar en el próximo frame cuando tengamos medidas.
      if (!widget.isHovered || !widget.enabled) {
        _stop();
      }
      // Forzar recálculo en build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    if (!widget.isHovered || !widget.enabled) {
      _stop();
    } else if (widget.isHovered && widget.enabled && _needsMarquee) {
      _evaluateAndMaybeStart(_containerWidth);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sin marquee activo -> texto normal con ellipsis.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        // Medir texto.
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);
        _textWidth = tp.width;
        _containerWidth = maxWidth;
        _needsMarquee = _textWidth > maxWidth + 0.5;

        final shouldAnimate =
            widget.enabled && widget.isHovered && _needsMarquee;

        if (!shouldAnimate) {
          // Detener animación si no corresponde.
          if (_controller.isAnimating) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _stop());
          }
          return Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
            style: widget.style,
          );
        }

        // Activar animación si hace falta (post frame para tener duration lista).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _evaluateAndMaybeStart(maxWidth);
        });

        // Con marquee: Clip + Row con dos copias separadas por gap para bucle continuo.
        // OverflowBox permite que el Row sea más ancho que el ClipRect sin
        // disparar el assert de RenderFlex overflowed.
        return ClipRect(
          child: SizedBox(
            width: maxWidth,
            height: tp.height,
            child: OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(_animation.value, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.text, style: widget.style),
                    SizedBox(width: widget.gap),
                    Text(widget.text, style: widget.style),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
