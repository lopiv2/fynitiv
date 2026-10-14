import 'package:material_ui/material_ui.dart';

/// Estilo del botón de play circular que aparece al hacer hover sobre una
/// tarjeta o un capítulo.
enum HoverPlayGlyphStyle {
  /// Círculo oscuro translúcido con borde blanco y play blanco (estilo actual).
  outline,

  /// Círculo blanco con play gris (estilo Amazon Prime).
  prime,
}

/// Botón de play circular reutilizable del hover.
class HoverPlayGlyph extends StatelessWidget {
  const HoverPlayGlyph({
    super.key,
    this.style = HoverPlayGlyphStyle.outline,
    this.size = 52,
  });

  final HoverPlayGlyphStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconSize = size * 0.62;
    switch (style) {
      case HoverPlayGlyphStyle.outline:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: iconSize,
          ),
        );
      case HoverPlayGlyphStyle.prime:
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            color: const Color(0xFF5A5A5A),
            size: iconSize,
          ),
        );
    }
  }
}

/// Estilo del glyph de play según el skin (Prime usa el suyo; el resto, outline).
HoverPlayGlyphStyle hoverPlayGlyphStyleFor(String? skinId) =>
    skinId == 'amazon_prime'
    ? HoverPlayGlyphStyle.prime
    : HoverPlayGlyphStyle.outline;
