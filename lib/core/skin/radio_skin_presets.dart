library;

import 'package:material_ui/material_ui.dart';

import 'radio_skin.dart';

abstract final class RadioSkinPresets {
  static const fynitivDefault = RadioSkin(
    id: 'fynitiv_default',
    name: 'Fynitiv Radio',
    primary: Color(0xFF7C3AED),
    accent: Color(0xFF22D3EE),
    backgroundTop: Color(0xFF0F172A),
    backgroundBottom: Color(0xFF1E1B4B),
    cardBackground: Color(0xFF1E293B),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF94A3B8),
    cardRadius: 14,
    useGlass: true,
  );

  static const List<RadioSkin> all = [fynitivDefault];
}
