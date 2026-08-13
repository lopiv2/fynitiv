import 'dart:math' as math;

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/widgets/language_selector.dart';
import '../core/widgets/scale_button.dart';
import '../features/auth/application/auth_controller.dart';
import '../l10n/app_localizations.dart';

/// Pantalla de bienvenida con el logo animado en 3D.
///
/// Las letras del título comienzan en perfil (giradas 90° sobre su eje Y, de
/// modo que solo se ve una línea vertical) y rotan de forma escalonada hasta
/// revelar "JELLYFINITIVE". Un brillo recorre el texto al final.
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
  static const String _title = 'JELLYFINITIVE';

  /// Duración total de la animación en segundos (sincronizada con el audio logo).
  static const double _totalSeconds = 14;

  /// Convierte segundos absolutos a fracción del controller.
  static double _f(double seconds) => seconds / _totalSeconds;

  /// Desfase de inicio de la rotación de cada letra (segundos).
  static const double _staggerSeconds = 0.5;

  /// Duración de la rotación de cada letra (segundos).
  static const double _rotateSeconds = 4.5;

  late final AnimationController _controller;
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
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
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/backgrounds/splash_back.png'),
            fit: BoxFit.cover,
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
                    // Tagline que aparece con efecto scramble al terminar el
                    // brillo. AnimatedSize suaviza el empuje del botón play.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _taglineValue > 0
                          ? Padding(
                              padding: const EdgeInsets.only(top: 48),
                              child: SizedBox(
                                height: 72,
                                child: Center(
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
                                      child: AnimatedTextKit(
                                        isRepeatingAnimation: false,
                                        animatedTexts: [
                                          ScrambleAnimatedText(
                                            AppLocalizations.of(
                                              context,
                                            )!.splashTagline,
                                            textAlign: TextAlign.center,
                                            speed: const Duration(
                                              milliseconds: 60,
                                            ),
                                            textStyle: const TextStyle(
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
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
            glow: i == _title.length - 1 ? _endGlowValue : 0,
            flareOpacity: i == _title.length - 1 ? _flareOpacity : 0,
            flareScale: i == _title.length - 1 ? _flareScale : 0,
            flareRotation: i == _title.length - 1 ? _flareRotation : 0,
          ),
      ],
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

  /// Valor 0→1 del tagline "The definitive experience": aparece justo cuando
  /// termina el barrido de brillo.
  double get _taglineValue {
    final t = Curves.easeOut.transform(
      ((_controller.value - _f(12.5)) / _f(1.5)).clamp(0.0, 1.0),
    );
    return t;
  }

  /// Valor 0→1 del barrido de brillo (ocurre al final de la animación).
  double get _shineValue {
    final t = Curves.easeInOut.transform(
      ((_controller.value - _f(10.5)) / _f(1.5)).clamp(0.0, 1.0),
    );
    return t;
  }

  /// Valor 0→1 del glow final sobre la última letra (aparece cuando el
  /// barrido de brillo llega a su fin).
  double get _endGlowValue {
    final t = Curves.easeOut.transform(
      ((_controller.value - _f(11.5)) / _f(1.5)).clamp(0.0, 1.0),
    );
    return t;
  }

  /// Ventana de tiempo (fracción 0→1) en la que ocurre el destello.
  double get _flareLocal {
    return ((_controller.value - _f(11)) / _f(2.5)).clamp(0.0, 1.0);
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

/// Una letra del título con rotación 3D sobre su eje vertical, degradado
/// azul→violeta y relieve (extrusión de capas de profundidad).
class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.angle,
    this.glow = 0,
    this.flareOpacity = 0,
    this.flareScale = 0,
    this.flareRotation = 0,
  });

  final String letter;
  final double angle;

  /// Intensidad 0→1 del glow que envuelve la letra (usado en la última "E").
  final double glow;

  /// Opacidad del destello (0→1).
  final double flareOpacity;

  /// Escala del destello (rebote elástico).
  final double flareScale;

  /// Rotación del destello al entrar.
  final double flareRotation;

  /// Degradado de la cara frontal de cada letra.
  static const LinearGradient _faceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3FA2FF), Color(0xFF8A5BFF), Color(0xFFB06EFF)],
  );

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
            // Cara frontal con el degradado azul→violeta.
            _face(gradient: _faceGradient),
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
                          padding: const EdgeInsets.only(left: 10, bottom: 10),
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

  /// Dibuja la letra con un color sólido o un degradado.
  Widget _face({Color? color, LinearGradient? gradient}) {
    final text = Text(
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
    if (gradient == null) return text;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: text,
    );
  }
}
