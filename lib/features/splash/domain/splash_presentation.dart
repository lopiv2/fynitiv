import 'package:material_ui/material_ui.dart';

/// Efecto decorativo de una presentación de splash.
///
/// Es una función pura del progreso [progress] (0..1 del clock de la
/// animación): sin estado ni controllers propios, se repinta con el resto de
/// la splash en cada frame.
typedef SplashEffect = Widget Function(BuildContext context, double progress);

/// Configuración visual y sonora de una presentación de splash.
///
/// Cada estación define su propia instancia; el motor de animación de
/// `splash_screen.dart` es común y solo lee estos campos, de forma que añadir
/// una presentación no duplica la coreografía.
@immutable
class SplashPresentation {
  const SplashPresentation({
    required this.id,
    required this.audioAsset,
    required this.backgroundAsset,
    required this.letterStops,
    required this.taglineColors,
    required this.extrusionDark,
    required this.extrusionLight,
    required this.glowColor,
    this.backgroundTint,
    this.iconColor = Colors.white,
    this.iconShadows = const [],
    this.flareAsset = 'assets/images/flares/flare_01.png',
    this.backgroundEffects = const [],
    this.effects = const [],
    this.titleFontFamily,
    this.letterOutlineColor = Colors.white,
  });

  /// Identificador estable (para comparar presentaciones entre estaciones).
  final String id;

  /// Asset de audio (ruta relativa sin `assets/`, estilo AssetSource).
  final String audioAsset;

  /// Asset de la imagen de fondo.
  final String backgroundAsset;

  /// Colores del degradado de las letras del título, de la primera a la
  /// última, repartidos uniformemente.
  final List<Color> letterStops;

  /// Color de cada palabra del tagline, en orden.
  final List<Color> taglineColors;

  /// Color de la extrusión 3D más profunda y más frontal.
  final Color extrusionDark;
  final Color extrusionLight;

  /// Color del halo/glow del final.
  final Color glowColor;

  /// Tinte translúcido sobre el fondo (para oscurecer/teñir la estación).
  final Color? backgroundTint;

  /// Color del icono que morfea sobre el tagline.
  final Color iconColor;

  /// Sombras del icono que morfea sobre el tagline: dan contraste cuando la
  /// presentación tiene fondos claros (p. ej. una imagen de fondo blanca).
  final List<Shadow> iconShadows;

  /// Asset del destello (flare) final.
  final String flareAsset;

  /// Capas decorativas propias de la estación, **detrás** del contenido.
  final List<SplashEffect> backgroundEffects;

  /// Capas decorativas propias de la estación, **delante** del contenido.
  final List<SplashEffect> effects;

  /// Familia tipográfica del título (letras FYNITIV). `null` = fuente del
  /// sistema (resto de presentaciones). Halloween usa Super Midnight.
  final String? titleFontFamily;

  /// Color del borde (outline) de las letras del título. Blanco por defecto;
  /// cada presentación puede fijar el suyo (p. ej. Halloween).
  final Color letterOutlineColor;

  /// Color base de la letra [index] de un título de [count] letras:
  /// interpolación con paradas repartidas uniformemente en [letterStops].
  Color letterColor(int index, int count) {
    if (letterStops.isEmpty) return Colors.white;
    if (letterStops.length == 1 || count <= 1) return letterStops.last;
    final t = (index / (count - 1)).clamp(0.0, 1.0);
    final scaled = t * (letterStops.length - 1);
    final i = scaled.floor().clamp(0, letterStops.length - 2);
    return Color.lerp(letterStops[i], letterStops[i + 1], scaled - i)!;
  }

  /// Degradado vertical de una letra: abajo una versión oscura del color base,
  /// una franja clara en medio y el color base arriba.
  LinearGradient letterGradient(int index, int count) {
    final base = letterColor(index, count);
    final dark = Color.lerp(base, Colors.black, 0.3)!;
    final light = Color.lerp(base, Colors.white, 0.5)!;
    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [dark, light, base, base],
      stops: const [0.0, 0.42, 0.58, 1.0],
    );
  }

  /// Color de una capa de extrusión en [t] (0 = fondo, 1 = frontal).
  Color extrusionColor(double t) =>
      Color.lerp(extrusionDark, extrusionLight, t.clamp(0.0, 1.0))!;

  /// Color del tagline en la posición [index] (con respaldo al último).
  Color taglineColor(int index) =>
      taglineColors.isEmpty
      ? Colors.white
      : taglineColors[index.clamp(0, taglineColors.length - 1)];
}
