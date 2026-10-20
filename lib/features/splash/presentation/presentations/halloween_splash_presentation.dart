import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../domain/splash_presentation.dart';

const String _kBatAsset = 'assets/images/seasonal/bat_fly.webp';

/// Imagen de fondo propia de Halloween: aparece justo después del relámpago.
const String _kHalloweenBackAsset =
    'assets/images/seasonal/halloween_back.webp';

/// Instante (progreso 0..1) del relámpago; el flash es inmediato y la imagen
/// `halloween_back` aparece justo después.
const double _kLightningAt = 0.55;

/// Presentación de Halloween: audio propio, paleta naranja/morado, luna y
/// niebla de fondo, relámpago con flash —tras el que aparece `halloween_back`—
/// y bandadas de murciélagos.
const SplashPresentation kHalloweenSplashPresentation = SplashPresentation(
  id: 'halloween',
  audioAsset: 'audio/halloween_splash_reveal.mp3',
  backgroundAsset: 'assets/images/backgrounds/splash_back.png',
  letterStops: [
    Color(0xFFFFE0B2), // naranja pálido (primera letra)
    Color(0xFFFF7A1A), // naranja (acento de la paleta estacional)
    Color(0xFF7E3FF2), // morado (primario de la paleta estacional)
  ],
  taglineColors: [
    Color(0xFFFFE0B2), // Watch.
    Color(0xFFFF7A1A), // Read.
    Color(0xFFB06EFF), // Play.
    Color(0xFF7E3FF2), // Anything
  ],
  extrusionDark: Color(0xFF1A0B2E), // fondo superior de la paleta de Halloween
  extrusionLight: Color(0xFF7A1E0E), // fondo inferior de la paleta de Halloween
  glowColor: Color(0xFFFF7A1A),
  // `halloween_back` es una imagen clara: el icono del tagline (∞ incluido)
  // usa el naranja de la paleta + sombra oscura para no desaparecer sobre ella.
  iconColor: Color(0xFFFF7A1A),
  backgroundTint: Color(0x661A0B2E), // viñeta morada oscura
  iconShadows: [
    Shadow(color: Color(0xDD1A0B2E), blurRadius: 10),
    Shadow(color: Color(0xAA2A0A3E), blurRadius: 24),
  ],
  backgroundEffects: [
    halloweenBackEffect,
    halloweenFogEffect,
    halloweenMoonEffect,
  ],
  effects: [halloweenBatsEffect, halloweenLightningEffect],
);

// ---------------------------------------------------------------------------
// Imagen de fondo `halloween_back`
// ---------------------------------------------------------------------------

/// Aparece tras el flash del relámpago y se queda como fondo de la escena.
Widget halloweenBackEffect(BuildContext context, double progress) {
  final t = Curves.easeOut.transform(
    ((progress - (_kLightningAt + 0.03)) / 0.12).clamp(0.0, 1.0),
  );
  if (t <= 0) return const SizedBox.shrink();
  return IgnorePointer(
    child: Opacity(
      opacity: t,
      child: Image.asset(
        _kHalloweenBackAsset,
        fit: BoxFit.cover,
        // Si el asset aún no está disponible, no romper la presentación.
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Niebla
// ---------------------------------------------------------------------------

/// Bandas de niebla que se arrastran lentamente a distintas alturas.
Widget halloweenFogEffect(BuildContext context, double progress) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final appear = Curves.easeOut.transform(
        ((progress - 0.02) / 0.22).clamp(0.0, 1.0),
      );
      if (appear <= 0) return const SizedBox.shrink();
      return IgnorePointer(
        child: Opacity(
          opacity: appear,
          child: Stack(
            children: [
              _fogBand(
                width: width,
                height: height,
                y: 0.72,
                color: const Color(0xFFB39DDB),
                opacity: 0.11,
                progress: progress,
                speed: 0.10,
                direction: 1,
              ),
              _fogBand(
                width: width,
                height: height,
                y: 0.84,
                color: const Color(0xFFFFCC80),
                opacity: 0.09,
                progress: progress,
                speed: 0.16,
                direction: -1,
              ),
              _fogBand(
                width: width,
                height: height,
                y: 0.04,
                color: const Color(0xFF7E3FF2),
                opacity: 0.08,
                progress: progress,
                speed: 0.07,
                direction: 1,
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _fogBand({
  required double width,
  required double height,
  required double y,
  required Color color,
  required double opacity,
  required double progress,
  required double speed,
  required double direction,
}) {
  final bandHeight = height * 0.30;
  // Deriva continua y cíclica para que nunca se quede quieta.
  final cycle = (progress * speed * 3.0) % 1.0;
  final translate = (-0.25 + 0.5 * cycle) * direction;
  return Positioned(
    top: y * height - bandHeight / 2,
    left: -width * 0.3,
    width: width * 1.6,
    height: bandHeight,
    child: FractionalTranslation(
      translation: Offset(translate, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Luna
// ---------------------------------------------------------------------------

/// Luna pálida con halo arriba a la derecha, con una leve deriva.
Widget halloweenMoonEffect(BuildContext context, double progress) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      final appear = Curves.easeOut.transform(
        (progress / 0.14).clamp(0.0, 1.0),
      );
      // La luna se apaga con el relámpago: cuando el flash revela el fondo
      // blanco ya no pinta nada y chocaría con los murciélagos en primer plano.
      final vanish = Curves.easeOut.transform(
        ((progress - (_kLightningAt - 0.03)) / 0.06).clamp(0.0, 1.0),
      );
      final moonAlpha = appear * (1.0 - vanish);
      if (moonAlpha <= 0) return const SizedBox.shrink();

      final size = (height * 0.26).clamp(110.0, 300.0);
      final drift = math.sin(progress * 2 * math.pi * 0.25);
      final left = width * 0.72 + drift * 14;
      final top = height * 0.07 + drift * 8;

      return IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Opacity(
                opacity: 0.92 * moonAlpha,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Halo.
                      Container(
                        width: size * 2.1,
                        height: size * 2.1,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0x55FFE9B0).withValues(alpha: 0.45 * moonAlpha),
                              const Color(0x00FFE9B0),
                            ],
                          ),
                        ),
                      ),
                      // Disco.
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0xFFFFF7E0), Color(0xFFFFE7AE)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x88FFD98A),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      // Cráteres (textura sutil).
                      Positioned(
                        left: size * 0.24,
                        top: size * 0.30,
                        child: _crater(size * 0.20),
                      ),
                      Positioned(
                        left: size * 0.52,
                        top: size * 0.18,
                        child: _crater(size * 0.12),
                      ),
                      Positioned(
                        left: size * 0.44,
                        top: size * 0.58,
                        child: _crater(size * 0.16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _crater(double diameter) {
  return Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFE9CE8F).withValues(alpha: 0.55),
    ),
  );
}

// ---------------------------------------------------------------------------
// Relámpago + flash
// ---------------------------------------------------------------------------

/// Relámpago: un rayo dibujado y, en el mismo instante, un flash de pantalla.
Widget halloweenLightningEffect(BuildContext context, double progress) {
  final pulse = _lightningPulse(progress);
  if (pulse <= 0.001) return const SizedBox.shrink();
  return Stack(
    fit: StackFit.expand,
    children: [
      // Flash inmediato (detrás del rayo).
      Opacity(
        opacity: (pulse * 0.72).clamp(0.0, 1.0),
        child: const ColoredBox(color: Color(0xFFEAF2FF)),
      ),
      Positioned.fill(
        child: CustomPaint(painter: _BoltPainter(pulse: pulse)),
      ),
    ],
  );
}

/// Doble destello (rayo principal + parpadeo), con subida rápida y caída
/// exponencial, en progreso 0..1.
double _lightningPulse(double t) {
  final main = _spike(t, _kLightningAt, 0.010, 0.075);
  final echo = _spike(t, _kLightningAt + 0.045, 0.008, 0.055) * 0.55;
  return (main + echo).clamp(0.0, 1.0);
}

double _spike(double t, double center, double rise, double decay) {
  final d = t - center;
  if (d <= -rise || d >= decay) return 0;
  if (d <= 0) return (d + rise) / rise; // subida
  return math.exp(-d / (decay * 0.30)); // caída exponencial
}

/// Rayo zigzagueante, más realista: canal principal con muchas desviaciones,
/// varias ramas y sub-ramas, con grosor decreciente de raíz a punta (halo,
/// brillo medio y núcleo blanco). La geometría se genera con una semilla fija
/// para que sea estable en todos los frames del destello.
class _BoltPainter extends CustomPainter {
  const _BoltPainter({required this.pulse});

  final double pulse;

  /// Semilla fija: el mismo rayo en cada frame (no parpadea ni tiembla).
  static const int _seed = 20251031;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bolt = _buildBolt(size);
    final rootWidth = (size.width * 0.0042).clamp(2.0, 9.0);

    // Ramas primero (más finas y tenues), luego el canal principal encima.
    for (final branch in bolt.branches) {
      _drawGlow(canvas, branch, rootWidth * 0.55, rootWidth * 0.12, 0.5);
    }
    _drawGlow(canvas, bolt.main, rootWidth, rootWidth * 0.16, 1.0);

    // Filamento blanco finísimo sobre el núcleo del canal principal.
    _drawSegments(
      canvas,
      bolt.main,
      (t) => math.max(0.7, rootWidth * (0.45 - 0.35 * t)),
      Colors.white.withValues(alpha: 0.95 * pulse),
      blur: 0,
    );
  }

  /// Dibuja un trazo con tres capas (halo, brillo medio y núcleo) cuyo grosor
  /// decrece de raíz a punta. [scale] atenúa las ramas respecto al canal.
  void _drawGlow(
    Canvas canvas,
    List<Offset> points,
    double rootWidth,
    double tipWidth,
    double scale,
  ) {
    double widthAt(double t) =>
        math.max(0.6, rootWidth + (tipWidth - rootWidth) * t);

    _drawSegments(
      canvas,
      points,
      (t) => widthAt(t) * 7.0,
      const Color(0xFF7FB4FF).withValues(alpha: 0.22 * pulse * scale),
      blur: 22,
    );
    _drawSegments(
      canvas,
      points,
      (t) => widthAt(t) * 2.3,
      const Color(0xFFBBD8FF).withValues(alpha: 0.60 * pulse * scale),
      blur: 6,
    );
    _drawSegments(
      canvas,
      points,
      widthAt,
      Colors.white.withValues(alpha: 0.98 * pulse * scale),
      blur: 0,
    );
  }

  /// Dibuja la polilínea segmento a segmento para poder variar el grosor con
  /// [widthAt] (0 = raíz, 1 = punta).
  void _drawSegments(
    Canvas canvas,
    List<Offset> points,
    double Function(double t) widthAt,
    Color color, {
    double blur = 0,
  }) {
    if (points.length < 2) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    if (blur > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    }
    final segments = points.length - 1;
    for (var i = 0; i < segments; i++) {
      paint.strokeWidth = widthAt(i / segments);
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  /// Genera el canal principal (zigzag vertical con muchas desviaciones) y sus
  /// ramas con sub-ramas, todo con un `Random` de semilla fija.
  _Bolt _buildBolt(Size size) {
    final rnd = math.Random(_seed);
    final centerX = size.width * 0.60;
    final bottomY = size.height * 0.68;
    final segments = 16;

    final main = <Offset>[Offset(centerX + (rnd.nextDouble() - 0.5) * 10, -size.height * 0.03)];
    for (var i = 1; i <= segments; i++) {
      final t = i / segments;
      final y = bottomY * t;
      // Zigzag irregular + leve atracción hacia el centro para que no se vaya.
      final prev = main.last.dx;
      final jitter = (rnd.nextDouble() - 0.5) * size.width * 0.055;
      final pull = (centerX - prev) * 0.18;
      main.add(Offset(prev + jitter + pull, y));
    }

    final branches = <List<Offset>>[];
    final branchCount = 9;
    for (var b = 0; b < branchCount; b++) {
      final startIndex = 1 + rnd.nextInt(main.length - 2);
      final direction = rnd.nextBool() ? 1.0 : -1.0;
      branches.add(_growBranch(rnd, size, main[startIndex], direction, 3 + rnd.nextInt(4)));
      // Sub-rama: nace a mitad de algunas ramas, con dirección opuesta.
      if (rnd.nextDouble() < 0.7) {
        final parent = branches.last;
        if (parent.length > 2) {
          final from = parent[1 + rnd.nextInt(parent.length - 2)];
          branches.add(_growBranch(rnd, size, from, -direction, 2 + rnd.nextInt(2)));
        }
      }
    }
    return _Bolt(main, branches);
  }

  /// Crecimiento de una rama: pasos hacia un lado con caída vertical irregular.
  List<Offset> _growBranch(
    math.Random rnd,
    Size size,
    Offset start,
    double direction,
    int steps,
  ) {
    final points = <Offset>[start];
    var p = start;
    for (var s = 0; s < steps; s++) {
      p = Offset(
        p.dx + direction * size.width * (0.02 + rnd.nextDouble() * 0.055),
        p.dy + size.height * (0.025 + rnd.nextDouble() * 0.05),
      );
      points.add(p);
    }
    return points;
  }

  @override
  bool shouldRepaint(covariant _BoltPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}

/// Geometría de un rayo: canal principal y ramas.
class _Bolt {
  const _Bolt(this.main, this.branches);

  final List<Offset> main;
  final List<List<Offset>> branches;
}

// ---------------------------------------------------------------------------
// Bandadas de murciélagos
// ---------------------------------------------------------------------------

/// Bandadas de murciélagos cruzando la pantalla durante la revelación.
///
/// Efecto puro del progreso 0..1: cada bandada es una nube de murciélagos
/// repartidos de forma uniforme pero desigual (espiral de ángulo áureo con
/// radio/ángulo irregulares por murciélago) que entra, cruza oscilando y sale;
/// cada uno lleva un pequeño remolque, aletea con su propio desfase y varía de
/// tamaño y opacidad. Sin estado ni controllers propios.
Widget halloweenBatsEffect(BuildContext context, double progress) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.maxHeight;
      return Stack(
        children: [
          for (final flock in _kFlocks)
            _buildFlock(flock, width, height, progress),
        ],
      );
    },
  );
}

/// Una bandada: cuándo entra, cómo cruza y cuánto se dispersa.
class _FlockSpec {
  const _FlockSpec({
    required this.delay,
    required this.travel,
    required this.y,
    required this.amplitude,
    required this.oscillations,
    required this.phase,
    required this.count,
    required this.spreadX,
    required this.spreadY,
    required this.size,
    this.flip = false,
  });

  /// Retardo de entrada, en progreso 0..1.
  final double delay;

  /// Duración del cruce, en progreso 0..1.
  final double travel;

  /// Altura base del centro (fracción de la altura).
  final double y;

  /// Amplitud de la oscilación vertical de la bandada (fracción de altura).
  final double amplitude;

  /// Nº de oscilaciones verticales a lo largo del cruce.
  final double oscillations;

  /// Desfase de la oscilación.
  final double phase;

  /// Nº de murciélagos de la bandada.
  final int count;

  /// Radio de dispersión horizontal de la nube (px).
  final double spreadX;

  /// Radio de dispersión vertical de la nube (px).
  final double spreadY;

  /// Anchura de referencia de un murciélago (px lógicos); cada uno varía algo.
  final double size;

  /// Voltea los sprites de la bandada.
  final bool flip;
}

/// Cuatro bandadas a distintas alturas y momentos, con tamaños decrecientes.
const List<_FlockSpec> _kFlocks = [
  _FlockSpec(
    delay: 0.05,
    travel: 0.52,
    y: 0.18,
    amplitude: 0.04,
    oscillations: 1.4,
    phase: 0.0,
    count: 20,
    spreadX: 200,
    spreadY: 130,
    size: 58,
  ),
  _FlockSpec(
    delay: 0.16,
    travel: 0.56,
    y: 0.70,
    amplitude: 0.05,
    oscillations: 1.1,
    phase: 1.7,
    count: 16,
    spreadX: 160,
    spreadY: 105,
    size: 50,
    flip: true,
  ),
  _FlockSpec(
    delay: 0.30,
    travel: 0.52,
    y: 0.44,
    amplitude: 0.05,
    oscillations: 1.8,
    phase: 3.3,
    count: 13,
    spreadX: 125,
    spreadY: 85,
    size: 40,
  ),
  _FlockSpec(
    delay: 0.42,
    travel: 0.48,
    y: 0.86,
    amplitude: 0.04,
    oscillations: 1.6,
    phase: 4.8,
    count: 9,
    spreadX: 95,
    spreadY: 62,
    size: 30,
    flip: true,
  ),
];

/// Pseudo-aleatorio determinista y estable por índice (0..1): mismo reparto en
/// cada frame, sin parpadeos.
double _hash01(int n) {
  var x = (n * 1103515245 + 12345) & 0x7fffffff;
  x ^= x >> 13;
  x = (x * 1274126177) & 0x7fffffff;
  x ^= x >> 11;
  return (x & 0xffff) / 0xffff;
}

Widget _buildFlock(
  _FlockSpec flock,
  double width,
  double height,
  double progress,
) {
  final local = (progress - flock.delay) / flock.travel;
  if (local <= 0 || local >= 1) return const SizedBox.shrink();

  // Centro de la bandada: cruza de fuera a fuera y oscila en vertical.
  final centerX = (-0.22 + local * 1.44) * width;
  final centerY =
      (flock.y +
          flock.amplitude *
              math.sin(local * 2 * math.pi * flock.oscillations + flock.phase)) *
      height;
  // La bandada completa se desvanece al entrar y al salir.
  final fade = math
      .min(1.0, math.min(local / 0.12, (1 - local) / 0.12))
      .clamp(0.0, 1.0);

  return Stack(
    children: [
      for (var i = 0; i < flock.count; i++)
        _buildFlockMember(flock, i, centerX, centerY, local, fade),
    ],
  );
}

Widget _buildFlockMember(
  _FlockSpec flock,
  int index,
  double centerX,
  double centerY,
  double local,
  double fade,
) {
  // Reparto uniforme (espiral de ángulo áureo) con radio y ángulo irregulares
  // por murciélago: cubre la bandada de forma pareja pero desigual, sin
  // formación fija.
  const golden = 2.399963229728653;
  final r1 = _hash01(index * 2 + 1);
  final r2 = _hash01(index * 7 + 3);
  final r3 = _hash01(index * 13 + 5);
  final angle = index * golden + r1 * 1.4;
  final spread = math.sqrt((index + 0.6) / flock.count);
  final radius = (0.35 + 0.65 * r2) * spread;
  final dx = math.cos(angle) * radius * flock.spreadX;
  final dy = math.sin(angle) * radius * flock.spreadY;

  // Remolque: los murciélagos más alejados del centro van algo por detrás, así
  // el grupo se lee como bandada en movimiento y no como un bloque rígido.
  final lag = 0.004 + 0.02 * radius;
  final memberLocal = (local - lag).clamp(0.0, 1.0);

  // Aleteo rápido y propio de cada murciélago.
  final flap = 0.28 * math.sin(memberLocal * 2 * math.pi * 6.0 + index * 1.3);
  // Pequeño cabeceo adicional para que la bandada no sea rígida.
  final bob = 2.5 * math.sin(memberLocal * 2 * math.pi * 3.0 + index * 0.9);

  final x = centerX + dx;
  final y = centerY + dy + bob;
  final opacity = (fade * (0.78 + 0.22 * r3)).clamp(0.0, 1.0);
  final batSize = flock.size * (0.68 + 0.5 * r3);
  final flipBat = flock.flip ^ index.isOdd;

  return Positioned(
    left: x,
    top: y,
    child: IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scaleX: flipBat ? -1 : 1,
          child: Transform.rotate(
            angle: flap,
            child: Image.asset(
              _kBatAsset,
              width: batSize,
              fit: BoxFit.contain,
              // En tests/hot reload el asset puede no estar disponible aún;
              // no romper la presentación por ello.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ),
  );
}
