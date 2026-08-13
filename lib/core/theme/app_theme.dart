import 'package:material_ui/material_ui.dart';

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
}
