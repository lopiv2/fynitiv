import 'package:material_ui/material_ui.dart';

import 'skin.dart';

/// Skins predefinidos.
abstract final class SkinPresets {
  /// Estilo actual: oscuro azul/púrpura.
  static const Skin jellyfinDefault = Skin(
    id: 'jellyfin_default',
    name: 'Jellyfin',
    primary: Color(0xFFAA5CC3),
    secondary: Color(0xFF2B7FFF),
    backgroundTop: Color(0xFF0B1030),
    backgroundBottom: Color(0xFF1A2568),
    sidebarBackground: Color(0xFF0A0E24),
    accent: Color(0xFF2B7FFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    sidebarLogo: 'assets/images/Logo_letter_jellyfinitive.png',
    sidebarWidth: 260,
    showContinueRow: true,
    showNewReleasesRow: true,
    cardBorderRadius: 10,
    sidebarCollapsible: true,
  );

  /// Estilo Disney+ (azul oscuro, acento celeste, textos claros).
  static const Skin disneyPlus = Skin(
    id: 'disney_plus',
    name: 'Disney+',
    primary: Color(0xFF0B1030),
    secondary: Color(0xFF1A2568),
    backgroundTop: Color(0xFF05080F),
    backgroundBottom: Color(0xFF0B1030),
    sidebarBackground: Color(0xFF03060B),
    accent: Color(0xFF00A0D1),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    sidebarLogo: 'assets/images/Logo_letter_jellyfinitive.png',
    logoPosition: LogoPosition.bottom,
    avatarPosition: LogoPosition.top,
    sidebarWidth: 260,
    sidebarHeaderSpacing: 24,
    navItemIconSpacing: 24,
    showContinueRow: true,
    showNewReleasesRow: true,
    showNewReleasesBanner: true,
    bannerBorder: true,
    bannerDotAlignment: SliderDotAlignment.right,
    bannerTransition: SliderTransition.slide,
    cardBorderRadius: 6,
    sidebarCollapsible: true,
  );

  /// Estilo Amazon Prime (azul oscuro casi negro, acento celeste "Prime").
  static const Skin amazonPrime = Skin(
    id: 'amazon_prime',
    name: 'Prime',
    primary: Color(0xFF00A8E1),
    secondary: Color(0xFF232F3E),
    backgroundTop: Color(0xFF0A0F14),
    backgroundBottom: Color(0xFF121A24),
    sidebarBackground: Color(0xFF070B0F),
    accent: Color(0xFF00A8E1),
    textPrimary: Colors.white,
    textSecondary: Color(0xB3FFFFFF),
    sidebarLogo: 'assets/images/Logo_letter_jellyfinitive.png',
    sidebarPosition: SidebarPosition.top,
    sidebarSelectedColor: Color(0xFF6B6B6B),
    sidebarWidth: 240,
    showContinueRow: true,
    cardImageType: CardImageType.backdrop,
    cardLogo: 'assets/images/jellyfin.png',
    cardLogoSize: 24,
    playerLogo: 'assets/images/jellyfin.png',
    showNewReleasesRow: true,
    showNewReleasesBanner: true,
    bannerLogoWidthFactor: 0.60,
    bannerShowArrows: true,
    bannerDotAlignment: SliderDotAlignment.center,
    bannerShowIncludedBadge: true,
    bannerShowJellyfinLogo: true,
    bannerHoverReveal: true,
    bannerShowActions: true,
    showTrailerInSlider: true,
    bannerTransition: SliderTransition.fade,
    bannerArrowsOnHover: true,
    bannerShowTitle: false,
    bannerAttachedTop: true,
    bannerShowAgeRating: true,
    bannerContentScale: 1.5,
    bannerHeightFactor: 0.5,
    bannerMaxHeight: 580,
    homeCardWidth: 350,
    homeRowHeight: 340,
    rowSpacing: 50,
    cardBorderRadius: 4,
    sidebarCollapsible: true,
    cardHoverExtension: true,
  );

  /// Estilo Movistar+ (oscuro, acento naranja/rojo).
  static const Skin movistarPlus = Skin(
    id: 'movistar_plus',
    name: 'Movistar+',
    primary: Color(0xFFFF6F00),
    secondary: Color(0xFF1B1B2F),
    backgroundTop: Color(0xFF0E0E1A),
    backgroundBottom: Color(0xFF1B1B2F),
    sidebarBackground: Color(0xFF0A0A14),
    accent: Color(0xFFFF6F00),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xB3FFFFFF),
    sidebarLogo: 'assets/images/Logo_letter_jellyfinitive.png',
    sidebarWidth: 260,
    showContinueRow: true,
    showNewReleasesRow: true,
    cardBorderRadius: 8,
    sidebarCollapsible: true,
  );

  static const List<Skin> all = [
    jellyfinDefault,
    disneyPlus,
    amazonPrime,
    movistarPlus,
  ];
}
