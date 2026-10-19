import 'package:material_ui/material_ui.dart';

import '../skin/skin.dart';

abstract final class AppTheme {
  static const Color jellyfinPurple = Color(0xFFAA5CC3);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: jellyfinPurple,
      brightness: brightness,
    );
    return ThemeData(colorScheme: scheme);
  }

  /// Tema derivado de la paleta de un [Skin].
  ///
  /// El primario crudo del skin (y su mezcla estacional) puede ser demasiado
  /// oscuro para los fondos del dashboard: los botones rellenos, el texto de
  /// `OutlinedButton`/`TextButton`, chips y sliders dejarían de leerse. Se
  /// aclara conservando el tono y se calcula su color "on" por luminancia,
  /// porque el de la semilla no corresponde al color sobrescrito.
  static ThemeData fromSkin(
    Skin skin, {
    Brightness brightness = Brightness.dark,
  }) {
    final primary = _visibleOnDark(skin.primary);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: skin.primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: _onColor(primary),
          secondary: skin.secondary,
          onSecondary: _onColor(skin.secondary),
        );
    return ThemeData(
      colorScheme: scheme,
      fontFamily: skin.fontFamily,
      switchTheme: _switchTheme(primary),
    );
  }

  /// Estilo de los switches con track/pulgar de contraste garantizado sobre el
  /// fondo oscuro, sea cual sea la estación y su intensidad.
  static SwitchThemeData _switchTheme(Color primary) {
    final trackOn = primary;
    final thumbOn = trackOn.computeLuminance() > 0.5
        ? const Color(0xFF10131C)
        : Colors.white;
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.white.withValues(alpha: 0.38);
        }
        return states.contains(WidgetState.selected)
            ? thumbOn
            : Colors.white.withValues(alpha: 0.9);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.white.withValues(alpha: 0.12);
        }
        return states.contains(WidgetState.selected)
            ? trackOn
            : Colors.white.withValues(alpha: 0.24);
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return Colors.white.withValues(
          alpha: states.contains(WidgetState.disabled) ? 0.12 : 0.4,
        );
      }),
    );
  }

  /// Aclara [color] conservando su tono hasta que su luminancia relativa sea
  /// suficiente para leerse sobre los fondos oscuros del dashboard.
  static Color _visibleOnDark(Color color) {
    const minLuminance = 0.2;
    if (color.computeLuminance() >= minLuminance) return color;
    var hsl = HSLColor.fromColor(color);
    while (hsl.lightness < 1.0) {
      hsl = hsl.withLightness((hsl.lightness + 0.05).clamp(0.0, 1.0));
      if (hsl.toColor().computeLuminance() >= minLuminance) break;
    }
    return hsl.toColor();
  }

  /// Color de contenido (texto/icono) que contrasta con [background].
  static Color _onColor(Color background) =>
      background.computeLuminance() > 0.18
      ? const Color(0xFF10131C)
      : Colors.white;
}
