/// Constantes globales de UI: tamaños de texto, separaciones y nº de
/// tarjetas visibles en carruseles. Un solo sitio para ajustar la
/// densidad visual de toda la app.
///
/// Los títulos de las filas del home usan su propio estilo centralizado
/// ([ScrollTitle]); el resto de cabeceras de sección usan [kSectionTitleFontSize].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/platform_mode.dart';

/// Factor de escala del mini-player por plataforma.
/// Un solo mapa para ajustar la densidad del mini sin tocar PC/móvil.
/// TV 1.4 → ~90px alto (64*1.4), cover ~67, iconos ~30; 1.35=86px, 1.5=96px.
double miniPlayerScaleFor(PlatformMode mode) => switch (mode) {
  PlatformMode.mobile => 1.0,
  PlatformMode.desktop => 1.3,
  PlatformMode.tv => 1.4,
};

/// Provider reactivo del factor: observa `platformModeProvider` y
/// cae a 1.0 mientras carga (evita parpadeo). Testeable con
/// `debugDeviceProvider = DebugDevice.tv`.
final miniPlayerScaleProvider = Provider<double>((ref) {
  final mode = ref.watch(platformModeProvider).value ?? PlatformMode.mobile;
  return miniPlayerScaleFor(mode);
});

/// Factor de escala de las tarjetas del Jukebox por plataforma.
/// TV necesita tarjetas más grandes para D-Pad/10-foot.
double jukeboxCardScaleFor(PlatformMode mode) => switch (mode) {
  PlatformMode.mobile => 1.0,
  PlatformMode.desktop => 1.2,
  PlatformMode.tv => 1.25,
};

final jukeboxCardScaleProvider = Provider<double>((ref) {
  final mode = ref.watch(platformModeProvider).value ?? PlatformMode.mobile;
  return jukeboxCardScaleFor(mode);
});

/// Tamaño único de los títulos de sección de música (Discografía,
/// Populares, Artistas relacionados...).
const double kSectionTitleFontSize = 24;

/// Hueco entre el título de una sección y el comienzo de su scroll.
const double kSectionTitleGap = 14;

/// Hueco entre el final de una sección y el título de la siguiente.
const double kBetweenSectionsGap = 32;

/// Tamaño del título dentro de las tarjetas ([MediaCard], discografía).
const double kCardTitleFontSize = 14;

/// Tamaño del subtítulo dentro de las tarjetas.
const double kCardSubtitleFontSize = 12;

/// Tamaño del texto de biografía (ficha de persona y sección
/// Información del artista): un solo valor para ambas.
const double kBioFontSize = 18;

/// Nº de tarjetas visibles sin desplazar en un carrusel horizontal,
/// según el ancho disponible (para controlar la densidad por resolución
/// de dispositivo sin tocar cada scroll).
int carouselVisibleCount(double viewportWidth) {
  if (viewportWidth < 600) return 2;
  if (viewportWidth < 1000) return 3;
  if (viewportWidth < 1400) return 4;
  return 6;
}

/// Ancho de tarjeta para que quepan [count] visibles (o las que toquen
/// por resolución si es nulo) con [sidePadding] lateral y [spacing]
/// entre tarjetas.
double cardWidthForCount(
  double viewportWidth, {
  required double sidePadding,
  required double spacing,
  int? count,
}) {
  final n = count ?? carouselVisibleCount(viewportWidth);
  if (n <= 0) return 160;
  return (viewportWidth - sidePadding * 2 - spacing * (n - 1)) / n;
}
