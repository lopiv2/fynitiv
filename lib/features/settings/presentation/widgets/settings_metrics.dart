import 'package:flutter/widgets.dart';

import '../../../../core/navigation/platform_mode.dart';

/// Navegación del shell de Ajustes según el ancho disponible.
enum SettingsNav { topChips, rail, sideMenu }

/// Tokens de densidad del shell de Ajustes.
///
/// Dos ejes independientes (ver FTD `settings-adaptativo`):
/// - **Ancho** → decide navegación y nº de columnas.
/// - **[PlatformMode.tv]** → decide densidad sea cual sea el ancho.
class SettingsMetrics {
  const SettingsMetrics({
    required this.nav,
    required this.isTv,
    required this.menuWidth,
    required this.contentMaxWidth,
    required this.pagePadding,
    required this.groupGap,
    required this.cardPadding,
    required this.pageTitleSize,
    required this.rowTitleSize,
    required this.rowSubtitleSize,
    required this.minRowHeight,
    required this.radius,
    required this.trailingWidth,
    required this.tvScale,
  });

  final SettingsNav nav;
  final bool isTv;
  final double menuWidth;
  final double contentMaxWidth;
  final EdgeInsets pagePadding;
  final double groupGap;
  final double cardPadding;
  final double pageTitleSize;
  final double rowTitleSize;
  final double rowSubtitleSize;
  final double minRowHeight;
  final double radius;
  final double trailingWidth;
  final double tvScale;

  /// Dos columnas lado a lado solo con mucho ancho (escritorio/TV ancha).
  bool get useTwoColumns => contentMaxWidth >= 1600 * 0.65;
}

/// Resuelve los tokens para el ancho/alto/modo dados.
///
/// [width]/[height] son píxeles lógicos (`MediaQuery.sizeOf`).
SettingsMetrics metricsFor({
  required double width,
  required double height,
  required PlatformMode mode,
}) {
  final isTv = mode == PlatformMode.tv;
  final SettingsNav nav;
  if (width < 600) {
    nav = SettingsNav.topChips;
  } else if (width < 1024) {
    nav = SettingsNav.rail;
  } else {
    nav = SettingsNav.sideMenu;
  }

  final tvScale = !isTv ? 1.0 : (height < 1000 ? 1.25 : 1.35);

  late final double menuWidth;
  late final double contentMaxWidth;
  late final EdgeInsets pagePadding;
  late final double groupGap;
  late final double cardPadding;
  late final double pageTitleSize;
  late final double rowTitleSize;
  late final double rowSubtitleSize;
  late final double minRowHeight;
  late final double radius;
  late final double trailingWidth;

  if (isTv) {
    // Overscan: 5 % del alto en horizontal (48–96), 32–56 en vertical.
    final hPad = (height * 0.05).clamp(48.0, 96.0);
    menuWidth = 320;
    contentMaxWidth = 960;
    pagePadding = EdgeInsets.symmetric(horizontal: hPad, vertical: 40);
    groupGap = 20;
    cardPadding = 24;
    pageTitleSize = height < 1000 ? 30 : 34;
    rowTitleSize = 19;
    rowSubtitleSize = 16;
    minRowHeight = 76;
    radius = 18;
    trailingWidth = 88;
  } else if (nav == SettingsNav.topChips) {
    menuWidth = 0;
    contentMaxWidth = (width - 32).clamp(280.0, 640.0);
    pagePadding = const EdgeInsets.all(16);
    groupGap = 12;
    cardPadding = 14;
    pageTitleSize = 22;
    rowTitleSize = 15;
    rowSubtitleSize = 12;
    minRowHeight = 64;
    radius = 12;
    trailingWidth = 56;
  } else if (nav == SettingsNav.rail) {
    menuWidth = 88;
    contentMaxWidth = 640;
    pagePadding = const EdgeInsets.all(24);
    groupGap = 16;
    cardPadding = 16;
    pageTitleSize = 24;
    rowTitleSize = 16;
    rowSubtitleSize = 13;
    minRowHeight = 68;
    radius = 14;
    trailingWidth = 64;
  } else {
    menuWidth = 264;
    contentMaxWidth = 720;
    pagePadding = const EdgeInsets.all(32);
    groupGap = 16;
    cardPadding = 18;
    pageTitleSize = 26;
    rowTitleSize = 16;
    rowSubtitleSize = 13;
    minRowHeight = 64;
    radius = 16;
    trailingWidth = 64;
  }

  return SettingsMetrics(
    nav: nav,
    isTv: isTv,
    menuWidth: menuWidth,
    contentMaxWidth: contentMaxWidth,
    pagePadding: pagePadding,
    groupGap: groupGap,
    cardPadding: cardPadding,
    pageTitleSize: pageTitleSize,
    rowTitleSize: rowTitleSize,
    rowSubtitleSize: rowSubtitleSize,
    minRowHeight: minRowHeight,
    radius: radius,
    trailingWidth: trailingWidth,
    tvScale: tvScale,
  );
}
