library;

import 'package:material_ui/material_ui.dart';

class RadioSkin {
  const RadioSkin({
    required this.id,
    required this.name,
    required this.primary,
    required this.accent,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    this.cardRadius = 12,
    this.useGlass = true,
  });

  final String id;
  final String name;
  final Color primary;
  final Color accent;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color cardBackground;
  final Color textPrimary;
  final Color textSecondary;
  final double cardRadius;
  final bool useGlass;

  RadioSkin copyWith({
    String? id,
    String? name,
    Color? primary,
    Color? accent,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? cardBackground,
    Color? textPrimary,
    Color? textSecondary,
    double? cardRadius,
    bool? useGlass,
  }) {
    return RadioSkin(
      id: id ?? this.id,
      name: name ?? this.name,
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      cardBackground: cardBackground ?? this.cardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      cardRadius: cardRadius ?? this.cardRadius,
      useGlass: useGlass ?? this.useGlass,
    );
  }

  factory RadioSkin.fromJson(Map<String, dynamic> json) {
    return RadioSkin(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      primary: _colorFromString(json['primary'] as String? ?? ''),
      accent: _colorFromString(json['accent'] as String? ?? ''),
      backgroundTop: _colorFromString(json['backgroundTop'] as String? ?? ''),
      backgroundBottom: _colorFromString(json['backgroundBottom'] as String? ?? ''),
      cardBackground: _colorFromString(json['cardBackground'] as String? ?? ''),
      textPrimary: _colorFromString(json['textPrimary'] as String? ?? ''),
      textSecondary: _colorFromString(json['textSecondary'] as String? ?? ''),
      cardRadius: (json['cardRadius'] as num?)?.toDouble() ?? 12,
      useGlass: json['useGlass'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primary': _colorToString(primary),
        'accent': _colorToString(accent),
        'backgroundTop': _colorToString(backgroundTop),
        'backgroundBottom': _colorToString(backgroundBottom),
        'cardBackground': _colorToString(cardBackground),
        'textPrimary': _colorToString(textPrimary),
        'textSecondary': _colorToString(textSecondary),
        'cardRadius': cardRadius,
        'useGlass': useGlass,
      };

  static Color _colorFromString(String s) {
    final hex = s.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16) ?? 0xFF000000;
    return Color(value);
  }

  static String _colorToString(Color c) {
    final argb = (c.toARGB32() & 0xFFFFFFFF);
    return '#${argb.toRadixString(16).padLeft(8, '0')}';
  }
}
