import '../../l10n/app_localizations.dart';

/// Posición de la barra lateral en el dashboard.
enum SidebarPosition { left, top, right, bottom }

/// Posición del logo dentro de la barra lateral.
enum LogoPosition { top, bottom }

/// Posición del avatar de usuario dentro de la barra lateral.
typedef AvatarPosition = LogoPosition;

/// Posición de los puntos de navegación del slider de novedades.
enum SliderDotAlignment { left, center, right }

/// Posición del logotipo superpuesto en el reproductor.
enum LogoOverlayPosition { none, topLeft, topRight, bottomLeft, bottomRight }

/// Tipo de imagen de las tarjetas de las filas de contenido: póster vertical
/// (2:3) o backdrop horizontal (16:9).
enum CardImageType { poster, backdrop }

/// Efecto de la animación de onda del reproductor de audio.
enum AudioWaveformEffect {
  equalizer,
  wave,
  mirror,
  bars,
  surfer,
  audioFlux,
  frequency,
  ledSpectrum,
  soundEclipse,
  soundSinus,
  raymarching,
  smokeRings,
  circularSpectrum,
}

/// Tipo de transición entre banners del slider de novedades.
enum SliderTransition { slide, fade }

/// Lados donde se dibuja la viñeta del featured slider.
/// - left/right/top/bottom: solo ese borde, con grosor [Skin.bannerVignetteSize].
/// - around: composición completa (radial + degradados, aspecto previo).
enum SliderVignetteMode { left, right, top, bottom, around }

/// Categoría de descubrimiento de Seerr (pestaña "Descubrir"). Cada valor se
/// resuelve contra la API de Seerr.
enum SeerrDiscoverCategory {
  /// Tendencias (películas + series).
  trending,

  /// Películas populares.
  popularMovies,

  /// Próximas películas (estrenos).
  upcomingMovies,

  /// Series populares.
  popularTv,

  /// Próximas series.
  upcomingTv,
}

/// Tipo de sección configurable para Home y VOD (unificado).
/// Cada valor representa un bloque que aparece en el dashboard.
/// El orden en el array `Skin.homeLayout` / `Skin.vodLayout` define el orden
/// de arriba a abajo en la pantalla. Si el layout está vacío, se usa el orden
/// legado de cada pantalla.
///
/// - featuredSlider: carrusel de novedades (banner grande). Solo si hay items.
/// - continueWatching: fila “Continuar viendo”.
/// - nextUp: fila “A continuación” (siguientes episodios).
/// - recent: expande a una fila por cada biblioteca con `recentIn`
///   (ordenados por fecha de creación). En Home aplica a
///   Música/Películas/Series/Libros; en VOD a las vistas VOD.
/// - newReleases: fila “Novedades” en formato posters (cuando no hay banner).
/// - library: expande a una fila por cada biblioteca (título = nombre de la
///   vista, orden por nombre o por `scroll.sort`).
/// - custom: fila filtrada por géneros/tipos definida en [HomeScroll].
/// - seasonal: fila de sugerencias estacionales (aparece solo en fechas
///   temáticas y si la preferencia está activa; vacía el resto del año).
enum LayoutSectionType {
  featuredSlider,
  continueWatching,
  nextUp,
  recent,
  newReleases,
  library,
  custom,
  seasonal,
  upcoming,

  /// Fila de descubrimiento de Seerr (pestaña "Descubrir"). La categoría va en
  /// [LayoutSection.seerrCategory].
  seerrDiscover,
}

/// División del VOD en pantallas por tipo de contenido.
/// - movies: solo películas (`/vod/movies`).
/// - series: solo series (`/vod/series`).
enum VodSplit { movies, series }

/// Estilo de la barra superior (modular por skin, como los [LayoutSection]
/// de Inicio/VOD). Cada skin elige cómo se dibuja su topbar sin tocar la
/// pantalla que la usa.
/// - classic: barra fija con logo + items + bibliotecas + ajustes + avatar.
/// - netflix: avatar con desplegable a la izquierda, nav centrada con
///   píldora blanca en el activo y logo de marca a la derecha.
/// - prime: como classic pero navegación solo-texto (sin iconos) y Buscar
///   como lupa a la derecha, pegada a Ajustes.
enum TopBarStyle { classic, netflix, prime }

/// Item de navegación configurable de la topbar estilo Netflix.
/// El orden en `Skin.topBarNavItems` define el orden de izquierda a derecha.
/// - search: icono que abre la rama de búsqueda.
/// - home: rama de Inicio.
/// - shows: biblioteca de series (se oculta si no existe).
/// - movies: biblioteca de películas (se oculta si no existe).
/// - books: rama de libros (E-Reader).
/// - liveTv: rama de TV/Radio en directo.
/// - games: rama de juegos.
/// - seerr: página de descubrimiento y peticiones Seerr.
/// - myNetflix: biblioteca general (Mi Netflix: mi contenido).
enum TopBarNavItem {
  search,
  home,
  shows,
  movies,
  books,
  liveTv,
  games,
  seerr,
  myNetflix,
}

/// Origen de imagen para un scroll (configurable por scroll).
enum RowImageSource { primary, thumb, backdrop }

/// Posición del logo overlay en un scroll (stack). Meta siempre abajo.
enum RowLogoPosition { top, center, bottom }

/// Alineación horizontal del meta overlay sobre la imagen.
enum RowMetaAlign { left, center, right }

/// Fila de contenido configurable por skin: un título y filtros que deciden
/// qué elementos se muestran (géneros y tipos). Permite customizar los scrolls
/// de cada skin sin tocar código de pantalla.
enum HomeScrollCardType { poster, backdrop }

/// Títulos de fila conocidos (solo etiqueta, sin cadenas ni filtros).
/// El filtrado lo hacen siempre `genres` ([JellyGenre]) y `types` de
/// [HomeScroll]: `titleKey` únicamente elige la cadena traducida.
/// Usa `titleKey: HomeScrollTitle.actionMovies` (sin cadenas).
enum HomeScrollTitle {
  continueWatching,
  nextUp,
  newReleases,
  library,
  seasonal,

  /// Comodín para claves libres (se muestra tal cual).
  custom,
  actionMovies,
  familyMovies,
  romanticMovies,
  animationMovies,
  realities,
  animeSeries,
  nostalgia,
  dramas,
  comedies,
  actionAdventure,
  musicals,
  foodCooking,
  travel,
  sciFi,
  western,
  crime,
  horror,
  superHero;

  /// Clave usada en `HomeScroll.titleKey`.
  String get key => name;

  /// Traduce el título (`custom` devuelve [customTitle] si no está vacío,
  /// si no la clave tal cual).
  static String resolve(
    AppLocalizations l10n,
    HomeScrollTitle title, [
    String? customTitle,
  ]) {
    switch (title) {
      case HomeScrollTitle.continueWatching:
        return l10n.continueWatching;
      case HomeScrollTitle.nextUp:
        return l10n.upNext;
      case HomeScrollTitle.newReleases:
        return l10n.newReleases;
      case HomeScrollTitle.library:
        return l10n.library;
      case HomeScrollTitle.custom:
        final free = customTitle?.trim() ?? '';
        return free.isEmpty ? title.key : free;
      case HomeScrollTitle.actionMovies:
        return l10n.actionMovies;
      case HomeScrollTitle.familyMovies:
        return l10n.familyMovies;
      case HomeScrollTitle.romanticMovies:
        return l10n.romanticMovies;
      case HomeScrollTitle.animationMovies:
        return l10n.animationMovies;
      case HomeScrollTitle.realities:
        return l10n.realities;
      case HomeScrollTitle.animeSeries:
        return l10n.animeSeries;
      case HomeScrollTitle.nostalgia:
        return l10n.nostalgia;
      case HomeScrollTitle.dramas:
        return l10n.dramas;
      case HomeScrollTitle.comedies:
        return l10n.comedies;
      case HomeScrollTitle.actionAdventure:
        return l10n.actionAdventure;
      case HomeScrollTitle.musicals:
        return l10n.musicals;
      case HomeScrollTitle.foodCooking:
        return l10n.foodCooking;
      case HomeScrollTitle.travel:
        return l10n.travel;
      case HomeScrollTitle.sciFi:
        return l10n.sciFi;
      case HomeScrollTitle.western:
        return l10n.western;
      case HomeScrollTitle.crime:
        return l10n.crime;
      case HomeScrollTitle.horror:
        return l10n.horror;
      case HomeScrollTitle.superHero:
        return l10n.superHero;
      case HomeScrollTitle.seasonal:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}

/// Qué hace pulsar una tarjeta de la fila:
/// - play: reproduce directamente (comportamiento actual).
/// - details: abre la pantalla de detalle del item (y de ahí su lógica).
enum HomeScrollTapAction { play, details }

/// Géneros de Jellyfin como enum para evitar misspellings en los presets.
/// `value` es el nombre principal que devuelve la API (ej. 'Action');
/// `aliases` cubre variantes del servidor (ej. sciFi = Science Fiction,
/// Sci-Fi, SciFi): el filtro OR los incluye todos.
/// úsalo así: `genres: [JellyGenre.action, JellyGenre.animation]`.
enum JellyGenre {
  action('Action'),
  adventure('Adventure'),
  animation('Animation'),
  anime('Anime'),
  biography('Biography'),
  comedy('Comedy'),
  crime('Crime'),
  documentary('Documentary'),
  drama('Drama'),
  family('Family'),
  fantasy('Fantasy'),
  history('History'),
  horror('Horror'),
  kids('Kids', ['Children']),
  music('Music'),
  musical('Musical'),
  mystery('Mystery'),
  reality('Reality'),
  romance('Romance'),
  sciFi('Science Fiction', ['Sci-Fi', 'SciFi']),
  short('Short'),
  sport('Sport'),
  superhero('Superhero'),
  suspense('Suspense'),
  thriller('Thriller'),
  war('War'),
  western('Western');

  const JellyGenre(this.value, [this.aliases = const []]);

  /// Nombre principal que usa Jellyfin (se guarda en el JSON del skin).
  final String value;

  /// Variantes del servidor que también deben coincidir.
  final List<String> aliases;

  /// Principal + alias (para el filtro OR de la API).
  List<String> get allValues => [value, ...aliases];

  static final Map<String, JellyGenre> _byValue = {
    for (final g in JellyGenre.values)
      for (final v in g.allValues) v: g,
  };

  /// Resuelve el enum desde el nombre de la API, alias incluidos
  /// (`null` si no existe).
  static JellyGenre? fromValue(String? value) =>
      value == null ? null : _byValue[value];
}

/// Orden de los elementos de un scroll de biblioteca (series/películas).
/// - alphabetical: orden alfabético (SortName asc)
/// - recent: más recientes por fecha de estreno (PremiereDate desc)
/// - rating: mejor valoradas (CommunityRating desc)
/// - added: recientemente añadidas al catálogo (DateCreated desc) – por defecto actual
/// - random: orden aleatorio (cada carga muestra películas diferentes)
enum HomeScrollSort { alphabetical, recent, rating, added, random }

/// Géneros que cada título de scroll custom trae por defecto.
/// El título mostrado (traducido vía ARB) y el contenido filtrado van así
/// siempre acordes: elegir "Comedias" filtra comedia. Los títulos sin
/// correspondencia directa en [JellyGenre] (nostalgia, cocina, viajes) traen
/// lista vacía y sus géneros se fijan a mano.
const Map<HomeScrollTitle, List<JellyGenre>> defaultGenresForTitle = {
  HomeScrollTitle.actionMovies: [JellyGenre.action],
  HomeScrollTitle.familyMovies: [
    JellyGenre.animation,
    JellyGenre.family,
    JellyGenre.kids,
  ],
  HomeScrollTitle.romanticMovies: [JellyGenre.romance],
  HomeScrollTitle.animationMovies: [JellyGenre.animation],
  HomeScrollTitle.realities: [JellyGenre.reality],
  HomeScrollTitle.animeSeries: [JellyGenre.anime],
  HomeScrollTitle.nostalgia: [],
  HomeScrollTitle.dramas: [JellyGenre.drama],
  HomeScrollTitle.comedies: [JellyGenre.comedy],
  HomeScrollTitle.actionAdventure: [JellyGenre.action, JellyGenre.adventure],
  HomeScrollTitle.musicals: [JellyGenre.musical, JellyGenre.music],
  HomeScrollTitle.foodCooking: [],
  HomeScrollTitle.travel: [],
  HomeScrollTitle.sciFi: [JellyGenre.sciFi],
  HomeScrollTitle.western: [JellyGenre.western],
  HomeScrollTitle.crime: [
    JellyGenre.crime,
    JellyGenre.mystery,
    JellyGenre.suspense,
    JellyGenre.thriller,
  ],
  HomeScrollTitle.horror: [JellyGenre.horror],
  HomeScrollTitle.superHero: [JellyGenre.superhero],
};

/// Título cuyo [defaultGenresForTitle] coincide exactamente con [genres]
/// (sin importar el orden), o `null` si es una combinación libre.
HomeScrollTitle? titleForGenres(Set<JellyGenre> genres) {
  if (genres.isEmpty) return null;
  for (final entry in defaultGenresForTitle.entries) {
    final defaults = entry.value;
    if (defaults.isEmpty || defaults.length != genres.length) continue;
    if (genres.containsAll(defaults)) return entry.key;
  }
  return null;
}

/// Une principal + alias de varios géneros para el filtro OR (`|`) de la API.
String jellyGenresFilter(Iterable<JellyGenre> genres) =>
    genres.expand((g) => g.allValues).join('|');
