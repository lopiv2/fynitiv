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
/// FeaturedSlider → ContinueWatching → NewReleases (si no hay banner) → por cada biblioteca → HomeScrolls custom.
/// - featuredSlider, continueWatching, newReleases, custom: igual que Home.
/// - library: expande a una fila por cada biblioteca VOD (Películas, Series... según `views`).
enum VodSectionType {
  featuredSlider,
  continueWatching,
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
///   HomeSection.custom(HomeScroll(titleKey: 'actionMovies', genres: ['Action'], cardType: HomeScrollCardType.backdrop)),
/// ]
/// ```
/// Para Prime puedes poner `continueWatching` primero y luego `featuredSlider`, o intercalar `recent` donde quieras.
class HomeSection {
  const HomeSection._(this.type, this.scroll);

  /// Bloque Featured Slider (banner).
  const HomeSection.featuredSlider([HomeScroll? scroll])
    : this._(HomeSectionType.featuredSlider, scroll);

  /// Bloque Continuar Viendo. Puedes pasar un [HomeScroll] con la config
  /// por fila (imageSource, bottomVignette, metaOverlay, showNewBadge, showLogo, logoPosition, cardType).
  /// Ej: `HomeSection.continueWatching(HomeScroll(titleKey: 'continue', genres: [], imageSource: RowImageSource.backdrop, metaOverlay: true))`
  const HomeSection.continueWatching([HomeScroll? scroll])
    : this._(HomeSectionType.continueWatching, scroll);

  /// Bloque A continuación.
  const HomeSection.nextUp([HomeScroll? scroll])
    : this._(HomeSectionType.nextUp, scroll);

  /// Bloque Reciente por biblioteca (expande a una fila por cada view).
  const HomeSection.recent([HomeScroll? scroll])
    : this._(HomeSectionType.recent, scroll);

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

  Map<String, dynamic> toJson() {
    if (scroll != null) {
      return {'type': type.name, 'scroll': scroll!.toJson()};
    }
    return {'type': type.name};
  }

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    final t =
        HomeSectionType.values.asNameMap()[json['type'] as String? ?? ''] ??
        HomeSectionType.custom;
    final s = json['scroll'] != null
        ? HomeScroll.fromJson(json['scroll'] as Map<String, dynamic>)
        : null;
    switch (t) {
      case HomeSectionType.featuredSlider:
        return HomeSection.featuredSlider(s);
      case HomeSectionType.continueWatching:
        return HomeSection.continueWatching(s);
      case HomeSectionType.nextUp:
        return HomeSection.nextUp(s);
      case HomeSectionType.recent:
        return HomeSection.recent(s);
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
      other is HomeSection && other.type == type && other.scroll == scroll;

  @override
  int get hashCode => Object.hash(type, scroll);
}

/// Sección ordenable de VOD.
/// Array `vodLayout` de arriba a abajo define la pantalla VOD.
/// Si está vacío, se usa el orden legado VOD.
/// - library: expande a una fila por cada biblioteca del usuario (Películas, Series...).
class VodSection {
  const VodSection._(this.type, this.scroll);

  const VodSection.featuredSlider([HomeScroll? scroll])
    : this._(VodSectionType.featuredSlider, scroll);
  const VodSection.continueWatching([HomeScroll? scroll])
    : this._(VodSectionType.continueWatching, scroll);
  const VodSection.newReleases([HomeScroll? scroll])
    : this._(VodSectionType.newReleases, scroll);
  const VodSection.library([HomeScroll? scroll])
    : this._(VodSectionType.library, scroll);
  const VodSection.custom(HomeScroll scroll)
    : this._(VodSectionType.custom, scroll);

  final VodSectionType type;

  /// Config por fila (para custom es obligatorio; para built-ins permite
  /// configurar esa fila específica con imageSource, vignette, metaOverlay, etc.)
  final HomeScroll? scroll;

  Map<String, dynamic> toJson() {
    if (scroll != null) {
      return {'type': type.name, 'scroll': scroll!.toJson()};
    }
    return {'type': type.name};
  }

  factory VodSection.fromJson(Map<String, dynamic> json) {
    final t =
        VodSectionType.values.asNameMap()[json['type'] as String? ?? ''] ??
        VodSectionType.custom;
    final s = json['scroll'] != null
        ? HomeScroll.fromJson(json['scroll'] as Map<String, dynamic>)
        : null;
    switch (t) {
      case VodSectionType.featuredSlider:
        return VodSection.featuredSlider(s);
      case VodSectionType.continueWatching:
        return VodSection.continueWatching(s);
      case VodSectionType.newReleases:
        return VodSection.newReleases(s);
      case VodSectionType.library:
        return VodSection.library(s);
      case VodSectionType.custom:
        return VodSection.custom(
          s ?? HomeScroll.fromJson({'titleKey': 'custom', 'genres': []}),
        );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is VodSection && other.type == type && other.scroll == scroll;

  @override
  int get hashCode => Object.hash(type, scroll);
}
