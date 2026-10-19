import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Un chorretón de nieve derretida dentro de [buildSnowDripPath].
class _SnowDrip {
  const _SnowDrip(this.center, this.halfWidth, this.length);

  final double center;
  final double halfWidth;
  final double length;
}

/// Construye el contorno de una capa de nieve derretida sobre [size].
///
/// Cubre la franja superior hasta [depth] (fracción de la altura) con un borde
/// inferior ondulado y [drips] chorretes que cuelgan. [seed] fija la forma de
/// manera determinista (misma forma en cada frame) y [melt] (0..1) alarga los
/// chorretes para animar el deshielo.
///
/// Se usa tanto para pintar la nieve de las tarjetas (`SnowCapPainter`) como
/// para recortar la nieve de las letras (`SnowDripClipper`).
Path buildSnowDripPath(
  Size size, {
  required int seed,
  double depth = 0.16,
  double dripMax = 0.14,
  int drips = 5,
  double melt = 0.0,
}) {
  final width = size.width;
  final height = size.height;
  final path = Path();
  if (width <= 0 || height <= 0) return path;

  final rnd = math.Random(seed);
  final baseY = (depth * height).clamp(0.0, height);

  // Chorretes: posición, anchura y longitud deterministas por semilla.
  final specs = <_SnowDrip>[];
  for (var i = 0; i < drips; i++) {
    final jitter = (rnd.nextDouble() - 0.5) * (0.7 / drips);
    final center = ((i + 0.5) / drips + jitter) * width;
    final halfWidth = width * (0.035 + rnd.nextDouble() * 0.05);
    final length =
        height *
        dripMax *
        (0.45 + rnd.nextDouble() * 0.8) *
        (0.75 + 0.5 * melt.clamp(0.0, 1.0));
    specs.add(_SnowDrip(center, halfWidth, length));
  }

  final phase = (seed % 17) * 0.37;

  path
    ..moveTo(0, 0)
    ..lineTo(width, 0)
    ..lineTo(width, baseY);

  // Borde inferior ondulado con los chorretes, de derecha a izquierda.
  const samples = 96;
  for (var i = samples; i >= 0; i--) {
    final x = width * i / samples;
    var y =
        baseY + math.sin(x / width * math.pi * 3.0 + phase) * height * 0.012;
    for (final drip in specs) {
      final dx = (x - drip.center) / drip.halfWidth;
      if (dx.abs() < 1) {
        final profile = math.pow(1 - dx * dx, 1.7).toDouble();
        y += drip.length * profile;
      }
    }
    path.lineTo(x, y);
  }

  path.close();
  return path;
}

/// Pinta una capa de nieve derretida: blanco arriba, azulado en las puntas y
/// una sombra azul difusa bajo el borde (hielo mojado).
class SnowCapPainter extends CustomPainter {
  const SnowCapPainter({
    required this.seed,
    this.melt = 0.0,
    this.depth = 0.10,
    this.dripMax = 0.13,
    this.drips = 4,
  });

  final int seed;
  final double melt;
  final double depth;
  final double dripMax;
  final int drips;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = buildSnowDripPath(
      size,
      seed: seed,
      depth: depth,
      dripMax: dripMax,
      drips: drips,
      melt: melt,
    );

    // Sombra/agua bajo la nieve.
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x66234063)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();

    // Nieve con gradiente blanco → azulado en las puntas.
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF2F8FF), Color(0xFFD6E9FF)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant SnowCapPainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.melt != melt ||
      oldDelegate.depth != depth ||
      oldDelegate.dripMax != dripMax ||
      oldDelegate.drips != drips;
}

/// Capa de nieve derretida no interactiva, pensada para superponerse a una
/// imagen (tarjetas).
class SnowCapOverlay extends StatelessWidget {
  const SnowCapOverlay({
    super.key,
    required this.seed,
    this.melt = 0.0,
    this.depth = 0.10,
    this.dripMax = 0.13,
    this.drips = 4,
  });

  final int seed;
  final double melt;
  final double depth;
  final double dripMax;
  final int drips;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: SnowCapPainter(
          seed: seed,
          melt: melt,
          depth: depth,
          dripMax: dripMax,
          drips: drips,
        ),
      ),
    );
  }
}

/// Recorta con la misma forma de nieve derretida (para las letras del logo).
class SnowDripClipper extends CustomClipper<Path> {
  const SnowDripClipper({
    required this.seed,
    this.melt = 0.0,
    this.depth = 0.30,
    this.dripMax = 0.14,
    this.drips = 3,
  });

  final int seed;
  final double melt;
  final double depth;
  final double dripMax;
  final int drips;

  @override
  Path getClip(Size size) => buildSnowDripPath(
    size,
    seed: seed,
    depth: depth,
    dripMax: dripMax,
    drips: drips,
    melt: melt,
  );

  @override
  bool shouldReclip(covariant SnowDripClipper oldClipper) =>
      oldClipper.seed != seed ||
      oldClipper.melt != melt ||
      oldClipper.depth != depth ||
      oldClipper.dripMax != dripMax ||
      oldClipper.drips != drips;
}
