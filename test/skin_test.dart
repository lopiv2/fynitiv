import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fynitiv/core/skin/skin.dart';

void main() {
  test('Skin se serializa y deserializa con logoPosition', () {
    const original = Skin(
      id: 'test',
      name: 'Test',
      primary: Color(0xFF112233),
      secondary: Color(0xFF445566),
      backgroundTop: Color(0xFF0B1030),
      backgroundBottom: Color(0xFF1A2568),
      sidebarBackground: Color(0xFF0A0E24),
      accent: Color(0xFF2B7FFF),
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xB3FFFFFF),
      sidebarLogo: 'assets/images/Logo_fynitiv.png',
      logoPosition: LogoPosition.bottom,
      avatarPosition: AvatarPosition.bottom,
      sidebarPosition: SidebarPosition.right,
      sidebarWidth: 280,
      cardBorderRadius: 6,
    );

    final json = jsonEncode(original.toJson());
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final restored = Skin.fromJson(decoded);

    expect(restored.id, 'test');
    expect(restored.logoPosition, LogoPosition.bottom);
    expect(restored.avatarPosition, AvatarPosition.bottom);
    expect(restored.sidebarPosition, SidebarPosition.right);
    expect(restored.sidebarWidth, 280);
    expect(restored.sidebarLogo, 'assets/images/Logo_fynitiv.png');
  });

  test('Skin fromJson usa valores por defecto si faltan', () {
    final skin = Skin.fromJson({'id': 'min'});
    expect(skin.logoPosition, LogoPosition.top);
    expect(skin.sidebarPosition, SidebarPosition.left);
    expect(skin.sidebarWidth, 260);
  });

  test('Skin parses las posiciones top/bottom de la barra', () {
    expect(Skin.fromJson({'id': 't', 'sidebarPosition': 'top'}).sidebarPosition,
        SidebarPosition.top);
    expect(
        Skin.fromJson({'id': 'b', 'sidebarPosition': 'bottom'}).sidebarPosition,
        SidebarPosition.bottom);
    expect(Skin.fromJson({'id': 'r', 'sidebarPosition': 'right'}).sidebarPosition,
        SidebarPosition.right);
  });
}
