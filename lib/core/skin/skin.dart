import 'package:material_ui/material_ui.dart';

/// Posición de la barra lateral en el dashboard.
enum SidebarPosition { left, right }

/// Posición del logo dentro de la barra lateral.
enum LogoPosition { top, bottom }

/// Posición del avatar de usuario dentro de la barra lateral.
typedef AvatarPosition = LogoPosition;

/// Skin: define colores, logos, layout y tipografía de la app.
class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.sidebarBackground,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    this.sidebarLogo,
    this.splashLogo,
    this.logoPosition = LogoPosition.top,
    this.avatarPosition = LogoPosition.top,
    this.sidebarPosition = SidebarPosition.left,
    this.sidebarWidth = 260,
    this.showContinueRow = true,
    this.showNewReleasesRow = true,
    this.cardBorderRadius = 10,
    this.sidebarCollapsible = true,
    this.fontFamily,
  });

  final String id;
  final String name;

  // Paleta.
  final Color primary;
  final Color secondary;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color sidebarBackground;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  // Logos (null → usar texto del nombre de la app).
  final String? sidebarLogo;
  final String? splashLogo;

  /// Dónde ubicar el logo dentro de la barra lateral.
  final LogoPosition logoPosition;

  /// Dónde ubicar el avatar de usuario dentro de la barra lateral.
  final AvatarPosition avatarPosition;

  // Layout.
  final SidebarPosition sidebarPosition;
  final double sidebarWidth;
  final bool showContinueRow;
  final bool showNewReleasesRow;
  final double cardBorderRadius;
  final bool sidebarCollapsible;

  // Tipografía.
  final String? fontFamily;

  Skin copyWith({
    String? id,
    String? name,
    Color? primary,
    Color? secondary,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? sidebarBackground,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    String? sidebarLogo,
    String? splashLogo,
    LogoPosition? logoPosition,
    AvatarPosition? avatarPosition,
    SidebarPosition? sidebarPosition,
    double? sidebarWidth,
    bool? showContinueRow,
    bool? showNewReleasesRow,
    double? cardBorderRadius,
    bool? sidebarCollapsible,
    String? fontFamily,
    bool clearSidebarLogo = false,
  }) {
    return Skin(
      id: id ?? this.id,
      name: name ?? this.name,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      sidebarLogo:
          clearSidebarLogo ? null : (sidebarLogo ?? this.sidebarLogo),
      splashLogo: splashLogo ?? this.splashLogo,
      logoPosition: logoPosition ?? this.logoPosition,
      avatarPosition: avatarPosition ?? this.avatarPosition,
      sidebarPosition: sidebarPosition ?? this.sidebarPosition,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      showContinueRow: showContinueRow ?? this.showContinueRow,
      showNewReleasesRow: showNewReleasesRow ?? this.showNewReleasesRow,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      sidebarCollapsible: sidebarCollapsible ?? this.sidebarCollapsible,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  // --- JSON ---

  factory Skin.fromJson(Map<String, dynamic> json) {
    return Skin(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      primary: _colorFromString(json['primary'] as String? ?? ''),
      secondary: _colorFromString(json['secondary'] as String? ?? ''),
      backgroundTop: _colorFromString(json['backgroundTop'] as String? ?? ''),
      backgroundBottom:
          _colorFromString(json['backgroundBottom'] as String? ?? ''),
      sidebarBackground:
          _colorFromString(json['sidebarBackground'] as String? ?? ''),
      accent: _colorFromString(json['accent'] as String? ?? ''),
      textPrimary: _colorFromString(json['textPrimary'] as String? ?? ''),
      textSecondary: _colorFromString(json['textSecondary'] as String? ?? ''),
      sidebarLogo: json['sidebarLogo'] as String?,
      splashLogo: json['splashLogo'] as String?,
      logoPosition: _logoPositionFromString(json['logoPosition'] as String?),
      avatarPosition:
          _logoPositionFromString(json['avatarPosition'] as String?),
      sidebarPosition: json['sidebarPosition'] == 'right'
          ? SidebarPosition.right
          : SidebarPosition.left,
      sidebarWidth: (json['sidebarWidth'] as num?)?.toDouble() ?? 260,
      showContinueRow: json['showContinueRow'] as bool? ?? true,
      showNewReleasesRow: json['showNewReleasesRow'] as bool? ?? true,
      cardBorderRadius:
          (json['cardBorderRadius'] as num?)?.toDouble() ?? 10,
      sidebarCollapsible: json['sidebarCollapsible'] as bool? ?? true,
      fontFamily: json['fontFamily'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primary': _colorToString(primary),
        'secondary': _colorToString(secondary),
        'backgroundTop': _colorToString(backgroundTop),
        'backgroundBottom': _colorToString(backgroundBottom),
        'sidebarBackground': _colorToString(sidebarBackground),
        'accent': _colorToString(accent),
        'textPrimary': _colorToString(textPrimary),
        'textSecondary': _colorToString(textSecondary),
        if (sidebarLogo != null) 'sidebarLogo': sidebarLogo,
        if (splashLogo != null) 'splashLogo': splashLogo,
        'logoPosition': logoPosition.name,
        'avatarPosition': avatarPosition.name,
        'sidebarPosition':
            sidebarPosition == SidebarPosition.right ? 'right' : 'left',
        'sidebarWidth': sidebarWidth,
        'showContinueRow': showContinueRow,
        'showNewReleasesRow': showNewReleasesRow,
        'cardBorderRadius': cardBorderRadius,
        'sidebarCollapsible': sidebarCollapsible,
        if (fontFamily != null) 'fontFamily': fontFamily,
      };

  static Color _colorFromString(String s) {
    final hex = s.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16) ?? 0xFF000000;
    return Color(value);
  }

  static LogoPosition _logoPositionFromString(String? s) {
    return s == 'bottom' ? LogoPosition.bottom : LogoPosition.top;
  }

  static String _colorToString(Color c) {
    final argb = (c.toARGB32() & 0xFFFFFFFF);
    return '#${argb.toRadixString(16).padLeft(8, '0')}';
  }
}
