import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/splash_presentation.dart';

const String _kChristmasBackAsset =
    'assets/images/seasonal/christmas_back.webp';
const String _kSantaAsset = 'assets/images/seasonal/santa.webp';

/// Presentación de Navidad: audio propio, paleta blanca/roja/verde adaptada a la
/// noche azul de `christmas_back`, copos cayendo, brillo cálido del pueblo y
/// Papá Noel con su trineo cruzando el cielo. El fondo aparece por fundido y se
/// queda; los copos siguen durante toda la animación.
const SplashPresentation kChristmasSplashPresentation = SplashPresentation(
  id: 'christmas',
  audioAsset: 'audio/christmas_splash_reveal.mp3',
  backgroundAsset: 'assets/images/backgrounds/splash_back.png',
  letterStops: [
    Color(0xFFFFFFFF), // blanco (primera letra)
    Color(0xFFFF5252), // rojo brillante (acento)
    Color(0xFF69F0AE), // verde menta (primario, con contraste sobre azul)
  ],
  taglineColors: [
    Color(0xFFFFFFFF), // Watch.   — blanco
    Color(0xFFFF5252), // Read.    — rojo
    Color(0xFFFFD54F), // Play.    — oro (luces del pueblo)
    Color(0xFF69F0AE), // Anything — verde menta
  ],
  extrusionDark: Color(0xFF0B1E3A), // azul profundo del cielo navideño
  extrusionLight: Color(0xFF7A0E12), // rojo de la paleta estacional
  glowColor: Color(0xFFFFD54F), // halo dorado
  backgroundTint: Color(0x330B1E3A), // leve azul nocturno
  iconColor: Color(0xFFFFD54F), // oro
  iconShadows: [
    Shadow(color: Color(0xCC0B1E3A), blurRadius: 10),
    Shadow(color: Color(0x990B1E3A), blurRadius: 22),
  ],
  backgroundEffects: [
    christmasBackEffect,
    christmasVillageGlowEffect,
    christmasSantaEffect,
    christmasSnowEffect,
  ],
  effects: [christmasForegroundSnowEffect],
);

// ---------------------------------------------------------------------------
// Fondo
// ---------------------------------------------------------------------------

/// `christmas_back` aparece por fundido y se queda como escenario.
Widget christmasBackEffect(BuildContext context, double progress) {
  final t = Curves.easeOut.transform(
    ((progress - 0.08) / 0.35).clamp(0.0, 1.0),
  );
  if (t <= 0) return const SizedBox.shrink();
  return IgnorePointer(
    child: Opacity(
      opacity: t,
      child: Image.asset(
        _kChristmasBackAsset,
        fit: BoxFit.cover,
        // Si el asset aún no está disponible, no romper la presentación.
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    ),
  );
}

/// Brillo cálido del pueblo (parte inferior), con un pulso muy leve.
Widget christmasVillageGlowEffect(BuildContext context, double progress) {
  final appear = Curves.easeOut.transform(
    ((progress - 0.18) / 0.4).clamp(0.0, 1.0),
  );
  if (appear <= 0) return const SizedBox.shrink();
  final pulse = 0.85 + 0.15 * math.sin(progress * 2 * math.pi * 1.2);
  return IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFFB74D).withValues(alpha: 0.20 * pulse * appear),
            const Color(0x00FFB74D),
          ],
          stops: const [0.0, 0.48],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Papá Noel volando
// ---------------------------------------------------------------------------

/// Trineo de Papá Noel cruzando el cielo de izquierda a derecha, con un arco
/// suave, leve cabeceo y desvanecido en los extremos. Va detrás del contenido.
Widget christmasSantaEffect(BuildContext context, double progress) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;

      // Cruza entre el 12% y el 82% del reloj.
      final local = ((progress - 0.12) / 0.70).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) return const SizedBox.shrink();

      final santaHeight = (height * 0.24).clamp(90.0, 260.0);
      final santaWidth = santaHeight * 1.8;
      // De fuera a fuera de pantalla.
      final left = -santaWidth + local * (width + 2 * santaWidth);
      // Arco: sube en el centro del recorrido y cabecea suavemente.
      final arc = -0.055 * height * math.sin(local * math.pi);
      final bob = 5.0 * math.sin(local * 2 * math.pi * 2.2);
      final top = height * 0.12 + arc + bob;
      // Cabeceo siguiendo el arco (nariz arriba al ascender).
      final tilt = -0.06 * math.cos(local * math.pi) +
          0.015 * math.sin(local * 2 * math.pi * 2.2);
      // Desvanecido en los extremos.
      final opacity = math
          .min(1.0, math.min(local / 0.10, (1 - local) / 0.10))
          .clamp(0.0, 1.0);

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: santaWidth,
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: tilt,
                  alignment: Alignment.center,
                  child: Image.asset(
                    _kSantaAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Nieve
// ---------------------------------------------------------------------------

/// Copos de nieve cayendo (capa de fondo), con deriva lateral y varios tamaños.
Widget christmasSnowEffect(BuildContext context, double progress) {
  final appear = Curves.easeOut.transform((progress / 0.08).clamp(0.0, 1.0));
  return CustomPaint(
    painter: _SnowPainter(
      progress: progress,
      appear: appear,
      count: 110,
      maxSize: 4.2,
      opacity: 0.85,
      seed: 1224,
    ),
  );
}

/// Capa de copos grandes y tenues por delante del contenido: da profundidad.
Widget christmasForegroundSnowEffect(
  BuildContext context,
  double progress,
) {
  final appear = Curves.easeOut.transform((progress / 0.10).clamp(0.0, 1.0));
  return CustomPaint(
    painter: _SnowPainter(
      progress: progress,
      appear: appear,
      count: 12,
      maxSize: 7.0,
      opacity: 0.30,
      seed: 2512,
    ),
  );
}

class _SnowPainter extends CustomPainter {
  _SnowPainter({
    required this.progress,
    required this.appear,
    required this.count,
    required this.maxSize,
    required this.opacity,
    required this.seed,
  });

  final double progress;
  final double appear;
  final int count;
  final double maxSize;
  final double opacity;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || appear <= 0) return;
    // Semilla fija: el reparto y las velocidades son estables en cada frame.
    final rnd = math.Random(seed);
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final startY = rnd.nextDouble();
      final speed = 0.35 + rnd.nextDouble() * 0.85;
      final startX = rnd.nextDouble();
      final swayAmplitude = 0.006 + rnd.nextDouble() * 0.022;
      final swayFreq = 1.5 + rnd.nextDouble() * 1.5;
      final phase = rnd.nextDouble() * 2 * math.pi;
      final radius = 0.9 + rnd.nextDouble() * (maxSize - 0.9);
      final alpha = opacity * (0.35 + rnd.nextDouble() * 0.65) * appear;

      // Caída continua con wrap vertical.
      final y = ((startY + speed * progress * 2.4) % 1.0) * size.height;
      // Deriva lateral suave.
      final x =
          (startX + swayAmplitude * math.sin(progress * 2 * math.pi * swayFreq + phase)) *
          size.width;

      paint.color = Colors.white.withValues(alpha: alpha);
      paint.maskFilter = radius > 2.6
          ? const MaskFilter.blur(BlurStyle.normal, 1.1)
          : null;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.appear != appear ||
      oldDelegate.count != count ||
      oldDelegate.maxSize != maxSize ||
      oldDelegate.opacity != opacity ||
      oldDelegate.seed != seed;
}
