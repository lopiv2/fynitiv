import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/splash_presentation.dart';

const String _kEasterBackAsset = 'assets/images/seasonal/easter_back.jpg';

/// Presentación de Pascua: audio propio, paleta morada de la temática sobre la
/// noche de `easter_back`, fondo por fundido, brillo cálido del horizonte y
/// luciérnagas volando con parpadeo (deriva errática + halo).
const SplashPresentation kEasterSplashPresentation = SplashPresentation(
  id: 'easter',
  audioAsset: 'audio/easter_splash.mp3',
  backgroundAsset: 'assets/images/backgrounds/splash_back.png',
  letterStops: [
    Color(0xFFEDE7FF), // lavanda pálido (primera letra)
    Color(0xFF9C6BFF), // morado (acento de la paleta estacional)
    Color(0xFFFFB74D), // naranja cálido (primario, huevos iluminados)
  ],
  taglineColors: [
    Color(0xFFEDE7FF), // Watch.   — lavanda
    Color(0xFF9C6BFF), // Read.    — morado
    Color(0xFFFFD54D), // Play.    — oro (luces del prado)
    Color(0xFFFFB74D), // Anything — naranja cálido
  ],
  extrusionDark: Color(0xFF1A1030), // fondo superior de la paleta de Pascua
  extrusionLight: Color(0xFF5A3F8F), // fondo inferior de la paleta de Pascua
  glowColor: Color(0xFFFFD54D), // halo dorado
  backgroundTint: Color(0x331A1030), // leve noche morada
  iconColor: Color(0xFFFFD54D), // oro
  iconShadows: [
    Shadow(color: Color(0xCC1A1030), blurRadius: 10),
    Shadow(color: Color(0x991A1030), blurRadius: 22),
  ],
  titleFontFamily: 'Eggs',
  letterOutlineColor: Color.fromARGB(255, 194, 126, 207),
  letterOutlineWidth: 0.1,
  backgroundEffects: [
    easterBackEffect,
    easterGlowEffect,
    easterFirefliesEffect,
  ],
  effects: [easterForegroundFirefliesEffect],
);

// ---------------------------------------------------------------------------
// Fondo
// ---------------------------------------------------------------------------

/// `easter_back` aparece por fundido y se queda como escenario.
Widget easterBackEffect(BuildContext context, double progress) {
  final t = Curves.easeOut.transform(
    ((progress - 0.08) / 0.35).clamp(0.0, 1.0),
  );
  if (t <= 0) return const SizedBox.shrink();
  return IgnorePointer(
    child: Opacity(
      opacity: t,
      child: Image.asset(
        _kEasterBackAsset,
        fit: BoxFit.cover,
        // Si el asset aún no está disponible, no romper la presentación.
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    ),
  );
}

/// Brillo cálido del horizonte (parte inferior), con un pulso muy leve.
Widget easterGlowEffect(BuildContext context, double progress) {
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
// Luciérnagas
// ---------------------------------------------------------------------------

/// Enjambre de luciérnagas volando (capa de fondo): deriva errática con
/// parpadeo propio por insecto.
Widget easterFirefliesEffect(BuildContext context, double progress) {
  final appear = Curves.easeOut.transform((progress / 0.08).clamp(0.0, 1.0));
  return CustomPaint(
    painter: _FirefliesPainter(
      progress: progress,
      appear: appear,
      count: 70,
      maxSize: 3.4,
      opacity: 0.9,
      seed: 40414,
    ),
  );
}

/// Luciérnagas grandes y tenues por delante del contenido: dan profundidad.
Widget easterForegroundFirefliesEffect(
  BuildContext context,
  double progress,
) {
  final appear = Curves.easeOut.transform((progress / 0.10).clamp(0.0, 1.0));
  return CustomPaint(
    painter: _FirefliesPainter(
      progress: progress,
      appear: appear,
      count: 12,
      maxSize: 6.0,
      opacity: 0.32,
      seed: 41404,
    ),
  );
}

class _FirefliesPainter extends CustomPainter {
  _FirefliesPainter({
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
      final baseX = rnd.nextDouble();
      final baseY = rnd.nextDouble();
      final driftX = 0.02 + rnd.nextDouble() * 0.05;
      final driftY = 0.015 + rnd.nextDouble() * 0.04;
      final freqX = 0.8 + rnd.nextDouble() * 1.6;
      final freqY = 0.7 + rnd.nextDouble() * 1.4;
      final phaseX = rnd.nextDouble() * 2 * math.pi;
      final phaseY = rnd.nextDouble() * 2 * math.pi;
      // Vuelo continuo: avance lento + vaivén errático.
      final travel = (progress * (0.25 + rnd.nextDouble() * 0.4) + rnd.nextDouble()) % 1.0;
      final wrappedTravel = (travel + 1.0) % 1.0;
      final radius = 1.2 + rnd.nextDouble() * (maxSize - 1.2);
      // Parpadeo propio: cada luciérnaga late a su ritmo.
      final blinkSpeed = 1.5 + rnd.nextDouble() * 2.5;
      final blink = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi * blinkSpeed + phaseX * 3));
      final alpha = opacity * blink * appear;

      final x =
          ((baseX + wrappedTravel * driftX * 8 +
                      0.03 * math.sin(progress * 2 * math.pi * freqX + phaseX)) %
                  1.0) *
              size.width;
      final y =
          ((baseY +
                      0.04 * math.sin(progress * 2 * math.pi * freqY + phaseY) -
                      wrappedTravel * driftY * 4) %
                  1.0) *
              size.height;
      // Normaliza el módulo negativo de Dart.
      final nx = ((x / size.width % 1.0) + 1.0) % 1.0 * size.width;
      final ny = ((y / size.height % 1.0) + 1.0) % 1.0 * size.height;
      final pos = Offset(nx, ny);

      // Halo tenue + núcleo cálido.
      canvas.drawCircle(
        pos,
        radius * 3.2,
        Paint()..color = const Color(0xFFFFD54D).withValues(alpha: alpha * 0.22),
      );
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FirefliesPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.appear != appear ||
      oldDelegate.count != count ||
      oldDelegate.maxSize != maxSize ||
      oldDelegate.opacity != opacity ||
      oldDelegate.seed != seed;
}
