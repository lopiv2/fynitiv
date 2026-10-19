import 'package:material_ui/material_ui.dart';

import '../skin/skin.dart';

/// Temáticas de calendario que pueden destacarse temporalmente en Inicio y
/// matizar la paleta del skin.
enum SeasonalEvent { halloween, christmas, valentinesDay, easter }

/// Devuelve la temática activa para la fecha local del dispositivo.
SeasonalEvent? seasonalEventForDate(DateTime date) {
  final halloweenStart = DateTime(date.year, 10);
  if (!date.isBefore(halloweenStart) &&
      date.isBefore(DateTime(date.year, 11))) {
    return SeasonalEvent.halloween;
  }

  final christmasStart = DateTime(date.year, 12);
  if (!date.isBefore(christmasStart) || (date.month == 1 && date.day <= 6)) {
    return SeasonalEvent.christmas;
  }

  final valentinesStart = DateTime(date.year, 2);
  if (!date.isBefore(valentinesStart) &&
      date.isBefore(DateTime(date.year, 2, 15))) {
    return SeasonalEvent.valentinesDay;
  }

  final easter = _westernEasterSunday(date.year);
  final easterStart = easter.subtract(const Duration(days: 14));
  final easterEnd = easter.add(const Duration(days: 2));
  if (!date.isBefore(easterStart) && date.isBefore(easterEnd)) {
    return SeasonalEvent.easter;
  }

  return null;
}

/// Colores de una temática estacional usados para teñir el skin activo.
@immutable
class SeasonalPalette {
  const SeasonalPalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.accent,
    required this.primary,
    this.strength = 1.0,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color accent;
  final Color primary;

  /// Multiplicador de la intensidad elegida por el usuario. Permite que una
  /// temática tenga más presencia (p. ej. Navidad) sin tocar las demás.
  final double strength;
}

/// Ruta del asset (webp) del badge de la temática (esquina de las tarjetas).
String seasonalBadgeAsset(SeasonalEvent event) => switch (event) {
  SeasonalEvent.halloween => 'assets/images/seasonal/halloween.webp',
  SeasonalEvent.christmas => 'assets/images/seasonal/tree.webp',
  SeasonalEvent.valentinesDay => 'assets/images/seasonal/valentines.webp',
  SeasonalEvent.easter => 'assets/images/seasonal/easter.webp',
};

/// Paleta por temática: fondo (arriba/abajo), acento y primario.
const Map<SeasonalEvent, SeasonalPalette> kSeasonalPalettes = {
  SeasonalEvent.halloween: SeasonalPalette(
    backgroundTop: Color(0xFF1A0B2E),
    backgroundBottom: Color(0xFF7A1E0E),
    accent: Color(0xFFFF7A1A),
    primary: Color(0xFF7E3FF2),
  ),
  SeasonalEvent.christmas: SeasonalPalette(
    // Verde bosque profundo → rojo profundo, con primario verde vivo y acento
    // oro. Un refuerzo moderado permite reconocer Navidad sobre skins
    // azules/morados sin sustituir por completo la identidad del skin.
    backgroundTop: Color(0xFF0A2C22),
    backgroundBottom: Color(0xFFB71C1C),
    accent: Color(0xFFFFC107),
    primary: Color(0xFF00C853),
    strength: 1.5,
  ),
  SeasonalEvent.valentinesDay: SeasonalPalette(
    backgroundTop: Color(0xFF2A0A1E),
    backgroundBottom: Color(0xFF7A0E32),
    accent: Color(0xFFFF4D7D),
    primary: Color(0xFFE91E63),
  ),
  SeasonalEvent.easter: SeasonalPalette(
    backgroundTop: Color(0xFF1A1030),
    backgroundBottom: Color(0xFF5A3F8F),
    accent: Color(0xFF9C6BFF),
    primary: Color(0xFFFFB74D),
  ),
};

/// Devuelve una copia del [base] con fondo, acento y primario mezclados hacia
/// la paleta de [event] en la proporción [intensity] (0 = sin cambio, 1 =
/// totalmente estacional). No modifica el skin persistido del usuario.
Skin tintSkinForSeason(Skin base, SeasonalEvent event, double intensity) {
  final palette = kSeasonalPalettes[event];
  if (palette == null || intensity <= 0) return base;
  // La fuerza propia de la temática multiplica la intensidad del usuario.
  final t = (intensity * palette.strength).clamp(0.0, 1.0);
  Color mix(Color from, Color to) => Color.lerp(from, to, t)!;
  return base.copyWith(
    backgroundTop: mix(base.backgroundTop, palette.backgroundTop),
    backgroundBottom: mix(base.backgroundBottom, palette.backgroundBottom),
    accent: mix(base.accent, palette.accent),
    primary: mix(base.primary, palette.primary),
  );
}

/// Fecha de Pascua occidental según el calendario gregoriano.
DateTime _westernEasterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}
