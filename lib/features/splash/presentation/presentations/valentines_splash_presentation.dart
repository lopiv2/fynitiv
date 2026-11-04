import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/splash_presentation.dart';

const String _kValentinesBackAsset =
    'assets/images/seasonal/valentine_back.jpg';

/// Presentación de San Valentín: audio propio, paleta rosa de la temática
/// adaptada al atardecer claro de `valentine_back`, fondo por fundido, brillo
/// cálido inferior y corazones/pétalos flotando. El icono del tagline usa el
/// rosa de la paleta + sombras oscuras para no desaparecer sobre el fondo claro.
const SplashPresentation kValentinesSplashPresentation = SplashPresentation(
  id: 'valentines',
  audioAsset: 'audio/valentines_splash_reveal.mp3',
  backgroundAsset: 'assets/images/backgrounds/splash_back.png',
  letterStops: [
    Color.fromARGB(255, 240, 181, 199), // rosa pálido (primera letra)
    Color(0xFFFF4D7D), // rosa (acento de la paleta estacional)
    Color(0xFFE91E63), // rosa intenso (primario de la paleta estacional)
  ],
  taglineColors: [
    Color(0xFFFFE4EC), // Watch.   — rosa pálido
    Color(0xFFFF4D7D), // Read.    — rosa
    Color(0xFFFF8FB1), // Play.    — rosa claro
    Color(0xFFE91E63), // Anything — rosa intenso
  ],
  extrusionDark: Color(0xFF2A0A1E), // fondo superior de la paleta de San Valentín
  extrusionLight: Color(0xFF7A0E32), // fondo inferior de la paleta de San Valentín
  glowColor: Color(0xFFFF4D7D), // halo rosa
  backgroundTint: Color(0x332A0A1E), // leve viñeta burdeos para legibilidad
  iconColor: Color(0xFFFF4D7D), // rosa
  iconShadows: [
    Shadow(color: Color(0xCC2A0A1E), blurRadius: 10),
    Shadow(color: Color(0x992A0A1E), blurRadius: 22),
  ],
  titleFontFamily: 'Hearrg',
  letterOutlineColor: Color.fromARGB(255, 219, 34, 80),
  letterOutlineWidth: 0.1,
  backgroundEffects: [
    valentinesBackEffect,
    valentinesGlowEffect,
    valentinesHeartsEffect,
    valentinesPetalsEffect,
  ],
  effects: [
    valentinesForegroundHeartsEffect,
    valentinesForegroundPetalsEffect,
  ],
);

// ---------------------------------------------------------------------------
// Fondo
// ---------------------------------------------------------------------------

/// `valentine_back` aparece por fundido y se queda como escenario.
Widget valentinesBackEffect(BuildContext context, double progress) {
  final t = Curves.easeOut.transform(
    ((progress - 0.08) / 0.35).clamp(0.0, 1.0),
  );
  if (t <= 0) return const SizedBox.shrink();
  return IgnorePointer(
    child: Opacity(
      opacity: t,
      child: Image.asset(
        _kValentinesBackAsset,
        fit: BoxFit.cover,
        // Si el asset aún no está disponible, no romper la presentación.
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    ),
  );
}

/// Brillo cálido del atardecer (parte inferior), con un pulso muy leve.
Widget valentinesGlowEffect(BuildContext context, double progress) {
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
            const Color(0xFFFF8FB1).withValues(alpha: 0.20 * pulse * appear),
            const Color(0x00FF8FB1),
          ],
          stops: const [0.0, 0.48],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Corazones
// ---------------------------------------------------------------------------

/// Corazones/pétalos flotando hacia arriba (capa de fondo), con deriva
/// lateral y varios tamaños.
Widget valentinesHeartsEffect(BuildContext context, double progress) {
  final appear = Curves.easeOut.transform((progress / 0.08).clamp(0.0, 1.0));
  return CustomPaint(
    painter: _HeartsPainter(
      progress: progress,
      appear: appear,
      count: 70,
      maxSize: 7.0,
      opacity: 0.85,
      seed: 21414,
    ),
  );
}

/// Capa de corazones grandes y tenues por delante del contenido: da profundidad.
Widget valentinesForegroundHeartsEffect(
  BuildContext context,
  double progress,
) {
  final appear = Curves.easeOut.transform((progress / 0.10).clamp(0.0, 1.0));
  return CustomPaint(
    painter: _HeartsPainter(
      progress: progress,
      appear: appear,
      count: 12,
      maxSize: 11.0,
      opacity: 0.30,
      seed: 14214,
    ),
  );
}

// ---------------------------------------------------------------------------
// Pétalos de rosa
// ---------------------------------------------------------------------------

/// Pétalos de rosa cayendo con deriva lateral y giro (capa de fondo).
/// Mantiene los corazones: es una capa adicional, no un sustituto.
Widget valentinesPetalsEffect(BuildContext context, double progress) {
  final appear = Curves.easeOut.transform((progress / 0.08).clamp(0.0, 1.0));
  return CustomPaint(
    painter: _PetalsPainter(
      progress: progress,
      appear: appear,
      count: 50,
      maxSize: 9.0,
      opacity: 0.9,
      seed: 21402,
    ),
  );
}

/// Pétalos grandes y tenues por delante del contenido: dan profundidad.
Widget valentinesForegroundPetalsEffect(
  BuildContext context,
  double progress,
) {
  final appear = Curves.easeOut.transform((progress / 0.10).clamp(0.0, 1.0));
  return CustomPaint(
    painter: _PetalsPainter(
      progress: progress,
      appear: appear,
      count: 10,
      maxSize: 14.0,
      opacity: 0.32,
      seed: 14202,
    ),
  );
}

/// Pétalo de rosa: elipse rotada con giro 3D simulado (escala X oscilante).
class _PetalsPainter extends CustomPainter {
  _PetalsPainter({
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
    for (var i = 0; i < count; i++) {
      final startY = rnd.nextDouble();
      final speed = 0.3 + rnd.nextDouble() * 0.7;
      final startX = rnd.nextDouble();
      final swayAmplitude = 0.01 + rnd.nextDouble() * 0.03;
      final swayFreq = 0.8 + rnd.nextDouble() * 1.2;
      final phase = rnd.nextDouble() * 2 * math.pi;
      final length = 3.0 + rnd.nextDouble() * (maxSize - 3.0);
      final alpha = opacity * (0.4 + rnd.nextDouble() * 0.6) * appear;
      // Caída con giro: el pétalo rota y se pliega (escala X oscilante).
      final rotation = phase + progress * 2 * math.pi * (0.5 + rnd.nextDouble());
      final fold = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi * (1.0 + rnd.nextDouble()) + phase));

      // Caída continua con wrap vertical.
      final wrappedY = (startY + speed * progress * 1.8) % 1.0;
      final y = ((wrappedY + 1.0) % 1.0) * size.height;
      // Deriva lateral suave.
      final x =
          (startX + swayAmplitude * math.sin(progress * 2 * math.pi * swayFreq + phase)) *
          size.width;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.scale(fold, 1.0);
      // Rojo/rosa con variación por partícula.
      final petal = switch (rnd.nextInt(3)) {
        0 => const Color(0xFFE91E63),
        1 => const Color(0xFFFF4D7D),
        _ => const Color(0xFFC2185B),
      };
      canvas.drawPath(
        _petalPath(length),
        Paint()..color = petal.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  /// Pétalo centrado en el origen: óvalo apuntado (largo `length`).
  Path _petalPath(double length) {
    final l = length;
    final w = length * 0.62;
    final path = Path();
    path.moveTo(0, -l / 2);
    path.cubicTo(w / 2, -l / 4, w / 2, l / 4, 0, l / 2);
    path.cubicTo(-w / 2, l / 4, -w / 2, -l / 4, 0, -l / 2);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _PetalsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.appear != appear ||
      oldDelegate.count != count ||
      oldDelegate.maxSize != maxSize ||
      oldDelegate.opacity != opacity ||
      oldDelegate.seed != seed;
}

class _HeartsPainter extends CustomPainter {
  _HeartsPainter({
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
    for (var i = 0; i < count; i++) {
      final startY = rnd.nextDouble();
      final speed = 0.25 + rnd.nextDouble() * 0.6;
      final startX = rnd.nextDouble();
      final swayAmplitude = 0.006 + rnd.nextDouble() * 0.022;
      final swayFreq = 1.2 + rnd.nextDouble() * 1.4;
      final phase = rnd.nextDouble() * 2 * math.pi;
      final radius = 1.6 + rnd.nextDouble() * (maxSize - 1.6);
      final alpha = opacity * (0.35 + rnd.nextDouble() * 0.65) * appear;
      final rotation = phase + progress * (0.6 + rnd.nextDouble() * 0.8);

      // Subida continua con wrap vertical (los corazones flotan hacia arriba).
      final wrappedY = (startY - speed * progress * 1.6) % 1.0;
      final y = ((wrappedY + 1.0) % 1.0) * size.height;
      // Deriva lateral suave.
      final x =
          (startX + swayAmplitude * math.sin(progress * 2 * math.pi * swayFreq + phase)) *
          size.width;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      final path = _heartPath(radius);
      // Rosa claro/rosa con algo de variación por partícula.
      final pink = rnd.nextDouble() < 0.5
          ? const Color(0xFFFF8FB1)
          : const Color(0xFFFF4D7D);
      canvas.drawPath(
        path,
        Paint()..color = pink.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  /// Corazón centrado en el origen, inscrito en un cuadrado de lado `size`.
  Path _heartPath(double size) {
    final s = size / 2;
    final path = Path();
    path.moveTo(0, s * 0.9);
    path.cubicTo(-s * 1.4, -s * 0.1, -s * 0.7, -s * 1.0, 0, -s * 0.35);
    path.cubicTo(s * 0.7, -s * 1.0, s * 1.4, -s * 0.1, 0, s * 0.9);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HeartsPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.appear != appear ||
      oldDelegate.count != count ||
      oldDelegate.maxSize != maxSize ||
      oldDelegate.opacity != opacity ||
      oldDelegate.seed != seed;
}
