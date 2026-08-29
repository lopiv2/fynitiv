import 'package:material_ui/material_ui.dart';

import '../domain/romm_platform.dart';

/// Color neón LED por plataforma – random determinista por `id/slug`.
/// Cada plataforma obtiene un hue estable (hash -> HSL) para no tener que
/// mantener un mapa manual. Así Atari 2600/5200/7800/Jaguar etc. ya no
/// comparten naranja.
Color platformLedColor(
  RommPlatform platform, {
  Color fallback = const Color(0xFF2B7FFF),
}) {
  // Si no hay id/slug útil, fallback
  final raw = '${platform.id}:${platform.slug}:${platform.name}'.trim();
  if (raw.isEmpty || raw == '0::') return fallback;

  // Hash estable tipo djb2 sobre el raw
  var hash = 5381;
  for (final c in raw.codeUnits) {
    hash = ((hash << 5) + hash + c) & 0x7fffffff;
  }
  // Mezcla con id para dispersión extra
  hash = (hash ^ platform.id.hashCode) & 0x7fffffff;

  // Evita tonos marrones/grises apagados: fuerza saturación alta y luminosidad media
  // Hue 0-360, s 0.78-0.95, l 0.52-0.62 (neón vivo)
  final hue = (hash % 360).toDouble();
  final sat = 0.78 + (hash % 17) / 100; // 0.78-0.94
  final light = 0.52 + ((hash >> 8) % 10) / 100; // 0.52-0.61

  // Conversión HSL -> RGB (sin necesidad de paquete extra)
  final c = (1 - (2 * light - 1).abs()) * sat;
  final x = c * (1 - ((hue / 60) % 2 - 1).abs());
  final m = light - c / 2;
  double r1, g1, b1;
  if (hue < 60) {
    r1 = c;
    g1 = x;
    b1 = 0;
  } else if (hue < 120) {
    r1 = x;
    g1 = c;
    b1 = 0;
  } else if (hue < 180) {
    r1 = 0;
    g1 = c;
    b1 = x;
  } else if (hue < 240) {
    r1 = 0;
    g1 = x;
    b1 = c;
  } else if (hue < 300) {
    r1 = x;
    g1 = 0;
    b1 = c;
  } else {
    r1 = c;
    g1 = 0;
    b1 = x;
  }
  final r = ((r1 + m) * 255).round().clamp(0, 255);
  final g = ((g1 + m) * 255).round().clamp(0, 255);
  final b = ((b1 + m) * 255).round().clamp(0, 255);

  // Evita colores demasiado oscuros por luminancia baja accidental
  final col = Color.fromARGB(0xFF, r, g, b);
  // Si por hash sale gris muy desaturado (raro por sat alta), fallback a neón
  if (r == g && g == b) return fallback;
  return col;
}
