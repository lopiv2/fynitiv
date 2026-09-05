import 'package:flutter/foundation.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../l10n/app_localizations.dart';

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

  /// Traduce el título (`custom` se devuelve tal cual).
  static String resolve(AppLocalizations l10n, HomeScrollTitle title) {
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
        return title.key;
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
    }
  }
}

/// Qué hace pulsar una tarjeta de la fila:
/// - play: reproduce directamente (comportamiento actual).
/// - details: abre la pantalla de detalle del item (y de ahí su lógica).
enum HomeScrollTapAction { play, details }

/// Géneros de Jellyfin como enum para evitar misspellings en los presets.
/// `value` es el nombre exacto que devuelve la API (ej. 'Action', 'Sci-Fi'):
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
  kids('Kids'),
  music('Music'),
  musical('Musical'),
  mystery('Mystery'),
  reality('Reality'),
  romance('Romance'),
  sciFi('Sci-Fi'),
  short('Short'),
  sport('Sport'),
  superhero('Superhero'),
  suspense('Suspense'),
  thriller('Thriller'),
  war('War'),
  western('Western');

  const JellyGenre(this.value);

  /// Nombre exacto en inglés que usa Jellyfin.
  final String value;

  static final Map<String, JellyGenre> _byValue = {
    for (final g in JellyGenre.values) g.value: g,
  };

  /// Resuelve el enum desde el nombre de la API (`null` si no existe).
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

class HomeScroll {
  const HomeScroll({
    required this.titleKey,
    this.genres = const [],
    this.types = const [BaseItemKind.movie, BaseItemKind.series],
    this.limit = 20,
    this.bottomVignette = false,
    this.bottomVignetteHeight = 56,
    this.bottomVignetteOpacity = 0.72,
    this.cardType,
    this.imageSource,
    this.metaOverlay = false,
    this.metaAlignment = RowMetaAlign.left,
    this.showNewBadge = false,
    this.showLogo = false,
    this.logoPosition = RowLogoPosition.top,
    this.logoSize,
    this.hideTitle = false,
    this.hideYear = false,
    this.showHoverOverlay = true,
    this.cardBorderRadius,
    this.hoverScale,
    this.showSeeMore = true,
    this.sort = HomeScrollSort.added,
    this.tapAction = HomeScrollTapAction.play,
    this.yearFrom,
    this.yearTo,
  });

  /// Título de la fila como enum ([HomeScrollTitle], sin cadenas).
  final HomeScrollTitle titleKey;

  /// Géneros de Jellyfin ([JellyGenre]) para filtrar la fila.
  /// Se muestran los elementos que tengan cualquiera de estos géneros.
  final List<JellyGenre> genres;

  /// Tipos de elemento a incluir.
  final List<BaseItemKind> types;

  /// Máximo de elementos de la fila.
  final int limit;

  /// Si `true`, muestra viñeta degradada solo en la parte inferior de la
  /// imagen de cada tarjeta de esta fila (útil para Disney, configurable por
  /// scroll y reutilizable en cualquier skin como Prime/Jelly).
  final bool bottomVignette;

  /// Altura de la viñeta inferior (px) cuando `bottomVignette` es `true`.
  final double bottomVignetteHeight;

  /// Opacidad máxima de la viñeta (0..1) en la parte baja del degradado.
  final double bottomVignetteOpacity;

  /// Formato de tarjeta para este scroll (null = usa global `cardImageType` del skin).
  final HomeScrollCardType? cardType;

  /// Origen de imagen para este scroll (null = usa default poster/thumb).
  /// Permite elegir por scroll si se usa primary, thumb o backdrop de la API.
  final RowImageSource? imageSource;

  /// Si `true`, el meta (título) se muestra en stack abajo sobre la imagen.
  final bool metaOverlay;

  /// Alineación horizontal del meta overlay (izquierda/centro/derecha).
  final RowMetaAlign metaAlignment;

  /// Muestra el banner "Nueva película/serie" sobre la imagen.
  final bool showNewBadge;

  /// Muestra el logo de la película/serie sobre la imagen en stack.
  final bool showLogo;

  /// Posición del logo en el stack (top/center/bottom). Meta siempre abajo.
  final RowLogoPosition logoPosition;

  /// Altura en px del logo overlay sobre la imagen. `null` = default actual
  /// (28, 36 en posición center).
  final double? logoSize;

  /// Oculta el título bajo la tarjeta (cuando es false se muestra).
  final bool hideTitle;

  /// Oculta el año bajo el título (solo afecta al subtítulo de año).
  final bool hideYear;

  /// Si es `false` no muestra el overlay oscuro con icono de play al hacer
  /// hover (útil para skins que quieren solo escala/borde sin oscurecer).
  final bool showHoverOverlay;

  /// Radio de borde de las tarjetas de este scroll (poster y backdrop).
  /// Si es `null` se usa el global `cardBorderRadius` del skin.
  final double? cardBorderRadius;

  /// Escala del hover/expansión de la tarjeta (poster/backdrop) de este scroll.
  /// `null` => usa el default actual (1.3 para HoverPlayCard, 1.04 para TV).
  /// `1.0` => sin escalado, solo muestra el panel/borde.
  final double? hoverScale;

  /// Si es `false` oculta el botón "Ver más" del título de la fila.
  final bool showSeeMore;

  /// Orden de los elementos de la biblioteca para este scroll.
  final HomeScrollSort sort;

  /// Acción al pulsar una tarjeta: reproducir directo o ir al detalle.
  final HomeScrollTapAction tapAction;

  /// Rango de años de producción para filtrar la fila (ej. nostalgia con
  /// `yearTo: 2000`). `null` = sin límite. Solo aplica a scrolls custom.
  final int? yearFrom;
  final int? yearTo;

  Map<String, dynamic> toJson() => {
    'titleKey': titleKey.name,
    'genres': genres.map((g) => g.value).toList(),
    'types': types.map((t) => t.name).toList(),
    'limit': limit,
    'bottomVignette': bottomVignette,
    'bottomVignetteHeight': bottomVignetteHeight,
    'bottomVignetteOpacity': bottomVignetteOpacity,
    if (cardType != null) 'cardType': cardType!.name,
    if (imageSource != null) 'imageSource': imageSource!.name,
    'metaOverlay': metaOverlay,
    'metaAlignment': metaAlignment.name,
    'showNewBadge': showNewBadge,
    'showLogo': showLogo,
    'logoPosition': logoPosition.name,
    if (logoSize != null) 'logoSize': logoSize,
    'hideTitle': hideTitle,
    'hideYear': hideYear,
    'showHoverOverlay': showHoverOverlay,
    if (cardBorderRadius != null) 'cardBorderRadius': cardBorderRadius,
    if (hoverScale != null) 'hoverScale': hoverScale,
    'showSeeMore': showSeeMore,
    'sort': sort.name,
    'tapAction': tapAction.name,
    if (yearFrom != null) 'yearFrom': yearFrom,
    if (yearTo != null) 'yearTo': yearTo,
  };

  factory HomeScroll.fromJson(Map<String, dynamic> json) => HomeScroll(
    titleKey:
        HomeScrollTitle.values.asNameMap()[json['titleKey'] as String? ?? ''] ??
        HomeScrollTitle.custom,
    // Los JSON guardados traen nombres de la API; los desconocidos se omiten.
    genres: ((json['genres'] as List?) ?? const [])
        .map((e) => JellyGenre.fromValue(e as String?))
        .whereType<JellyGenre>()
        .toList(),
    types: ((json['types'] as List?) ?? const [])
        .map((e) => BaseItemKind.values.asNameMap()[e] ?? BaseItemKind.movie)
        .toList(),
    limit: (json['limit'] as num?)?.toInt() ?? 20,
    bottomVignette: json['bottomVignette'] as bool? ?? false,
    bottomVignetteHeight:
        (json['bottomVignetteHeight'] as num?)?.toDouble() ?? 56,
    bottomVignetteOpacity:
        (json['bottomVignetteOpacity'] as num?)?.toDouble() ?? 0.72,
    cardType: json['cardType'] != null
        ? HomeScrollCardType.values.asNameMap()[json['cardType'] as String]
        : null,
    imageSource: json['imageSource'] != null
        ? RowImageSource.values.asNameMap()[json['imageSource'] as String]
        : null,
    metaOverlay: json['metaOverlay'] as bool? ?? false,
    metaAlignment: json['metaAlignment'] != null
        ? RowMetaAlign.values.asNameMap()[json['metaAlignment'] as String] ??
              RowMetaAlign.left
        : RowMetaAlign.left,
    showNewBadge: json['showNewBadge'] as bool? ?? false,
    showLogo: json['showLogo'] as bool? ?? false,
    logoPosition: json['logoPosition'] != null
        ? RowLogoPosition.values.asNameMap()[json['logoPosition'] as String] ??
              RowLogoPosition.top
        : RowLogoPosition.top,
    logoSize: (json['logoSize'] as num?)?.toDouble(),
    hideTitle: json['hideTitle'] as bool? ?? false,
    hideYear: json['hideYear'] as bool? ?? false,
    showHoverOverlay: json['showHoverOverlay'] as bool? ?? true,
    cardBorderRadius: (json['cardBorderRadius'] as num?)?.toDouble(),
    hoverScale: (json['hoverScale'] as num?)?.toDouble(),
    showSeeMore: json['showSeeMore'] as bool? ?? true,
    yearFrom: (json['yearFrom'] as num?)?.toInt(),
    yearTo: (json['yearTo'] as num?)?.toInt(),
    tapAction: json['tapAction'] != null
        ? HomeScrollTapAction.values.asNameMap()[json['tapAction'] as String] ??
            HomeScrollTapAction.play
        : HomeScrollTapAction.play,
    sort: json['sort'] != null
        ? HomeScrollSort.values.asNameMap()[json['sort'] as String] ??
            HomeScrollSort.added
        : HomeScrollSort.added,
  );

  @override
  bool operator ==(Object other) =>
      other is HomeScroll &&
      other.titleKey == titleKey &&
      listEquals(other.genres, genres) &&
      listEquals(other.types, types) &&
      other.limit == limit &&
      other.bottomVignette == bottomVignette &&
      other.bottomVignetteHeight == bottomVignetteHeight &&
      other.bottomVignetteOpacity == bottomVignetteOpacity &&
      other.cardType == cardType &&
      other.imageSource == imageSource &&
       other.metaOverlay == metaOverlay &&
       other.metaAlignment == metaAlignment &&
       other.showNewBadge == showNewBadge &&
      other.showLogo == showLogo &&
       other.logoPosition == logoPosition &&
       other.logoSize == logoSize &&
        other.hideTitle == hideTitle &&
        other.hideYear == hideYear &&
        other.showHoverOverlay == showHoverOverlay &&
        other.cardBorderRadius == cardBorderRadius &&
        other.hoverScale == hoverScale &&
        other.showSeeMore == showSeeMore &&
        other.sort == sort &&
        other.tapAction == tapAction &&
        other.yearFrom == yearFrom &&
        other.yearTo == yearTo;

  @override
  int get hashCode => Object.hashAll([
    titleKey,
    genres,
    types,
    limit,
    bottomVignette,
    bottomVignetteHeight,
    bottomVignetteOpacity,
    cardType,
    imageSource,
    metaOverlay,
    metaAlignment,
    showNewBadge,
    showLogo,
    logoPosition,
    logoSize,
    hideTitle,
    hideYear,
    showHoverOverlay,
    cardBorderRadius,
    hoverScale,
    showSeeMore,
    sort,
    tapAction,
    yearFrom,
    yearTo,
  ]);
}
