import 'package:material_ui/material_ui.dart';

import 'home_scroll.dart';
import 'layout_section.dart';

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

/// Tipo de imagen de las tarjetas de las filas de contenido.
enum CardImageType { poster, backdrop }

/// Efecto de la animación de onda del reproductor de audio.
enum AudioWaveformEffect { equalizer, wave, mirror, bars, surfer }

/// Tipo de transición entre banners del slider de novedades.
enum SliderTransition { slide, fade }

/// Lados donde se dibuja la viñeta del featured slider.
/// - left/right/top/bottom: solo ese borde, con grosor [Skin.bannerVignetteSize].
/// - around: composición completa (radial + degradados, aspecto previo).
enum SliderVignetteMode { left, right, top, bottom, around }

/// Skin: define colores, logos, layout y tipografía de la app.
class Skin {
  const Skin({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.sidebarBackground,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    this.sidebarLogo,
    this.splashLogo,
    this.logoPosition = LogoPosition.top,
    this.avatarPosition = LogoPosition.top,
    this.sidebarPosition = SidebarPosition.left,
    this.sidebarWidth = 260,
    this.sidebarHeaderSpacing = 8,
    this.navItemIconSpacing = 12,
    this.sidebarSelectedColor,
    this.showContinueRow = true,
    this.cardImageType = CardImageType.poster,
    this.cardLogo,
    this.cardLogoSize = 18,
    this.playerLogo,
    this.playerLogoPosition = LogoOverlayPosition.none,
    this.audioWaveformEffect = AudioWaveformEffect.equalizer,
    this.showNewReleasesRow = true,
    this.showNewReleasesBanner = false,
    this.bannerBorder = false,
    this.bannerBorderWidth = 1.5,
    this.bannerBorderColor = const Color(0xFFFFFFFF),
    this.bannerBorderHoverWidth = 2.5,
    this.bannerLogoWidthFactor = 0.32,
    this.bannerLogoMaxHeight = 110.0,
    this.bannerShowArrows = false,
    this.bannerDotAlignment = SliderDotAlignment.right,
    this.bannerDotsOutside = false,
    this.bannerShowNewBadge = false,
    this.bannerInlineMeta = false,
    this.bannerShowIncludedBadge = false,
    this.bannerShowJellyfinLogo = false,
    this.bannerHoverReveal = false,
    this.bannerShowActions = false,
    this.showTrailerInSlider = false,
    this.bannerTransition = SliderTransition.slide,
    this.bannerArrowsOnHover = false,
    this.bannerShowTitle = true,
    this.bannerAttachedTop = false,
    this.bannerShowAgeRating = false,
    this.bannerContentScale = 1.0,
    this.bannerHeightFactor = 0.38,
    this.bannerMaxHeight = 440,
    this.bannerHorizontalPadding = 0,
    this.bannerShadow = false,
    this.bannerHoverScale = 1.02,
    this.bannerVignette = true,
    this.bannerVignetteMode = SliderVignetteMode.around,
    this.bannerVignetteOpacity = 1.0,
    this.bannerVignetteSize = 160,
    this.homeCardWidth = 150,
    this.homeRowHeight = 270,
    this.homeCardScale = 1.0,
    this.rowSpacing = 24,
    this.itemSpacing = 12,
    this.cardBorderRadius = 10,
    this.bannerBorderRadius,
    this.sidebarCollapsible = true,
    this.fontFamily,
    this.cardHoverExtension = false,
    this.homeScrolls = const [],
    // --- Layouts ordenables por skin (array de arriba a abajo) ---
    // Si están vacíos se usa el orden legado para no romper presets existentes.
    // Home: FeaturedSlider → ContinueWatching → NextUp → Recent → custom HomeScrolls.
    // VOD: FeaturedSlider → ContinueWatching → NewReleases → Library per view → custom.
    // Para personalizar, define el array en el orden que quieras que aparezca.
    // Ej. Disney: [featuredSlider, continueWatching, newReleases, custom(Action), custom(Family)]
    // Cada elemento `HomeSection`/`VodSection` puede ser built-in o `custom(HomeScroll(...))`
    // con poster/backdrop, viñeta, etc. configurables por scroll y reutilizables en cualquier skin.
    this.homeLayout = const [],
    this.vodLayout = const [],
    this.titleMarqueeOnHover = false,
    this.topBarFloating = false,
    this.showCardBadge = false,
  });

  final String id;
  final String name;

  // Paleta.
  final Color primary;
  final Color secondary;
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color sidebarBackground;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  // Logos (null → usar texto del nombre de la app).
  final String? sidebarLogo;
  final String? splashLogo;

  /// Dónde ubicar el logo dentro de la barra lateral.
  final LogoPosition logoPosition;

  /// Dónde ubicar el avatar de usuario dentro de la barra lateral.
  final AvatarPosition avatarPosition;

  /// Espaciado vertical alrededor del avatar/logo cuando van arriba.
  final double sidebarHeaderSpacing;

  /// Separación horizontal entre el icono y el texto de los items de la barra.
  final double navItemIconSpacing;

  /// Color del item seleccionado de la barra. Si es `null` se usa el acento
  /// con transparencia.
  final Color? sidebarSelectedColor;

  // Layout.
  final SidebarPosition sidebarPosition;
  final double sidebarWidth;
  final bool showContinueRow;

  /// Tipo de imagen de las tarjetas de las filas de contenido: póster vertical
  /// (2:3) o backdrop horizontal (16:9).
  final CardImageType cardImageType;

  /// Logotipo superpuesto abajo a la derecha de las tarjetas de las filas de
  /// contenido. Puede ser un asset (`assets/...`) o la ruta de un archivo de
  /// imagen propio. `null` = sin logotipo.
  final String? cardLogo;

  /// Altura del logotipo de las tarjetas (px).
  final double cardLogoSize;

  /// Logotipo del reproductor (marca de agua). Si es `null` se usa el mismo
  /// de las tarjetas ([cardLogo]). Puede ser un asset o una ruta de archivo.
  final String? playerLogo;

  /// Posición del logotipo (el mismo de las tarjetas) dentro del reproductor
  /// de vídeo. [LogoOverlayPosition.none] lo desactiva.
  final LogoOverlayPosition playerLogoPosition;

  /// Efecto de la onda animada del reproductor de audio.
  final AudioWaveformEffect audioWaveformEffect;
  final bool showNewReleasesRow;

  /// Muestra las novedades como carrusel de banners (estilo Disney+) en la
  /// parte superior del home, con slider de puntos.
  final bool showNewReleasesBanner;

  /// Borde alrededor de cada banner del slider de novedades.
  final bool bannerBorder;

  /// Grosor del borde del featured slider (px). Solo si [bannerBorder] es true.
  final double bannerBorderWidth;

  /// Color del borde del featured slider.
  final Color bannerBorderColor;

  /// Grosor del borde al hacer hover/focus en el featured slider.
  final double bannerBorderHoverWidth;

  /// Tamaño del logo del título en el slider de novedades (fracción del ancho).
  final double bannerLogoWidthFactor;

  /// Altura máxima del logo del título en el slider de novedades (px,
  /// antes de aplicar la escala de contenido).
  final double bannerLogoMaxHeight;

  /// Muestra flechas a los lados del slider de novedades para navegar.
  final bool bannerShowArrows;

  /// Posición de los puntos del slider de novedades.
  final SliderDotAlignment bannerDotAlignment;

  /// Si `true`, los puntos se muestran centrados debajo del slider,
  /// fuera del banner (estilo Disney+).
  final bool bannerDotsOutside;

  /// Muestra la pastilla "Nueva película"/"Nueva serie" sobre el logo
  /// cuando el contenido es reciente (estilo Disney+).
  final bool bannerShowNewBadge;

  /// Muestra la meta inferior en línea estilo Disney+: insignia de edad
  /// oscura + año • géneros, sin nota de estrellas ni descripción.
  final bool bannerInlineMeta;

  /// Muestra la insignia "Se incluye con Jellyfin" bajo el logo del banner.
  final bool bannerShowIncludedBadge;

  /// Muestra el logo de Jellyfin en pequeño sobre el logo del banner.
  final bool bannerShowJellyfinLogo;

  /// Al pasar el ratón sobre el logo (solo escritorio), el logo se desliza
  /// hacia arriba y se revela la descripción del elemento.
  final bool bannerHoverReveal;

  /// Muestra los botones de acción (Ver ahora, +, i) bajo el logo del banner.
  final bool bannerShowActions;

  /// Muestra un botón de trailer en el slider, solo para películas o series.
  final bool showTrailerInSlider;

  /// Transición entre banners del slider de novedades.
  final SliderTransition bannerTransition;

  /// Muestra las flechas del slider solo al pasar el ratón sobre él.
  final bool bannerArrowsOnHover;

  /// Muestra el título (Novedades) sobre el slider.
  final bool bannerShowTitle;

  /// Pega el slider al borde superior del contenido (sin margen).
  final bool bannerAttachedTop;

  /// Muestra la edad recomendada del contenido (recuadro de color) en el
  /// slider, en lugar del año y el tipo de contenido.
  final bool bannerShowAgeRating;

  /// Escala del conjunto (logo, botones, insignia, descripción) del slider.
  final double bannerContentScale;

  /// Factor de altura del slider (relativo al ancho disponible).
  final double bannerHeightFactor;

  /// Altura máxima del slider.
  final double bannerMaxHeight;

  /// Padding horizontal (izquierda + derecha) del featured slider.
  /// Deja un hueco entre el borde de la pantalla y el banner. 0 = sin padding.
  final double bannerHorizontalPadding;

  /// Si `true`, el featured slider muestra sombra elevada alrededor del banner.
  final bool bannerShadow;

  /// Escala al hacer hover sobre el banner del featured slider (1.0 = sin escala,
  /// 1.02 = ligero zoom). Solo borde si es 1.0.
  final double bannerHoverScale;

  /// Si `true`, muestra viñeta oscurecida en bordes del featured slider
  /// (radial + degradados superior/laterales). Configurable por skin.
  final bool bannerVignette;

  /// Lados donde se dibuja la viñeta (solo si [bannerVignette] es `true`).
  final SliderVignetteMode bannerVignetteMode;

  /// Opacidad global de la viñeta (0..1, multiplica las alfas base).
  final double bannerVignetteOpacity;

  /// Grosor en px de la viñeta en los modos por lado (left/right/top/bottom).
  /// El modo `around` usa su composición fija de degradados.
  final double bannerVignetteSize;

  /// Ancho de las tarjetas de las filas del home.
  final double homeCardWidth;

  /// Alto de las filas del home.
  final double homeRowHeight;

  /// Escala aplicada al conjunto de la fila (ancho de tarjeta y alto).
  /// Por ejemplo, `1.5` hace las tarjetas un 50% más grandes y, por lo
  /// tanto, caben menos elementos en el viewport inicial sin hacer scroll.
  final double homeCardScale;

  /// Espacio horizontal entre elementos de un ContentRow.
  final double itemSpacing;

  /// Radio de las esquinas del featured slider. Si es `null` se deriva de
  /// `cardBorderRadius` (+2 para compensar el borde).
  final double? bannerBorderRadius;

  /// Separación vertical entre filas (scrolls) de contenido.
  final double rowSpacing;
  final double cardBorderRadius;
  final bool sidebarCollapsible;

  // Tipografía.
  final String? fontFamily;

  /// Muestra el panel de extensión al hacer hover sobre las tarjetas de las
  /// filas (estilo Prime): la tarjeta crece y aparece un cuadro negro bajo el
  /// elemento con el nombre y un botón de reproducir.
  final bool cardHoverExtension;

  /// Filas de contenido extra (scrolls) configuradas por este skin, con sus
  /// filtros (géneros/tipos). Se muestran bajo las filas de la biblioteca.
  /// @Deprecated: usar `homeLayout`/`vodLayout` con `HomeSection.custom`/`VodSection.custom`.
  /// Se mantiene por compatibilidad: si `homeLayout`/`vodLayout` están vacíos se usa este
  /// array en el orden legado (detrás de Recent). Si `homeLayout`/`vodLayout` no está vacío,
  /// este campo se ignora por completo para evitar duplicados.
  final List<HomeScroll> homeScrolls;

  /// Layout ordenable del Home: array de secciones de arriba a abajo.
  /// Vacío = orden legado (FeaturedSlider → ContinueWatching → NextUp → Recent → homeScrolls).
  /// Lleno = se respeta exactamente el orden dado, permitiendo intercalar built-ins
  /// y customs (poster/backdrop, viñeta, etc.) de forma máxima personalizable por skin.
  /// Cada `HomeSection` puede ser built-in o `custom(HomeScroll)` con su propio poster/backdrop.
  final List<HomeSection> homeLayout;

  /// Layout ordenable de VOD: array de secciones de arriba a abajo.
  /// Vacío = orden legado VOD (FeaturedSlider → ContinueWatching → NewReleases → Library per view → homeScrolls).
  /// Lleno = orden custom. `library` expande a una fila por biblioteca (Películas, Series...),
  /// `custom` a un HomeScroll filtrado. Si `vodLayout` no está vacío, `homeScrolls` se ignora en VOD.
  final List<VodSection> vodLayout;

  /// Cuando el título del elemento hace overflow, lo desplaza horizontalmente
  /// en bucle al hacer hover (estilo Jellyfin Android TV). Solo si está activo.
  final bool titleMarqueeOnHover;

  /// Si `true` y `sidebarPosition` es `top`, la barra se muestra como isla
  /// flotante pill con glass blur (radio fijo 28), centrada y superpuesta
  /// al contenido con `Stack`.
  final bool topBarFloating;

  /// Muestra badge blanco superior en tarjetas backdrop según género/rating
  /// (estilo Prime: "LA MEJOR ACCIÓN", "TENDENCIAS", etc.). Solo efecto
  /// visual si `cardImageType == backdrop` y rating ≥ 7.
  final bool showCardBadge;

  Skin copyWith({
    String? id,
    String? name,
    Color? primary,
    Color? secondary,
    Color? backgroundTop,
    Color? backgroundBottom,
    Color? sidebarBackground,
    Color? accent,
    Color? textPrimary,
    Color? textSecondary,
    String? sidebarLogo,
    String? splashLogo,
    LogoPosition? logoPosition,
    AvatarPosition? avatarPosition,
    SidebarPosition? sidebarPosition,
    double? sidebarWidth,
    double? sidebarHeaderSpacing,
    double? navItemIconSpacing,
    Color? sidebarSelectedColor,
    bool? showContinueRow,
    CardImageType? cardImageType,
    String? cardLogo,
    double? cardLogoSize,
    String? playerLogo,
    LogoOverlayPosition? playerLogoPosition,
    AudioWaveformEffect? audioWaveformEffect,
    bool? showNewReleasesRow,
    bool? showNewReleasesBanner,
    bool? bannerBorder,
    double? bannerBorderWidth,
    Color? bannerBorderColor,
    double? bannerBorderHoverWidth,
    double? bannerLogoWidthFactor,
    double? bannerLogoMaxHeight,
    bool? bannerShowArrows,
    SliderDotAlignment? bannerDotAlignment,
    bool? bannerDotsOutside,
    bool? bannerShowNewBadge,
    bool? bannerInlineMeta,
    bool? bannerShowIncludedBadge,
    bool? bannerShowJellyfinLogo,
    bool? bannerHoverReveal,
    bool? bannerShowActions,
    bool? showTrailerInSlider,
    SliderTransition? bannerTransition,
    bool? bannerArrowsOnHover,
    bool? bannerShowTitle,
    bool? bannerAttachedTop,
    bool? bannerShowAgeRating,
    double? bannerContentScale,
    double? bannerHeightFactor,
    double? bannerMaxHeight,
    double? bannerHorizontalPadding,
    bool? bannerShadow,
    double? bannerHoverScale,
    bool? bannerVignette,
    SliderVignetteMode? bannerVignetteMode,
    double? bannerVignetteOpacity,
    double? bannerVignetteSize,
    double? homeCardWidth,
    double? homeRowHeight,
    double? homeCardScale,
    double? rowSpacing,
    double? itemSpacing,
    double? cardBorderRadius,
    double? bannerBorderRadius,
    bool? sidebarCollapsible,
    String? fontFamily,
    bool? cardHoverExtension,
    List<HomeScroll>? homeScrolls,
    List<HomeSection>? homeLayout,
    List<VodSection>? vodLayout,
    bool? titleMarqueeOnHover,
    bool? topBarFloating,
    bool? showCardBadge,
    bool clearSidebarLogo = false,
    bool clearCardLogo = false,
    bool clearPlayerLogo = false,
  }) {
    return Skin(
      id: id ?? this.id,
      name: name ?? this.name,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      backgroundTop: backgroundTop ?? this.backgroundTop,
      backgroundBottom: backgroundBottom ?? this.backgroundBottom,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      accent: accent ?? this.accent,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      sidebarLogo: clearSidebarLogo ? null : (sidebarLogo ?? this.sidebarLogo),
      splashLogo: splashLogo ?? this.splashLogo,
      logoPosition: logoPosition ?? this.logoPosition,
      avatarPosition: avatarPosition ?? this.avatarPosition,
      sidebarPosition: sidebarPosition ?? this.sidebarPosition,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      sidebarHeaderSpacing: sidebarHeaderSpacing ?? this.sidebarHeaderSpacing,
      navItemIconSpacing: navItemIconSpacing ?? this.navItemIconSpacing,
      sidebarSelectedColor: sidebarSelectedColor ?? this.sidebarSelectedColor,
      showContinueRow: showContinueRow ?? this.showContinueRow,
      cardImageType: cardImageType ?? this.cardImageType,
      cardLogo: clearCardLogo ? null : (cardLogo ?? this.cardLogo),
      cardLogoSize: cardLogoSize ?? this.cardLogoSize,
      playerLogo: clearPlayerLogo ? null : (playerLogo ?? this.playerLogo),
      playerLogoPosition: playerLogoPosition ?? this.playerLogoPosition,
      audioWaveformEffect: audioWaveformEffect ?? this.audioWaveformEffect,
      showNewReleasesRow: showNewReleasesRow ?? this.showNewReleasesRow,
      showNewReleasesBanner:
          showNewReleasesBanner ?? this.showNewReleasesBanner,
      bannerBorder: bannerBorder ?? this.bannerBorder,
      bannerBorderWidth: bannerBorderWidth ?? this.bannerBorderWidth,
      bannerBorderColor: bannerBorderColor ?? this.bannerBorderColor,
      bannerBorderHoverWidth:
          bannerBorderHoverWidth ?? this.bannerBorderHoverWidth,
      bannerLogoWidthFactor:
          bannerLogoWidthFactor ?? this.bannerLogoWidthFactor,
      bannerLogoMaxHeight: bannerLogoMaxHeight ?? this.bannerLogoMaxHeight,
      bannerShowArrows: bannerShowArrows ?? this.bannerShowArrows,
      bannerDotAlignment: bannerDotAlignment ?? this.bannerDotAlignment,
      bannerDotsOutside: bannerDotsOutside ?? this.bannerDotsOutside,
      bannerShowNewBadge: bannerShowNewBadge ?? this.bannerShowNewBadge,
      bannerInlineMeta: bannerInlineMeta ?? this.bannerInlineMeta,
      bannerShowIncludedBadge:
          bannerShowIncludedBadge ?? this.bannerShowIncludedBadge,
      bannerShowJellyfinLogo:
          bannerShowJellyfinLogo ?? this.bannerShowJellyfinLogo,
      bannerHoverReveal: bannerHoverReveal ?? this.bannerHoverReveal,
      bannerShowActions: bannerShowActions ?? this.bannerShowActions,
      showTrailerInSlider: showTrailerInSlider ?? this.showTrailerInSlider,
      bannerTransition: bannerTransition ?? this.bannerTransition,
      bannerArrowsOnHover: bannerArrowsOnHover ?? this.bannerArrowsOnHover,
      bannerShowTitle: bannerShowTitle ?? this.bannerShowTitle,
      bannerAttachedTop: bannerAttachedTop ?? this.bannerAttachedTop,
      bannerShowAgeRating: bannerShowAgeRating ?? this.bannerShowAgeRating,
      bannerContentScale: bannerContentScale ?? this.bannerContentScale,
      bannerHeightFactor: bannerHeightFactor ?? this.bannerHeightFactor,
      bannerMaxHeight: bannerMaxHeight ?? this.bannerMaxHeight,
      bannerHorizontalPadding:
          bannerHorizontalPadding ?? this.bannerHorizontalPadding,
      bannerShadow: bannerShadow ?? this.bannerShadow,
      bannerHoverScale: bannerHoverScale ?? this.bannerHoverScale,
      bannerVignette: bannerVignette ?? this.bannerVignette,
      bannerVignetteMode: bannerVignetteMode ?? this.bannerVignetteMode,
      bannerVignetteOpacity:
          bannerVignetteOpacity ?? this.bannerVignetteOpacity,
      bannerVignetteSize: bannerVignetteSize ?? this.bannerVignetteSize,
      homeCardWidth: homeCardWidth ?? this.homeCardWidth,
      homeRowHeight: homeRowHeight ?? this.homeRowHeight,
      homeCardScale: homeCardScale ?? this.homeCardScale,
      rowSpacing: rowSpacing ?? this.rowSpacing,
      itemSpacing: itemSpacing ?? this.itemSpacing,
      cardBorderRadius: cardBorderRadius ?? this.cardBorderRadius,
      bannerBorderRadius: bannerBorderRadius ?? this.bannerBorderRadius,
      sidebarCollapsible: sidebarCollapsible ?? this.sidebarCollapsible,
      fontFamily: fontFamily ?? this.fontFamily,
      cardHoverExtension: cardHoverExtension ?? this.cardHoverExtension,
      homeScrolls: homeScrolls ?? this.homeScrolls,
      homeLayout: homeLayout ?? this.homeLayout,
      vodLayout: vodLayout ?? this.vodLayout,
      titleMarqueeOnHover: titleMarqueeOnHover ?? this.titleMarqueeOnHover,
      topBarFloating: topBarFloating ?? this.topBarFloating,
      showCardBadge: showCardBadge ?? this.showCardBadge,
    );
  }

  // --- JSON ---

  factory Skin.fromJson(Map<String, dynamic> json) {
    return Skin(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      primary: _colorFromString(json['primary'] as String? ?? ''),
      secondary: _colorFromString(json['secondary'] as String? ?? ''),
      backgroundTop: _colorFromString(json['backgroundTop'] as String? ?? ''),
      backgroundBottom: _colorFromString(
        json['backgroundBottom'] as String? ?? '',
      ),
      sidebarBackground: _colorFromString(
        json['sidebarBackground'] as String? ?? '',
      ),
      accent: _colorFromString(json['accent'] as String? ?? ''),
      textPrimary: _colorFromString(json['textPrimary'] as String? ?? ''),
      textSecondary: _colorFromString(json['textSecondary'] as String? ?? ''),
      sidebarLogo: json['sidebarLogo'] as String?,
      splashLogo: json['splashLogo'] as String?,
      logoPosition: _logoPositionFromString(json['logoPosition'] as String?),
      avatarPosition: _logoPositionFromString(
        json['avatarPosition'] as String?,
      ),
      sidebarPosition: switch (json['sidebarPosition']) {
        'top' => SidebarPosition.top,
        'right' => SidebarPosition.right,
        'bottom' => SidebarPosition.bottom,
        _ => SidebarPosition.left,
      },
      sidebarWidth: (json['sidebarWidth'] as num?)?.toDouble() ?? 260,
      sidebarHeaderSpacing:
          (json['sidebarHeaderSpacing'] as num?)?.toDouble() ?? 8,
      navItemIconSpacing:
          (json['navItemIconSpacing'] as num?)?.toDouble() ?? 12,
      sidebarSelectedColor: _colorOrNull(
        json['sidebarSelectedColor'] as String?,
      ),
      showContinueRow: json['showContinueRow'] as bool? ?? true,
      cardImageType: _cardImageTypeFromString(json['cardImageType']),
      cardLogo: json['cardLogo'] as String?,
      cardLogoSize: (json['cardLogoSize'] as num?)?.toDouble() ?? 18,
      playerLogo: json['playerLogo'] as String?,
      playerLogoPosition: _logoOverlayPositionFromString(
        json['playerLogoPosition'],
      ),
      audioWaveformEffect: _audioWaveformEffectFromString(
        json['audioWaveformEffect'],
      ),
      showNewReleasesRow: json['showNewReleasesRow'] as bool? ?? true,
      showNewReleasesBanner: json['showNewReleasesBanner'] as bool? ?? false,
      bannerBorder: json['bannerBorder'] as bool? ?? false,
      bannerBorderWidth:
          (json['bannerBorderWidth'] as num?)?.toDouble() ?? 1.5,
      bannerBorderColor:
          _colorFromString(json['bannerBorderColor'] as String? ?? '#FFFFFFFF'),
      bannerBorderHoverWidth:
          (json['bannerBorderHoverWidth'] as num?)?.toDouble() ?? 2.5,
      bannerLogoWidthFactor:
          (json['bannerLogoWidthFactor'] as num?)?.toDouble() ?? 0.32,
      bannerLogoMaxHeight:
          (json['bannerLogoMaxHeight'] as num?)?.toDouble() ?? 110.0,
      bannerShowArrows: json['bannerShowArrows'] as bool? ?? false,
      bannerDotAlignment: _dotAlignmentFromString(json['bannerDotAlignment']),
      bannerDotsOutside: json['bannerDotsOutside'] as bool? ?? false,
      bannerShowNewBadge: json['bannerShowNewBadge'] as bool? ?? false,
      bannerInlineMeta: json['bannerInlineMeta'] as bool? ?? false,
      bannerShowIncludedBadge:
          json['bannerShowIncludedBadge'] as bool? ?? false,
      bannerShowJellyfinLogo: json['bannerShowJellyfinLogo'] as bool? ?? false,
      bannerHoverReveal: json['bannerHoverReveal'] as bool? ?? false,
      bannerShowActions: json['bannerShowActions'] as bool? ?? false,
      showTrailerInSlider: json['showTrailerInSlider'] as bool? ?? false,
      bannerTransition: _transitionFromString(json['bannerTransition']),
      bannerArrowsOnHover: json['bannerArrowsOnHover'] as bool? ?? false,
      bannerShowTitle: json['bannerShowTitle'] as bool? ?? true,
      bannerAttachedTop: json['bannerAttachedTop'] as bool? ?? false,
      bannerShowAgeRating: json['bannerShowAgeRating'] as bool? ?? false,
      bannerContentScale:
          (json['bannerContentScale'] as num?)?.toDouble() ?? 1.0,
      bannerHeightFactor:
          (json['bannerHeightFactor'] as num?)?.toDouble() ?? 0.38,
      bannerMaxHeight: (json['bannerMaxHeight'] as num?)?.toDouble() ?? 440,
      bannerHorizontalPadding:
          (json['bannerHorizontalPadding'] as num?)?.toDouble() ?? 0,
      bannerShadow: json['bannerShadow'] as bool? ?? false,
      bannerHoverScale:
          (json['bannerHoverScale'] as num?)?.toDouble() ?? 1.02,
      bannerVignette: json['bannerVignette'] as bool? ?? true,
      bannerVignetteMode: _vignetteModeFromString(json['bannerVignetteMode']),
      bannerVignetteOpacity:
          (json['bannerVignetteOpacity'] as num?)?.toDouble() ?? 1.0,
      bannerVignetteSize:
          (json['bannerVignetteSize'] as num?)?.toDouble() ?? 160,
      homeCardWidth: (json['homeCardWidth'] as num?)?.toDouble() ?? 150,
      homeRowHeight: (json['homeRowHeight'] as num?)?.toDouble() ?? 270,
      homeCardScale: (json['homeCardScale'] as num?)?.toDouble() ?? 1.0,
      rowSpacing: (json['rowSpacing'] as num?)?.toDouble() ?? 24,
      itemSpacing: (json['itemSpacing'] as num?)?.toDouble() ?? 12,
      cardBorderRadius: (json['cardBorderRadius'] as num?)?.toDouble() ?? 10,
      bannerBorderRadius: (json['bannerBorderRadius'] as num?)?.toDouble(),
      sidebarCollapsible: json['sidebarCollapsible'] as bool? ?? true,
      fontFamily: json['fontFamily'] as String?,
      cardHoverExtension: json['cardHoverExtension'] as bool? ?? false,
      homeScrolls:
          (json['homeScrolls'] as List?)
              ?.map((e) => HomeScroll.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      homeLayout:
          (json['homeLayout'] as List?)
              ?.map((e) => HomeSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      vodLayout:
          (json['vodLayout'] as List?)
              ?.map((e) => VodSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      titleMarqueeOnHover: json['titleMarqueeOnHover'] as bool? ?? false,
      topBarFloating: json['topBarFloating'] as bool? ?? false,
      showCardBadge: json['showCardBadge'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'primary': _colorToString(primary),
    'secondary': _colorToString(secondary),
    'backgroundTop': _colorToString(backgroundTop),
    'backgroundBottom': _colorToString(backgroundBottom),
    'sidebarBackground': _colorToString(sidebarBackground),
    'accent': _colorToString(accent),
    'textPrimary': _colorToString(textPrimary),
    'textSecondary': _colorToString(textSecondary),
    if (sidebarLogo != null) 'sidebarLogo': sidebarLogo,
    if (splashLogo != null) 'splashLogo': splashLogo,
    'logoPosition': logoPosition.name,
    'avatarPosition': avatarPosition.name,
    'sidebarPosition': sidebarPosition.name,
    'sidebarWidth': sidebarWidth,
    'sidebarHeaderSpacing': sidebarHeaderSpacing,
    'navItemIconSpacing': navItemIconSpacing,
    if (sidebarSelectedColor != null)
      'sidebarSelectedColor': _colorToString(sidebarSelectedColor!),
    'showContinueRow': showContinueRow,
    'cardImageType': cardImageType.name,
    if (cardLogo != null) 'cardLogo': cardLogo,
    'cardLogoSize': cardLogoSize,
    if (playerLogo != null) 'playerLogo': playerLogo,
    'playerLogoPosition': playerLogoPosition.name,
    'audioWaveformEffect': audioWaveformEffect.name,
    'showNewReleasesRow': showNewReleasesRow,
    'showNewReleasesBanner': showNewReleasesBanner,
    'bannerBorder': bannerBorder,
    'bannerBorderWidth': bannerBorderWidth,
    'bannerBorderColor': _colorToString(bannerBorderColor),
    'bannerBorderHoverWidth': bannerBorderHoverWidth,
    'bannerLogoWidthFactor': bannerLogoWidthFactor,
    'bannerLogoMaxHeight': bannerLogoMaxHeight,
    'bannerShowArrows': bannerShowArrows,
    'bannerDotAlignment': bannerDotAlignment.name,
    'bannerDotsOutside': bannerDotsOutside,
    'bannerShowNewBadge': bannerShowNewBadge,
    'bannerInlineMeta': bannerInlineMeta,
    'bannerShowIncludedBadge': bannerShowIncludedBadge,
    'bannerShowJellyfinLogo': bannerShowJellyfinLogo,
    'bannerHoverReveal': bannerHoverReveal,
    'bannerShowActions': bannerShowActions,
    'showTrailerInSlider': showTrailerInSlider,
    'bannerTransition': bannerTransition.name,
    'bannerArrowsOnHover': bannerArrowsOnHover,
    'bannerShowTitle': bannerShowTitle,
    'bannerAttachedTop': bannerAttachedTop,
    'bannerShowAgeRating': bannerShowAgeRating,
    'bannerContentScale': bannerContentScale,
    'bannerHeightFactor': bannerHeightFactor,
    'bannerMaxHeight': bannerMaxHeight,
    'bannerHorizontalPadding': bannerHorizontalPadding,
    'bannerShadow': bannerShadow,
    'bannerHoverScale': bannerHoverScale,
    'bannerVignette': bannerVignette,
    'bannerVignetteMode': bannerVignetteMode.name,
    'bannerVignetteOpacity': bannerVignetteOpacity,
    'bannerVignetteSize': bannerVignetteSize,
    'homeCardWidth': homeCardWidth,
    'homeRowHeight': homeRowHeight,
    'homeCardScale': homeCardScale,
    'rowSpacing': rowSpacing,
    'itemSpacing': itemSpacing,
    'cardBorderRadius': cardBorderRadius,
    if (bannerBorderRadius != null) 'bannerBorderRadius': bannerBorderRadius,
    'sidebarCollapsible': sidebarCollapsible,
    if (fontFamily != null) 'fontFamily': fontFamily,
    'cardHoverExtension': cardHoverExtension,
    'homeScrolls': homeScrolls.map((s) => s.toJson()).toList(),
    'homeLayout': homeLayout.map((s) => s.toJson()).toList(),
    'vodLayout': vodLayout.map((s) => s.toJson()).toList(),
    'titleMarqueeOnHover': titleMarqueeOnHover,
    'topBarFloating': topBarFloating,
    'showCardBadge': showCardBadge,
  };

  static Color _colorFromString(String s) {
    final hex = s.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16) ?? 0xFF000000;
    return Color(value);
  }

  static Color? _colorOrNull(String? s) {
    if (s == null || s.isEmpty) return null;
    return _colorFromString(s);
  }

  static LogoPosition _logoPositionFromString(String? s) {
    return s == 'bottom' ? LogoPosition.bottom : LogoPosition.top;
  }

  static SliderDotAlignment _dotAlignmentFromString(String? s) {
    return SliderDotAlignment.values.asNameMap()[s] ?? SliderDotAlignment.right;
  }

  static SliderTransition _transitionFromString(String? s) {
    return SliderTransition.values.asNameMap()[s] ?? SliderTransition.slide;
  }

  static SliderVignetteMode _vignetteModeFromString(String? s) {
    return SliderVignetteMode.values.asNameMap()[s] ??
        SliderVignetteMode.around;
  }

  static LogoOverlayPosition _logoOverlayPositionFromString(String? s) {
    return LogoOverlayPosition.values.asNameMap()[s] ??
        LogoOverlayPosition.none;
  }

  static CardImageType _cardImageTypeFromString(String? s) {
    return CardImageType.values.asNameMap()[s] ?? CardImageType.poster;
  }

  static AudioWaveformEffect _audioWaveformEffectFromString(String? s) {
    return AudioWaveformEffect.values.asNameMap()[s] ??
        AudioWaveformEffect.equalizer;
  }

  static String _colorToString(Color c) {
    final argb = (c.toARGB32() & 0xFFFFFFFF);
    return '#${argb.toRadixString(16).padLeft(8, '0')}';
  }
}
