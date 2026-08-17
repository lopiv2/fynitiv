import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:morphnext/morphnext.dart';

import '../core/widgets/language_selector.dart';
import '../core/widgets/scale_button.dart';
import '../features/auth/application/auth_controller.dart';

/// Pantalla de bienvenida con el logo animado en 3D.
///
/// Las letras del título comienzan en perfil (giradas 90° sobre su eje Y, de
/// modo que solo se ve una línea vertical) y rotan de forma escalonada hasta
/// revelar "FYNITIV". Un brillo recorre el texto al final.
///
/// Cuando el logo está desplegado aparece entre el título y el tagline un
/// icono que morfea en secuencia (TV → libro → mando → ∞) mientras se
/// revelan las palabras: "Watch. Read. Play. Anything".
///
/// Incluye un botón de loop para repetir la animación y un botón de play que
/// resuelve la sesión y entra en la pantalla principal.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const String _title = 'FYNITIV';

  /// Duración total de la animación en segundos (sincronizada con el audio logo).
  static const double _totalSeconds = 13;

  /// Convierte segundos absolutos a fracción del controller.
  static double _f(double seconds) => seconds / _totalSeconds;

  /// Desfase de inicio de la rotación de cada letra (segundos).
  static const double _staggerSeconds = 0.4;

  /// Duración de la rotación de cada letra (segundos).
  static const double _rotateSeconds = 2.8;

  /// Inicio de la aparición del tagline: el logo ya está desplegado.
  static const double _tWatch = 7.0;

  /// Instante en que "Read." se revela (morph TV → libro completo).
  static const double _tRead = 8.0;

  /// Instante en que "Play." se revela (morph libro → mando completo).
  static const double _tPlay = 9.0;

  /// Instante en que "Anything" se revela (morph mando → ∞ completo).
  static const double _tAnything = 10.0;

  /// Inicio del morph TV → libro (0.5s antes de "Read.", termina a los 8.0).
  static const double _tMorph1Start = 7.5;

  /// Inicio del morph libro → mando (0.5s antes de "Play.", termina a los 9.0).
  static const double _tMorph2Start = 8.5;

  /// Inicio del morph mando → ∞ (0.5s antes de "Anything", termina a los 10.0).
  static const double _tMorph3Start = 9.5;

  /// Iconos de la secuencia Watch → Read → Play → Anything.
  static const IconData _iconWatch = Icons.live_tv_outlined;
  static const IconData _iconRead = Icons.menu_book_outlined;
  static const IconData _iconPlay = Icons.sports_esports_outlined;
  static const IconData _iconAnything = Icons.all_inclusive;

  /// Tamaño del icono que morfea sobre el tagline.
  static const double _iconSize = 52;

  /// Color del icono y sombra para integrarlo con el tagline.
  static const Color _iconColor = Colors.white;

  /// Curva del morph controlado: un ligero easeInOut sobre la ventana de 0.5s
  /// mantiene la sensación orgánica sin perder la sincronía exacta con el
  /// texto (termina justo en el umbral de la palabra).
  static const Curve _morphCurve = Curves.easeInOut;

  static const TextStyle _taglineStyle = TextStyle(
    color: Color(0xFFE3E9FF),
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 8,
    shadows: [
      Shadow(
        color: Color(0x66000B33),
        blurRadius: 12,
        offset: Offset(0, 6),
      ),
    ],
  );

  /// Color de cada palabra del tagline ("Watch.", "Read.", "Play.",
  /// "Anything"), en la misma familia cromática que las letras del título
  /// (plateado → azul #1CA0FD en el centro → morado #DB45FD), empezando
  /// igual de claro/plateado que la "F" para la primera palabra.
  static const List<Color> _taglineWordColors = [
    Color(0xFFE9EEF6), // Watch.   — plateado/blanco, igual que la F
    Color(0xFF1CA0FD), // Read.    — azul (centro del degradado del título)
    Color(0xFFC13FFD), // Play.    — morado intermedio
    Color(0xFFDB45FD), // Anything — morado final (igual que la V)
  ];

  late final AnimationController _controller;
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 13),
    );
    _controller.forward();
    _playLogo();
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Reproduce el audio logo de la splash.
  Future<void> _playLogo() async {
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource('audio/splash_reveal.mp3'));
  }

  /// Reinicia la animación y el audio desde cero.
  void _replay() {
    _controller
      ..reset()
      ..forward();
    _playLogo();
  }

  /// Resuelve la sesión y entra en la aplicación.
  Future<void> _enterApp() {
    return ref.read(authControllerProvider.notifier).enterApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/backgrounds/splash_back.png'),
            fit: BoxFit.cover,
            // Durante un hot reload Flutter re-resuelve los assets y puede
            // fallar momentáneamente; se ignora para no romper la vista.
            onError: (_, _) {},
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [_buildLetters(), _buildShineOverlay()],
                      ),
                    ),
                    // Tagline que aparece al terminar el brillo: un icono que
                    // morfea (TV → libro → mando → ∞) y las palabras que se
                    // revelan de una en una. AnimatedSize suaviza el empuje.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _taglineValue > 0
                          ? Padding(
                              padding: const EdgeInsets.only(top: 48),
                              child: AnimatedSlide(
                                offset: Offset(
                                  0,
                                  0.5 * (1 - _taglineValue),
                                ),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                child: AnimatedOpacity(
                                  opacity: _taglineValue,
                                  duration: const Duration(
                                    milliseconds: 700,
                                  ),
                                  curve: Curves.easeOut,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildTaglineIcon(),
                                      const SizedBox(height: 14),
                                      _buildTaglineWords(),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 72),
                    _buildControls(),
                    const SizedBox(height: 20),
                    const LanguageSelector(),
                    const SizedBox(height: 24),
                    _buildDevBadge(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Fila con cada letra del título rotando desde el perfil hasta frontal.
  Widget _buildLetters() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _title.length; i++)
          _LetterTile(
            letter: _title[i],
            angle: _letterAngle(i),
            gradient: _letterGradient(i),
            glow: i == _title.length - 1 ? _endGlowValue : 0,
            flareOpacity: i == _title.length - 1 ? _flareOpacity : 0,
            flareScale: i == _title.length - 1 ? _flareScale : 0,
            flareRotation: i == _title.length - 1 ? _flareRotation : 0,
          ),
      ],
    );
  }

  /// Color base de una letra de "FYNITIV": interpolado en tres tramos —
  /// plateado/blanco (F) → azul #1CA0FD (mitad) → morado #DB45FD (V) — para
  /// que la primera letra salga metálica/clara como en la referencia, en vez
  /// de arrancar ya en azul puro.
  static Color _letterColor(int index) {
    final t = index / (_title.length - 1);
    const colors = [
      Color(0xFFE9EEF6), // F — plateado/blanco azulado
      Color(0xFF1CA0FD), // mitad — azul
      Color(0xFFDB45FD), // V — morado
    ];
    const stops = [0.0, 0.5, 1.0];
    for (var i = 0; i < stops.length - 1; i++) {
      if (t <= stops[i + 1]) {
        final localT = ((t - stops[i]) / (stops[i + 1] - stops[i])).clamp(
          0.0,
          1.0,
        );
        return Color.lerp(colors[i], colors[i + 1], localT)!;
      }
    }
    return colors.last;
  }

  /// Degradado vertical (abajo→arriba) de una letra de "FYNITIV": abajo una
  /// versión oscura del color base, en medio una franja estrecha muy clara y
  /// arriba el color base — que a su vez sigue el esquema de tres paradas de
  /// [_letterColor] (plateado → azul → morado) según la posición de la letra.
  static LinearGradient _letterGradient(int index) {
    final base = _letterColor(index);
    final dark = Color.lerp(base, Colors.black, 0.3)!;
    final light = Color.lerp(base, Colors.white, 0.5)!;
    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [dark, light, base, base],
      stops: const [0.0, 0.42, 0.58, 1.0],
    );
  }

  /// Brillo que recorre el texto una vez las letras están alineadas.
  Widget _buildShineOverlay() {
    final t = _shineValue;
    if (t <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          // Barra de brillo que se desliza de izquierda a derecha.
          final slide = (-0.5 + t * 2.0).clamp(-0.5, 1.5);
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [
              (slide - 0.2).clamp(0.0, 1.0),
              slide.clamp(0.0, 1.0),
              (slide + 0.2).clamp(0.0, 1.0),
            ],
          ).createShader(bounds);
        },
        child: _buildLetters(),
      ),
    );
  }

  /// Valor 0→1 del tagline "Watch. Read. Play. Anything": aparece justo cuando
  /// el logo está totalmente desplegado y termina el barrido de brillo.
  double get _taglineValue {
    final t = Curves.easeOut.transform(
      ((_controller.value - _f(_tWatch)) / _f(0.4)).clamp(0.0, 1.0),
    );
    return t;
  }

  /// Valor 0→1 del barrido de brillo (ocurre al final de la animación).
  double get _shineValue {
    final t = Curves.easeInOut.transform(
      ((_controller.value - _f(5.8)) / _f(1.0)).clamp(0.0, 1.0),
    );
    return t;
  }

  /// Valor 0→1 del glow final sobre la última letra (aparece cuando el
  /// barrido de brillo llega a su fin).
  double get _endGlowValue {
    final t = Curves.easeOut.transform(
      ((_controller.value - _f(6.3)) / _f(1.0)).clamp(0.0, 1.0),
    );
    return t;
  }

  /// Ventana de tiempo (fracción 0→1) en la que ocurre el destello.
  double get _flareLocal {
    return ((_controller.value - _f(6.5)) / _f(1.5)).clamp(0.0, 1.0);
  }

  /// Opacidad del destello: encendido rápido y decaimiento exponencial.
  double get _flareOpacity {
    final local = _flareLocal;
    if (local <= 0) return 0;
    if (local < 0.25) return local / 0.25;
    return math.exp(-(local - 0.25) * 6.0);
  }

  /// Escala del destello: entra pequeño con rebote (overshoot elástico) y
  /// crece hasta un tamaño final grande.
  double get _flareScale {
    final e = (_flareLocal / 0.35).clamp(0.0, 1.0);
    return 0.5 + 3.5 * Curves.elasticOut.transform(e);
  }

  /// Rotación del destello: un leve giro al entrar que se estabiliza.
  double get _flareRotation {
    final e = (_flareLocal / 0.4).clamp(0.0, 1.0);
    return -0.35 + 0.35 * Curves.easeOutCubic.transform(e);
  }

  /// Ángulo de rotación Y de la letra [index]: de π/2 (perfil) a 0 (frontal),
  /// con desfase escalonado por letra en segundos.
  double _letterAngle(int index) {
    final start = _f(index * _staggerSeconds);
    final end = _f(index * _staggerSeconds + _rotateSeconds).clamp(0.0, 1.0);
    final local = Curves.easeOutCubic.transform(
      ((_controller.value - start) / (end - start)).clamp(0.0, 1.0),
    );
    return (math.pi / 2) * (1.0 - local);
  }

  /// Icono situado entre el título y el tagline. Usa MorphIcon controlado por
  /// el clock de 13s para que el morph termine EXACTAMENTE en el mismo instante
  /// en que se revela su palabra (TV → libro en [7.5,8.0], libro → mando en
  /// [8.5,9.0], mando → ∞ en [9.5,10.0]).
  Widget _buildTaglineIcon() {
    final t = _controller.value;
    if (t < _f(_tMorph1Start)) {
      return const Icon(_iconWatch, size: _iconSize, color: _iconColor);
    }
    if (t < _f(_tRead)) {
      return _morph(_iconWatch, _iconRead, _tMorph1Start, _tRead);
    }
    if (t < _f(_tPlay)) {
      return _morph(_iconRead, _iconPlay, _tMorph2Start, _tPlay);
    }
    if (t < _f(_tAnything)) {
      return _morph(_iconPlay, _iconAnything, _tMorph3Start, _tAnything);
    }
    return const Icon(_iconAnything, size: _iconSize, color: _iconColor);
  }

  /// Morph controlado entre dos iconos a lo largo de la ventana [start]→[end].
  /// Termina exactamente en [end], sincronizado con la palabra que se revela.
  Widget _morph(IconData from, IconData to, double start, double end) {
    final raw = ((_controller.value - _f(start)) / _f(end - start)).clamp(
      0.0,
      1.0,
    );
    return MorphIcon(
      from: from,
      to: to,
      progress: AlwaysStoppedAnimation(_morphCurve.transform(raw)),
      size: _iconSize,
      color: _iconColor,
    );
  }

  /// Fila del tagline: cada palabra se revela al cumplirse su umbral en el
  /// clock (7.0, 8.0, 9.0, 10.0) justo cuando el morph de su icono termina,
  /// acumulándose a la izquierda hasta "Watch. Read. Play. Anything".
  Widget _buildTaglineWords() {
    const words = [
      ('Watch.', _tWatch),
      ('Read.', _tRead),
      ('Play.', _tPlay),
      ('Anything', _tAnything),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < words.length; i++)
            AnimatedSlide(
              offset: Offset(
                0,
                _controller.value >= _f(words[i].$2) ? 0 : 0.3,
              ),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _controller.value >= _f(words[i].$2) ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Text(
                  words[i].$1,
                  style: _taglineStyle.copyWith(
                    color: _taglineWordColors[i],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleButton(
          onPressed: _enterApp,
          selectedScale: 1.2,
          borderRadius: BorderRadius.circular(60),
          child: Material(
            color: Colors.white.withValues(alpha: 0.20),
            shape: const CircleBorder(),
            elevation: 6,
            child: const Padding(
              padding: EdgeInsets.all(28),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 72,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Badge de pruebas del creador: solo visible en desarrollo para comprobar
  /// los flujos de la app (repetir presentación y resetear configuración).
  Widget _buildDevBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleButton(
            onPressed: _replay,
            selectedScale: 1.15,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.replay, size: 18, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text(
                    'Repetir presentación',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          ScaleButton(
            onPressed: _resetConfig,
            selectedScale: 1.15,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.delete_sweep_outlined,
                    size: 18,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Resetear configuración',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetConfig() async {
    await ref.read(authControllerProvider.notifier).resetAppData();
    if (!mounted) return;
    setState(() {
      _controller
        ..reset()
        ..forward();
    });
    _playLogo();
  }
}

/// Una letra del título con rotación 3D sobre su eje vertical, un degradado
/// vertical por letra y relieve (extrusión de capas de profundidad).
class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.angle,
    this.gradient,
    this.glow = 0,
    this.flareOpacity = 0,
    this.flareScale = 0,
    this.flareRotation = 0,
  });

  final String letter;
  final double angle;

  /// Degradado vertical de la cara frontal de la letra.
  final LinearGradient? gradient;

  /// Intensidad 0→1 del glow que envuelve la letra (usado en la última "V").
  final double glow;

  /// Opacidad del destello (0→1).
  final double flareOpacity;

  /// Escala del destello (rebote elástico).
  final double flareScale;

  /// Rotación del destello al entrar.
  final double flareRotation;

  /// Número de capas de profundidad del relieve.
  static const int _depth = 8;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0018)
        ..rotateY(angle),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Glow final: halo que rodea la letra y crece al terminar el brillo.
            if (glow > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: glow,
                    child: Center(
                      child: Container(
                        width: 360,
                        height: 360,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(
                                0xFFB06EFF,
                              ).withValues(alpha: 0.55 * glow),
                              const Color(0xFFB06EFF).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Extrusión 3D: capas de profundidad con tonos progresivamente
            // más claros hacia la cara frontal.
            for (var i = _depth; i >= 1; i--)
              Transform.translate(
                offset: Offset(0, i * 4.4),
                child: _face(
                  color: Color.lerp(
                    const Color(0xFF170A4D),
                    const Color(0xFF4A2AA0),
                    i / _depth,
                  )!,
                ),
              ),
            // Cara frontal con el degradado vertical de la letra. Lleva
            // outline blanco.
            _face(gradient: gradient, outline: true),
            // Destello (flare) final sobre la letra.
            if (flareOpacity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: flareOpacity,
                    child: Transform.rotate(
                      angle: flareRotation,
                      child: Transform.scale(
                        scale: flareScale,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 28, bottom: 20),
                          child: Center(
                            child: Image.asset(
                              'assets/images/flares/flare_01.png',
                              width: 600,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Dibuja la letra con un color sólido o un degradado y, opcionalmente, un
  /// outline blanco con un leve brillo que solo cubre la letra (no el relieve).
  Widget _face({
    Color? color,
    LinearGradient? gradient,
    bool outline = false,
  }) {
    final filled = Text(
      letter,
      style: TextStyle(
        color: color ?? Colors.white,
        fontSize: 160,
        fontWeight: FontWeight.w800,
        letterSpacing: 4,
        shadows: const [
          Shadow(
            color: Color(0x66000B33),
            blurRadius: 16,
            offset: Offset(0, 12),
          ),
        ],
      ),
    );

    Widget letterWidget = filled;
    if (gradient != null) {
      letterWidget = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => gradient.createShader(bounds),
        child: filled,
      );
    }

    if (!outline) return letterWidget;

    return Stack(
      alignment: Alignment.center,
      children: [
        letterWidget,
        Text(
          letter,
          style: TextStyle(
            fontSize: 160,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5
              ..color = const Color(0xFFFFFFFF),
            shadows: const [
              Shadow(
                color: Color(0x4DFFFFFF),
                blurRadius: 10,
                offset: Offset(0, 0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}