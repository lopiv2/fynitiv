import 'package:flutter/foundation.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

/// Origen de imagen para un scroll (configurable por scroll).
enum RowImageSource { primary, thumb, backdrop }

/// Posición del logo overlay en un scroll (stack). Meta siempre abajo.
enum RowLogoPosition { top, center, bottom }

/// Fila de contenido configurable por skin: un título y filtros que deciden
/// qué elementos se muestran (géneros y tipos). Permite customizar los scrolls
/// de cada skin sin tocar código de pantalla.
enum HomeScrollCardType { poster, backdrop }

class HomeScroll {
  const HomeScroll({
    required this.titleKey,
    required this.genres,
    this.types = const [BaseItemKind.movie, BaseItemKind.series],
    this.limit = 20,
    this.bottomVignette = false,
    this.bottomVignetteHeight = 56,
    this.bottomVignetteOpacity = 0.72,
    this.cardType,
    this.imageSource,
    this.metaOverlay = false,
    this.showNewBadge = false,
    this.showLogo = false,
    this.logoPosition = RowLogoPosition.top,
    this.hideTitle = false,
    this.hideYear = false,
  });

  /// Clave de localización del título de la fila (AppLocalizations).
  final String titleKey;

  /// Géneros (nombres en inglés de Jellyfin: 'Action', 'Animation', ...).
  /// Se muestran los elementos que tengan cualquiera de estos géneros.
  final List<String> genres;

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

  /// Muestra el banner "Nueva película/serie" sobre la imagen.
  final bool showNewBadge;

  /// Muestra el logo de la película/serie sobre la imagen en stack.
  final bool showLogo;

  /// Posición del logo en el stack (top/center/bottom). Meta siempre abajo.
  final RowLogoPosition logoPosition;

  /// Oculta el título bajo la tarjeta (cuando es false se muestra).
  final bool hideTitle;

  /// Oculta el año bajo el título (solo afecta al subtítulo de año).
  final bool hideYear;

  Map<String, dynamic> toJson() => {
    'titleKey': titleKey,
    'genres': genres,
    'types': types.map((t) => t.name).toList(),
    'limit': limit,
    'bottomVignette': bottomVignette,
    'bottomVignetteHeight': bottomVignetteHeight,
    'bottomVignetteOpacity': bottomVignetteOpacity,
    if (cardType != null) 'cardType': cardType!.name,
    if (imageSource != null) 'imageSource': imageSource!.name,
    'metaOverlay': metaOverlay,
    'showNewBadge': showNewBadge,
    'showLogo': showLogo,
    'logoPosition': logoPosition.name,
    'hideTitle': hideTitle,
    'hideYear': hideYear,
  };

  factory HomeScroll.fromJson(Map<String, dynamic> json) => HomeScroll(
    titleKey: json['titleKey'] as String,
    genres: (json['genres'] as List?)?.cast<String>() ?? const [],
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
    showNewBadge: json['showNewBadge'] as bool? ?? false,
    showLogo: json['showLogo'] as bool? ?? false,
    logoPosition: json['logoPosition'] != null
        ? RowLogoPosition.values.asNameMap()[json['logoPosition'] as String] ??
              RowLogoPosition.top
        : RowLogoPosition.top,
    hideTitle: json['hideTitle'] as bool? ?? false,
    hideYear: json['hideYear'] as bool? ?? false,
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
      other.showNewBadge == showNewBadge &&
      other.showLogo == showLogo &&
      other.logoPosition == logoPosition &&
      other.hideTitle == hideTitle &&
      other.hideYear == hideYear;

  @override
  int get hashCode => Object.hash(
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
    showNewBadge,
    showLogo,
    logoPosition,
    hideTitle,
    hideYear,
  );
}
