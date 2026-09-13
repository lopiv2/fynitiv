import 'package:flutter/foundation.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import 'home_scroll.dart';

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
enum LayoutSectionType {
  featuredSlider,
  continueWatching,
  nextUp,
  recent,
  newReleases,
  library,
  custom,
}

/// Sección ordenable de Home y VOD.
/// Documenta claramente: el array `homeLayout`/`vodLayout` de arriba a abajo
/// define la pantalla.
/// Ejemplo Disney:
/// ```dart
/// homeLayout: [
///   LayoutSection.featuredSlider(),
///   LayoutSection.continueWatching(),
///   LayoutSection.newReleases(),
///   LayoutSection.custom(HomeScroll(titleKey: HomeScrollTitle.actionMovies, genres: [JellyGenre.action], cardType: HomeScrollCardType.backdrop)),
/// ]
/// ```
/// Para Prime puedes poner `continueWatching` primero y luego `featuredSlider`,
/// o intercalar `recent`/`library` donde quieras.
class LayoutSection {
  const LayoutSection._(this.type, this.scroll, [this.collections]);

  /// Bloque Featured Slider (banner).
  const LayoutSection.featuredSlider([HomeScroll? scroll])
    : this._(LayoutSectionType.featuredSlider, scroll);

  /// Bloque Continuar Viendo. Puedes pasar un [HomeScroll] con la config
  /// por fila (imageSource, bottomVignette, metaOverlay, showNewBadge, showLogo, logoPosition, cardType).
  /// Ej: `LayoutSection.continueWatching(HomeScroll(titleKey: HomeScrollTitle.continueWatching, genres: [], imageSource: RowImageSource.backdrop, metaOverlay: true))`
  /// (los géneros son [JellyGenre], ej. `genres: [JellyGenre.action]`)
  const LayoutSection.continueWatching([HomeScroll? scroll])
    : this._(LayoutSectionType.continueWatching, scroll);

  /// Bloque A continuación.
  const LayoutSection.nextUp([HomeScroll? scroll])
    : this._(LayoutSectionType.nextUp, scroll);

  /// Bloque Reciente por biblioteca (expande a una fila por cada view).
  /// Con [collections] limitas a qué bibliotecas aplica (ej. solo Películas
  /// o solo Series), cada entrada con su propio [scroll] (imagen, layout…).
  /// `null` o vacío = todas.
  const LayoutSection.recent([
    HomeScroll? scroll,
    Set<CollectionType>? collections,
  ]) : this._(LayoutSectionType.recent, scroll, collections);

  /// Bloque Novedades en formato fila (cuando no hay banner).
  const LayoutSection.newReleases([HomeScroll? scroll])
    : this._(LayoutSectionType.newReleases, scroll);

  /// Fila por biblioteca (Películas, Series…). Con [collections] limitas a qué
  /// bibliotecas aplica, cada entrada con su propio [scroll] (imagen origen,
  /// póster/backdrop, títulos, logo…). `null` o vacío = todas.
  /// Ej: `LayoutSection.library(HomeScroll(...imageSource: RowImageSource.backdrop...), {CollectionType.movies})`
  const LayoutSection.library([
    HomeScroll? scroll,
    Set<CollectionType>? collections,
  ]) : this._(LayoutSectionType.library, scroll, collections);

  /// Bloque custom filtrado por géneros.
  const LayoutSection.custom(HomeScroll scroll)
    : this._(LayoutSectionType.custom, scroll);

  final LayoutSectionType type;

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

  factory LayoutSection.fromJson(Map<String, dynamic> json) {
    final t =
        LayoutSectionType.values.asNameMap()[json['type'] as String? ?? ''] ??
        LayoutSectionType.custom;
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
      case LayoutSectionType.featuredSlider:
        return LayoutSection.featuredSlider(s);
      case LayoutSectionType.continueWatching:
        return LayoutSection.continueWatching(s);
      case LayoutSectionType.nextUp:
        return LayoutSection.nextUp(s);
      case LayoutSectionType.recent:
        return LayoutSection.recent(s, coll);
      case LayoutSectionType.newReleases:
        return LayoutSection.newReleases(s);
      case LayoutSectionType.library:
        return LayoutSection.library(s, coll);
      case LayoutSectionType.custom:
        return LayoutSection.custom(
          s ?? HomeScroll.fromJson({'titleKey': 'custom', 'genres': []}),
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LayoutSection &&
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

/// Alias para compatibilidad: `HomeSection` es ahora [LayoutSection].
typedef HomeSection = LayoutSection;

/// Alias para compatibilidad: `VodSection` es ahora [LayoutSection].
typedef VodSection = LayoutSection;

/// Alias para compatibilidad: `HomeSectionType` es ahora [LayoutSectionType].
typedef HomeSectionType = LayoutSectionType;

/// Alias para compatibilidad: `VodSectionType` es ahora [LayoutSectionType].
typedef VodSectionType = LayoutSectionType;
