import 'package:jellyfin_dart/jellyfin_dart.dart';

import 'skin.dart';

/// Estilo de cabecera de la página de detalle.
enum DetailHeaderStyle {
  /// Backdrop a pantalla completa con degradado (Prime).
  backdrop,

  /// Portada lateral + info (listas densas).
  cover,

  /// Solo título y acciones, sin imagen.
  minimal,
}

/// Secciones componibles de la página de detalle, en orden de pintado.
enum DetailSection {
  /// Cabecera: imagen, logo, título, géneros/año/nota y acciones principales.
  header,

  /// Pestañas Detalles/Relacionado (Prime).
  tabs,

  /// Tarjeta de sinopsis y metadatos (ISBN, archivo, idioma...).
  synopsis,

  /// Tarjeta de créditos (reparto, directores, autores...).
  credits,

  /// Contenido propio del tipo: episodios, pistas, temporadas, filmografía.
  media,

  /// Fila de relacionados.
  related,

  /// Extras: audio, subtítulos, descargas, temas.
  extras,
}

/// Configuración declarativa de la página de detalle, como [HomeScroll] para
/// las filas: qué se muestra y en qué orden. Cada pantalla la interpreta en
/// la fase 2; aquí solo vive el modelo y el resolver.
class DetailLayout {
  const DetailLayout({
    this.headerStyle = DetailHeaderStyle.backdrop,
    this.showLogo = true,
    this.showActions = true,
    this.showGenres = true,
    this.showYear = true,
    this.showRating = true,
    this.showOverview = true,
    this.showCredits = true,
    this.showMedia = true,
    this.showRelated = true,
    this.showExtras = true,
    this.showTabs = true,
    this.sections = const [
      DetailSection.header,
      DetailSection.tabs,
      DetailSection.synopsis,
      DetailSection.credits,
      DetailSection.media,
      DetailSection.related,
      DetailSection.extras,
    ],
  });

  final DetailHeaderStyle headerStyle;
  final bool showLogo;
  final bool showActions;
  final bool showGenres;
  final bool showYear;
  final bool showRating;
  final bool showOverview;
  final bool showCredits;
  final bool showMedia;
  final bool showRelated;
  final bool showExtras;
  final bool showTabs;
  final List<DetailSection> sections;

  DetailLayout copyWith({
    DetailHeaderStyle? headerStyle,
    bool? showLogo,
    bool? showActions,
    bool? showGenres,
    bool? showYear,
    bool? showRating,
    bool? showOverview,
    bool? showCredits,
    bool? showMedia,
    bool? showRelated,
    bool? showExtras,
    bool? showTabs,
    List<DetailSection>? sections,
  }) {
    return DetailLayout(
      headerStyle: headerStyle ?? this.headerStyle,
      showLogo: showLogo ?? this.showLogo,
      showActions: showActions ?? this.showActions,
      showGenres: showGenres ?? this.showGenres,
      showYear: showYear ?? this.showYear,
      showRating: showRating ?? this.showRating,
      showOverview: showOverview ?? this.showOverview,
      showCredits: showCredits ?? this.showCredits,
      showMedia: showMedia ?? this.showMedia,
      showRelated: showRelated ?? this.showRelated,
      showExtras: showExtras ?? this.showExtras,
      showTabs: showTabs ?? this.showTabs,
      sections: sections ?? this.sections,
    );
  }
}

/// Layout base Prime: todo visible, con pestañas.
const kPrimeDetailLayout = DetailLayout();

/// Libros/cómics: sin pistas de audio/subtítulos ni temporadas; la ficha
/// trae serie, autores, editorial, ISBN, idioma y archivo como extras.
/// El orden replica la composición actual (cabecera, pestañas, relacionados,
/// sinopsis+créditos) para paridad visual total.
const kBookDetailLayout = DetailLayout(
  sections: [
    DetailSection.header,
    DetailSection.tabs,
    DetailSection.related,
    DetailSection.synopsis,
    DetailSection.credits,
    DetailSection.extras,
  ],
);

/// Series: el cuerpo propio son temporadas/episodios; Disney usa su
/// composición dedicada.
const kSeriesDetailLayout = DetailLayout();

/// Música (canciones, álbumes, artistas): pistas/artistas como medio,
/// sin extras de audio/subtítulos ni pestañas.
const kMusicDetailLayout = DetailLayout(
  showTabs: false,
  sections: [
    DetailSection.header,
    DetailSection.synopsis,
    DetailSection.credits,
    DetailSection.media,
    DetailSection.related,
  ],
);

/// Personas: filmografía como medio, sin créditos ni extras.
const kPersonDetailLayout = DetailLayout(
  showCredits: false,
  showExtras: false,
  showTabs: false,
  sections: [
    DetailSection.header,
    DetailSection.synopsis,
    DetailSection.media,
    DetailSection.related,
  ],
);

/// Layout efectivo del detalle para [kind] con el skin [skin].
///
/// Fase 1: presets por tipo; el único ajuste por skin es el cuerpo dedicado
/// de series Disney+ (paridad con el comportamiento actual).
DetailLayout detailLayoutFor({Skin? skin, BaseItemKind? kind}) {
  final base = switch (kind) {
    BaseItemKind.book => kBookDetailLayout,
    BaseItemKind.series => kSeriesDetailLayout,
    BaseItemKind.audio ||
    BaseItemKind.musicAlbum ||
    BaseItemKind.musicArtist ||
    BaseItemKind.audioBook => kMusicDetailLayout,
    BaseItemKind.person => kPersonDetailLayout,
    _ => kPrimeDetailLayout,
  };
  // Disney+ compone las series con su propio cuerpo (sin pestañas Prime).
  if (kind == BaseItemKind.series && skin?.id == 'disney_plus') {
    return base.copyWith(showTabs: false);
  }
  return base;
}
