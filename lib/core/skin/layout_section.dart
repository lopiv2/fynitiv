import 'package:flutter/foundation.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import 'home_scroll.dart';

/// Tipo de sección configurable para el Home.
/// Cada valor representa un bloque que aparece en el dashboard de Home.
/// El orden en el array `Skin.homeLayout` define el orden de arriba a abajo
/// en la pantalla. Si `homeLayout` está vacío, se usa el orden legado:
/// FeaturedSlider → ContinueWatching → NextUp → Recent por biblioteca → HomeScrolls custom.
///
/// - featuredSlider: carrusel de novedades (banner grande). Solo si hay items.
/// - continueWatching: fila “Continuar viendo”.
/// - nextUp: fila “A continuación” (siguientes episodios).
/// - recent: expande a una fila por cada biblioteca (Música, Películas, Series, Libros) con `recentIn`.
/// - newReleases: fila “Novedades” en formato posters (cuando no hay banner).
/// - custom: fila filtrada por géneros/tipos definida en [HomeScroll].
enum HomeSectionType {
  featuredSlider,
  continueWatching,
  nextUp,
  recent,
  newReleases,
  custom,
}

/// Tipo de sección configurable para VOD.
/// Similar a Home pero para la pantalla de Video On Demand.
/// Si `vodLayout` está vacío, se usa el orden legado VOD:
/// FeaturedSlider → ContinueWatching → NextUp → NewReleases (si no hay banner) → por cada biblioteca → HomeScrolls custom.
/// - featuredSlider, continueWatching, nextUp, newReleases, custom: igual que Home.
/// - library: expande a una fila por cada biblioteca VOD (Películas, Series... según `views`).
enum VodSectionType {
  featuredSlider,
  continueWatching,
  nextUp,
  newReleases,
  library,
  custom,
}

/// Sección ordenable del Home.
/// Documenta claramente: el array `homeLayout` de arriba a abajo define la pantalla.
/// Ejemplo Disney:
/// ```dart
/// homeLayout: [
///   HomeSection.featuredSlider(),
///   HomeSection.continueWatching(),
///   HomeSection.newReleases(),
///   HomeSection.custom(HomeScroll(titleKey: HomeScrollTitle.actionMovies, genres: [JellyGenre.action], cardType: HomeScrollCardType.backdrop)),
/// ]
/// ```
/// Para Prime puedes poner `continueWatching` primero y luego `featuredSlider`, o intercalar `recent` donde quieras.
class HomeSection {
  const HomeSection._(this.type, this.scroll, [this.collections]);

  /// Bloque Featured Slider (banner).
  const HomeSection.featuredSlider([HomeScroll? scroll])
    : this._(HomeSectionType.featuredSlider, scroll);

  /// Bloque Continuar Viendo. Puedes pasar un [HomeScroll] con la config
  /// por fila (imageSource, bottomVignette, metaOverlay, showNewBadge, showLogo, logoPosition, cardType).
  /// Ej: `HomeSection.continueWatching(HomeScroll(titleKey: HomeScrollTitle.continueWatching, genres: [], imageSource: RowImageSource.backdrop, metaOverlay: true))`
  /// (los géneros son [JellyGenre], ej. `genres: [JellyGenre.action]`)
  const HomeSection.continueWatching([HomeScroll? scroll])
    : this._(HomeSectionType.continueWatching, scroll);

  /// Bloque A continuación.
  const HomeSection.nextUp([HomeScroll? scroll])
    : this._(HomeSectionType.nextUp, scroll);

  /// Bloque Reciente por biblioteca (expande a una fila por cada view).
  /// Con [collections] limitas a qué bibliotecas aplica (ej. solo Películas
  /// o solo Series), cada entrada con su propio [scroll] (imagen, layout…).
  /// `null` o vacío = todas.
  const HomeSection.recent([HomeScroll? scroll, Set<CollectionType>? collections])
    : this._(HomeSectionType.recent, scroll, collections);

  /// Bloque Novedades en formato fila (cuando no hay banner).
  const HomeSection.newReleases([HomeScroll? scroll])
    : this._(HomeSectionType.newReleases, scroll);

  /// Bloque custom filtrado por géneros.
  const HomeSection.custom(HomeScroll scroll)
    : this._(HomeSectionType.custom, scroll);

  final HomeSectionType type;

  /// Config por fila: para `custom` es obligatorio; para built-ins es opcional y
  /// permite configurar por fila (ej. continueWatching con backdrop, vignette, metaOverlay, etc.).
  /// Si es null, se usan defaults del skin.
  final HomeScroll? scroll;

  /// Bibliotecas a las que aplica (solo `recent`/`library`). `null`/vacío = todas.
  final Set<CollectionType>? collections;

  /// Comprueba si una vista entra en esta sección según [collections].
  bool matchesView(CollectionType? collectionType) {
    if (collections == null || collections!.isEmpty) return true;
    return collectionType != null && collections!.contains(collectionType);
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type.name};
    if (scroll != null) map['scroll'] = scroll!.toJson();
    if (collections != null && collections!.isNotEmpty) {
      map['collections'] = collections!.map((c) => c.name).toList();
    }
    return map;
  }

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    final t =
        HomeSectionType.values.asNameMap()[json['type'] as String? ?? ''] ??
        HomeSectionType.custom;
    final s = json['scroll'] != null
        ? HomeScroll.fromJson(json['scroll'] as Map<String, dynamic>)
        : null;
    final collections = (json['collections'] as List?)
        ?.map((e) => CollectionType.values.asNameMap()[e])
        .whereType<CollectionType>()
        .toSet();
    final coll = (collections == null || collections.isEmpty)
        ? null
        : collections;
    switch (t) {
      case HomeSectionType.featuredSlider:
        return HomeSection.featuredSlider(s);
      case HomeSectionType.continueWatching:
        return HomeSection.continueWatching(s);
      case HomeSectionType.nextUp:
        return HomeSection.nextUp(s);
      case HomeSectionType.recent:
        return HomeSection.recent(s, coll);
      case HomeSectionType.newReleases:
        return HomeSection.newReleases(s);
      case HomeSectionType.custom:
        return HomeSection.custom(
          s ?? HomeScroll.fromJson({'titleKey': 'custom', 'genres': []}),
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is HomeSection &&
      other.type == type &&
      other.scroll == scroll &&
      setEquals(other.collections, collections);

  @override
  int get hashCode => Object.hash(
    type,
    scroll,
    collections == null
        ? null
        : Object.hashAll(
            collections!.map((c) => c.index).toList()..sort(),
          ),
  );
}

/// Sección ordenable de VOD.
/// Array `vodLayout` de arriba a abajo define la pantalla VOD.
/// Si está vacío, se usa el orden legado VOD.
/// - library: expande a una fila por cada biblioteca del usuario (Películas, Series...).
class VodSection {
  const VodSection._(this.type, this.scroll, [this.collections]);

  const VodSection.featuredSlider([HomeScroll? scroll])
    : this._(VodSectionType.featuredSlider, scroll);
  const VodSection.continueWatching([HomeScroll? scroll])
    : this._(VodSectionType.continueWatching, scroll);

  /// Bloque A continuación (siguiente episodio de cada serie).
  const VodSection.nextUp([HomeScroll? scroll])
    : this._(VodSectionType.nextUp, scroll);
  const VodSection.newReleases([HomeScroll? scroll])
    : this._(VodSectionType.newReleases, scroll);

  /// Fila por biblioteca (Películas, Series…). Con [collections] limitas a qué
  /// bibliotecas aplica, cada entrada con su propio [scroll] (imagen origen,
  /// póster/backdrop, títulos, logo…). `null` o vacío = todas.
  /// Ej: `VodSection.library(HomeScroll(...imageSource: RowImageSource.backdrop...), {CollectionType.movies})`
  const VodSection.library([HomeScroll? scroll, Set<CollectionType>? collections])
    : this._(VodSectionType.library, scroll, collections);
  const VodSection.custom(HomeScroll scroll)
    : this._(VodSectionType.custom, scroll);

  final VodSectionType type;

  /// Config por fila (para custom es obligatorio; para built-ins permite
  /// configurar esa fila específica con imageSource, vignette, metaOverlay, etc.)
  final HomeScroll? scroll;

  /// Bibliotecas a las que aplica (solo `library`). `null`/vacío = todas.
  final Set<CollectionType>? collections;

  /// Comprueba si una vista entra en esta sección según [collections].
  bool matchesView(CollectionType? collectionType) {
    if (collections == null || collections!.isEmpty) return true;
    return collectionType != null && collections!.contains(collectionType);
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type.name};
    if (scroll != null) map['scroll'] = scroll!.toJson();
    if (collections != null && collections!.isNotEmpty) {
      map['collections'] = collections!.map((c) => c.name).toList();
    }
    return map;
  }

  factory VodSection.fromJson(Map<String, dynamic> json) {
    final t =
        VodSectionType.values.asNameMap()[json['type'] as String? ?? ''] ??
        VodSectionType.custom;
    final s = json['scroll'] != null
        ? HomeScroll.fromJson(json['scroll'] as Map<String, dynamic>)
        : null;
    final collections = (json['collections'] as List?)
        ?.map((e) => CollectionType.values.asNameMap()[e])
        .whereType<CollectionType>()
        .toSet();
    final coll = (collections == null || collections.isEmpty)
        ? null
        : collections;
    switch (t) {
      case VodSectionType.featuredSlider:
        return VodSection.featuredSlider(s);
      case VodSectionType.continueWatching:
        return VodSection.continueWatching(s);
      case VodSectionType.nextUp:
        return VodSection.nextUp(s);
      case VodSectionType.newReleases:
        return VodSection.newReleases(s);
      case VodSectionType.library:
        return VodSection.library(s, coll);
      case VodSectionType.custom:
        return VodSection.custom(
          s ?? HomeScroll.fromJson({'titleKey': 'custom', 'genres': []}),
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is VodSection &&
      other.type == type &&
      other.scroll == scroll &&
      setEquals(other.collections, collections);

  @override
  int get hashCode => Object.hash(
    type,
    scroll,
    collections == null
        ? null
        : Object.hashAll(
            collections!.map((c) => c.index).toList()..sort(),
          ),
  );
}
