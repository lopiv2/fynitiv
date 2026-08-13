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
  static ThemeData fromSkin(Skin skin, {Brightness brightness = Brightness.dark}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: skin.primary,
      brightness: brightness,
    ).copyWith(
      secondary: skin.secondary,
      primary: skin.primary,
    );
    return ThemeData(
      colorScheme: scheme,
      fontFamily: skin.fontFamily,
    );
  }
}
