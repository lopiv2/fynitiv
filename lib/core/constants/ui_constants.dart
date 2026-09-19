/// Constantes globales de UI: tamaños de texto, separaciones y nº de
/// tarjetas visibles en carruseles. Un solo sitio para ajustar la
/// densidad visual de toda la app.
///
/// Los títulos de las filas del home usan su propio estilo centralizado
/// ([ScrollTitle]); el resto de cabeceras de sección usan [kSectionTitleFontSize].
library;

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
