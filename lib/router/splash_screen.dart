import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:morphnext/morphnext.dart';

import '../core/audio/soloud_single_player.dart';
import '../core/seasonal/active_seasonal_event.dart';
import '../core/widgets/language_selector.dart';
import '../core/widgets/scale_button.dart';
import '../core/widgets/snow_drip.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/splash/presentation/presentations/splash_presentations.dart';
import '../l10n/app_localizations.dart';

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
    with TickerProviderStateMixin {
  static const String _title = 'FYNITIV';
  static const Duration _dripCycleDuration = Duration(milliseconds: 1800);
  late final List<GlobalKey> _letterKeys = List.generate(
    _title.length,
    (_) => GlobalKey(),
  );
  final GlobalKey _bloodRainOverlayKey = GlobalKey();

  int get _dripCycleIndex {
    final duration = _dripController.duration ?? _dripCycleDuration;
    return (_dripController.lastElapsedDuration?.inMicroseconds ?? 0) ~/
        duration.inMicroseconds;
  }

  /// Factor de velocidad acotado (menor = más lento, mayor = más rápido).
  static double _speedFactor(double speed) => speed.clamp(0.05, 4.0).toDouble();

  /// Crecimiento del capdrip dentro de la letra (fracción base 0.42..0.70).
  static double _capGrowBase(int seed) => 0.42 + _variation(seed, 71) * 0.28;

  /// Caída de la gota ya desprendida (fracción base 0.20..0.38).
  static double _capFallBase(int seed) => 0.20 + _variation(seed, 83) * 0.18;

  /// Escala del ciclo: cubre el capdrip más lento y la gota más lenta, de modo
  /// que ambos ritmos sean independientes y nadie se reinicie a mitad.
  static double _dripCycleScale(double dripSpeed, double fallSpeed) =>
      (0.70 / _speedFactor(dripSpeed) + 0.38 / _speedFactor(fallSpeed))
          .clamp(0.5, 40.0)
          .toDouble();

  static Duration _dripDurationFor(double dripSpeed, double fallSpeed) =>
      Duration(
        microseconds:
            (_dripCycleDuration.inMicroseconds *
                    _dripCycleScale(dripSpeed, fallSpeed))
                .round(),
      );

  static int _capSeedFor(int letterIndex, int cycleIndex) =>
      1009 + letterIndex * 7919 + cycleIndex * 104729;

  static double _variation(int seed, int salt) {
    var value = (seed * 1103515245 + 12345 + salt * 2654435761) & 0x7fffffff;
    value ^= value >> 13;
    value = (value * 1274126177) & 0x7fffffff;
    return (value & 0x7fffffff) / 0x7fffffff;
  }

  List<double>? _capDripProgresses(int letterIndex, int cycleIndex) {
    if (!_presentation.capDripsReachBottom) return null;
    final letterSeed = _capSeedFor(letterIndex, cycleIndex);
    final scale = _dripCycleScale(
      _presentation.capDripSpeed,
      _presentation.capFallSpeed,
    );
    final dripSpeed = _speedFactor(_presentation.capDripSpeed);
    return List<double>.generate(_presentation.capDrips, (dropIndex) {
      final seed = letterSeed ^ (dropIndex * 0x45d9f3b);
      final grow = (_capGrowBase(seed) / dripSpeed) / scale;
      return (_dripController.value / grow).clamp(0.0, 1.0).toDouble();
    });
  }

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
      Shadow(color: Color(0x66000B33), blurRadius: 12, offset: Offset(0, 6)),
    ],
  );

  /// Color de cada palabra del tagline ("Watch.", "Read.", "Play.",
  /// "Anything") — definido por la presentación estacional activa.

  late final AnimationController _controller;
  late final AnimationController _dripController;
  late final SoloudSinglePlayer _audioPlayer;

  /// Presentación estacional activa (se reevalúa en cada build).
  late SplashPresentation _presentation;
  List<_BloodGlyphMetrics> _bloodGlyphMetrics = const [];
  String? _bloodMetricsFontFamily;
  double? _bloodMetricsFontSize;
  TextScaler? _bloodMetricsTextScaler;
  TextDirection? _bloodMetricsTextDirection;

  @override
  void initState() {
    super.initState();
    _audioPlayer = SoloudSinglePlayer();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 13),
    );
    _dripController = AnimationController(
      vsync: this,
      duration: _dripCycleDuration,
    );
    _presentation = splashPresentationFor(
      ref.read(activeSeasonalEventProvider),
    );
    _controller.addStatusListener(_onPresentationStatusChanged);
    _controller.forward();
    _playAudio();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onPresentationStatusChanged);
    _controller.dispose();
    _dripController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onPresentationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _presentation.capAfterCompletion) {
      _dripController.duration = _dripDurationFor(
        _presentation.capDripSpeed,
        _presentation.capFallSpeed,
      );
      _dripController.repeat();
    }
  }

  /// Reproduce el audio de la presentación activa.
  Future<void> _playAudio() async {
    await _audioPlayer.stop();
    await _audioPlayer.playAsset(_presentation.audioAsset);
  }

  /// Reinicia la animación y el audio desde cero con la presentación actual.
  void _replay() {
    _dripController
      ..stop()
      ..value = 0;
    _controller
      ..reset()
      ..forward();
    _playAudio();
  }

  /// Resuelve la sesión y entra en la aplicación.
  Future<void> _enterApp() {
    return ref.read(authControllerProvider.notifier).enterApp();
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(activeSeasonalEventProvider);
    _presentation = splashPresentationFor(event);
    _ensureBloodGlyphMetrics(context);

    // Al cambiar la estación (calendario o selector de debug) se reinicia la
    // presentación y suena el audio de la nueva estación.
    ref.listen(activeSeasonalEventProvider, (previous, next) {
      if (previous == next) return;
      _presentation = splashPresentationFor(next);
      _replay();
    });

    final presentation = _presentation;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(presentation.backgroundAsset),
                fit: BoxFit.cover,
                // Durante un hot reload Flutter re-resuelve los assets y puede
                // fallar momentáneamente; se ignora para no romper la vista.
                onError: (_, _) {},
              ),
            ),
          ),
          if (presentation.backgroundTint case final tint?)
            Positioned.fill(
              child: IgnorePointer(child: ColoredBox(color: tint)),
            ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Capas de fondo de la estación (luna, niebla, imagen…).
                  for (final effect in presentation.backgroundEffects)
                    IgnorePointer(child: effect(context, _controller.value)),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [_buildLetters(), _buildShineOverlay()],
                            ),
                          ),
                          // Tagline que aparece al terminar el brillo: un icono
                          // que morfea (TV → libro → mando → ∞) y las palabras
                          // que se revelan de una en una. AnimatedSize suaviza
                          // el empuje.
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
                                      duration: const Duration(
                                        milliseconds: 700,
                                      ),
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
                          const SizedBox(height: 72),
                          const LanguageSelector(),
                          const SizedBox(height: 24),
                          _buildDevBadge(),
                          const SizedBox(height: 16),
                          _buildPlatformDisclaimer(),
                        ],
                      ),
                    ),
                  ),
                  // Capas decorativas de la estación (p. ej. murciélagos).
                  for (final effect in presentation.effects)
                    IgnorePointer(child: effect(context, _controller.value)),
                ],
              );
            },
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _dripController,
              builder: (context, _) {
                if (!_presentation.capAfterCompletion ||
                    !_controller.isCompleted) {
                  return const SizedBox.shrink();
                }
                return IgnorePointer(
                  child: CustomPaint(
                    key: _bloodRainOverlayKey,
                    painter: _BloodRainPainter(
                      letterKeys: _letterKeys,
                      overlayKey: _bloodRainOverlayKey,
                      glyphMetrics: _bloodGlyphMetrics,
                      progress: _dripController.value,
                      cycleIndex: _dripCycleIndex,
                      color: _presentation.capColor,
                      capDepth: _presentation.capDepth,
                      capDrips: _presentation.capDrips,
                      dripSpeed: _presentation.capDripSpeed,
                      fallSpeed: _presentation.capFallSpeed,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _ensureBloodGlyphMetrics(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    if (_bloodMetricsFontFamily == _presentation.titleFontFamily &&
        _bloodMetricsFontSize == _presentation.titleFontSize &&
        _bloodMetricsTextScaler == textScaler &&
        _bloodMetricsTextDirection == textDirection &&
        _bloodGlyphMetrics.length == _title.length) {
      return;
    }

    _bloodMetricsFontFamily = _presentation.titleFontFamily;
    _bloodMetricsFontSize = _presentation.titleFontSize;
    _bloodMetricsTextScaler = textScaler;
    _bloodMetricsTextDirection = textDirection;
    _bloodGlyphMetrics = [
      for (final letter in _title.split(''))
        _measureBloodGlyph(
          letter: letter,
          fontFamily: _presentation.titleFontFamily,
          fontSize: _presentation.titleFontSize,
          textScaler: textScaler,
          textDirection: textDirection,
        ),
    ];
  }

  _BloodGlyphMetrics _measureBloodGlyph({
    required String letter,
    required String? fontFamily,
    required double fontSize,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
        ),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    final line = painter.computeLineMetrics().first;
    return _BloodGlyphMetrics(
      width: painter.width,
      height: painter.height,
      baseline: line.baseline,
    );
  }

  /// Fila con cada letra del título rotando desde el perfil hasta frontal.
  Widget _buildLetters({bool attachRainKeys = true}) {
    return AnimatedBuilder(
      animation: _dripController,
      builder: (context, _) {
        final capStarted =
            !_presentation.capAfterCompletion || _controller.isCompleted;
        final dripCycleIndex = _dripCycleIndex;
        final capMelt = _presentation.capAfterCompletion
            ? (_presentation.capDripsReachBottom ? 1.0 : _dripController.value)
            : 0.5 + 0.18 * math.sin(_controller.value * 2 * math.pi * 1.5);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _title.length; i++)
              _LetterTile(
                faceKey: attachRainKeys ? _letterKeys[i] : null,
                letter: _title[i],
                angle: _letterAngle(i),
                gradient: _presentation.letterGradient(i, _title.length),
                fontFamily: _presentation.titleFontFamily,
                fontSize: _presentation.titleFontSize,
                capEnabled: _presentation.capEnabled && capStarted,
                capColor: _presentation.capColor,
                capShadowColor: _presentation.capShadowColor,
                capDepth: _presentation.capDepth,
                capDripMax: _presentation.capDripMax,
                capDrips: _presentation.capDrips,
                capDripsReachBottom: _presentation.capDripsReachBottom,
                capDripBottomRatio: _presentation.capDripsReachBottom
                    ? _bloodGlyphMetrics[i].baseline /
                          _bloodGlyphMetrics[i].height
                    : null,
                capDripProgresses: _capDripProgresses(i, dripCycleIndex),
                letterOutlineColor: _presentation.letterOutlineColor,
                letterOutlineWidth: _presentation.letterOutlineWidth,
                extrusionDark: _presentation.extrusionDark,
                extrusionLight: _presentation.extrusionLight,
                glowColor: _presentation.glowColor,
                flareAsset: _presentation.flareAsset,
                capSeed: _capSeedFor(i, dripCycleIndex),
                capMelt: capMelt,
                glow: i == _title.length - 1 ? _endGlowValue : 0,
                flareOpacity: i == _title.length - 1 ? _flareOpacity : 0,
                flareScale: i == _title.length - 1 ? _flareScale : 0,
                flareRotation: i == _title.length - 1 ? _flareRotation : 0,
              ),
          ],
        );
      },
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
        // El brillo dibuja una segunda copia del título. Esa copia no debe
        // compartir las GlobalKey que usa la capa de gotas para medir la base.
        child: _buildLetters(attachRainKeys: false),
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
      return Icon(
        _iconWatch,
        size: _iconSize,
        color: _presentation.iconColor,
        shadows: _presentation.iconShadows,
      );
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
    return Icon(
      _iconAnything,
      size: _iconSize,
      color: _presentation.iconColor,
      shadows: _presentation.iconShadows,
    );
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
      color: _presentation.iconColor,
      shadows: _presentation.iconShadows,
    );
  }

  /// Fila del tagline: cada palabra se revela al cumplirse su umbral en el
  /// clock (7.0, 8.0, 9.0, 10.0) justo cuando el morph de su icono termina,
  /// acumulándose a la izquierda hasta "Watch. Read. Play. Anything".
  Widget _buildTaglineWords() {
    final l10n = AppLocalizations.of(context)!;
    final words = [
      (l10n.splashWatch, _tWatch),
      (l10n.splashRead, _tRead),
      (l10n.splashPlay, _tPlay),
      (l10n.splashAnything, _tAnything),
    ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < words.length; i++)
            AnimatedSlide(
              offset: Offset(0, _controller.value >= _f(words[i].$2) ? 0 : 0.3),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _controller.value >= _f(words[i].$2) ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Text(
                  words[i].$1,
                  style: _taglineStyle.copyWith(
                    color: _presentation.taglineColor(i),
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

  /// Disclaimer de plataformas disponibles (Android, Linux y Windows).
  ///
  /// Se muestra en todas las presentaciones de splash (el `build` es común a
  /// las estaciones). El texto va por ARB; los nombres de plataforma son
  /// propios y no se traducen. Los botones del badge de desarrollo que hay
  /// encima mantienen sus textos fijos (norma de no traducir debug).
  Widget _buildPlatformDisclaimer() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.splashAvailableOn,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/android.svg',
              height: 28,
              semanticsLabel: 'Android',
            ),
            const SizedBox(width: 20),
            Image.asset(
              'assets/images/Linux-Logo.png',
              height: 38,
              semanticLabel: 'Linux',
            ),
            Image.asset(
              'assets/images/windows.png',
              height: 58,
              semanticLabel: 'Windows',
            ),
          ],
        ),
      ],
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
    _playAudio();
  }
}

/// Una letra del título con rotación 3D sobre su eje vertical, un degradado
/// vertical por letra y relieve (extrusión de capas de profundidad).
class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.angle,
    required this.extrusionDark,
    required this.extrusionLight,
    required this.glowColor,
    required this.flareAsset,
    required this.capEnabled,
    required this.capSeed,
    required this.capMelt,
    this.gradient,
    this.faceKey,
    this.fontFamily,
    this.fontSize = 160.0,
    this.capColor = const Color(0xFFF4FAFF),
    this.capShadowColor = const Color(0xCC183451),
    this.capDepth = 0.30,
    this.capDripMax = 0.13,
    this.capDrips = 3,
    this.capDripsReachBottom = false,
    this.capDripBottomRatio,
    this.capDripProgresses,
    this.letterOutlineColor = Colors.white,
    this.letterOutlineWidth = 3.5,
    this.glow = 0,
    this.flareOpacity = 0,
    this.flareScale = 0,
    this.flareRotation = 0,
  });

  final String letter;
  final double angle;

  /// Color de la capa de extrusión más profunda y más frontal.
  final Color extrusionDark;
  final Color extrusionLight;

  /// Color del halo/glow final.
  final Color glowColor;

  /// Asset del destello (flare) final.
  final String flareAsset;

  /// Casquete líquido sobre la letra (nieve, sangre...).
  final bool capEnabled;

  /// Semilla independiente para que cada glifo tenga chorretes propios.
  final int capSeed;

  /// Fase sutil del goteo/deshielo, conducida por el clock común de la splash.
  final double capMelt;

  /// Degradado vertical de la cara frontal de la letra.
  final LinearGradient? gradient;

  /// Clave solo para medir la tinta frontal, no la extrusión/sombra.
  final GlobalKey? faceKey;

  /// Familia tipográfica del título (viene de la presentación estacional).
  final String? fontFamily;

  /// Tamaño de la letra (viene de la presentación estacional).
  final double fontSize;

  /// Franja superior del casquete (viene de la presentación).
  final double capDepth;

  /// Longitud máxima de los chorretes del casquete (viene de la presentación).
  final double capDripMax;

  /// Número de chorretes del casquete por letra (viene de la presentación).
  final int capDrips;

  /// Extiende el extremo de cada capdrip hasta el baseline visible.
  final bool capDripsReachBottom;

  /// Baseline del glifo como fracción de la altura del texto.
  final double? capDripBottomRatio;

  /// Progreso individual de cada capdrip (0..1), si crecen a ritmos distintos.
  final List<double>? capDripProgresses;

  /// Color del casquete (viene de la presentación).
  final Color capColor;

  /// Sombra bajo el casquete (viene de la presentación).
  final Color capShadowColor;

  /// Color del borde (outline) de la letra (viene de la presentación).
  final Color letterOutlineColor;

  /// Grosor del borde (outline) de la letra (viene de la presentación).
  final double letterOutlineWidth;

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
                              glowColor.withValues(alpha: 0.55 * glow),
                              glowColor.withValues(alpha: 0.0),
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
                  color: Color.lerp(extrusionDark, extrusionLight, i / _depth)!,
                ),
              ),
            // Cara frontal con el degradado vertical de la letra. Lleva
            // outline blanco.
            _face(gradient: gradient, outline: true, textKey: faceKey),
            if (capEnabled)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipPath(
                    clipper: SnowDripClipper(
                      seed: capSeed,
                      depth: capDepth,
                      dripMax: capDripMax,
                      drips: capDrips,
                      melt: capMelt,
                      dripsReachBottom: capDripsReachBottom,
                      dripBottomRatio: capDripBottomRatio,
                      dripProgresses: capDripProgresses,
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: capColor,
                        fontFamily: fontFamily,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(
                            color: capShadowColor,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
                              flareAsset,
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
    GlobalKey? textKey,
  }) {
    final filled = Text(
      letter,
      key: textKey,
      style: TextStyle(
        color: color ?? Colors.white,
        fontFamily: fontFamily,
        fontSize: fontSize,
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
            fontFamily: fontFamily,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = letterOutlineWidth
              ..color = letterOutlineColor,
            shadows: [
              Shadow(
                color: letterOutlineColor.withValues(alpha: 0.30),
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

/// Gotas visibles que recorren la cara frontal de las letras tras la intro.
/// Cada gota deja un rastro corto y reinicia su caída con un desfase propio.
/// Gotas de sangre que caen desde el borde inferior de las letras hasta el
/// borde inferior de la ventana. Las posiciones de origen se obtienen de las
/// cajas reales del título, por lo que siguen el layout y el escalado del logo.
class _BloodRainPainter extends CustomPainter {
  const _BloodRainPainter({
    required this.letterKeys,
    required this.overlayKey,
    required this.glyphMetrics,
    required this.progress,
    required this.cycleIndex,
    required this.color,
    required this.capDepth,
    required this.capDrips,
    required this.dripSpeed,
    required this.fallSpeed,
  });

  final List<GlobalKey> letterKeys;
  final GlobalKey overlayKey;
  final List<_BloodGlyphMetrics> glyphMetrics;
  final double progress;
  final int cycleIndex;
  final Color color;
  final double capDepth;
  final int capDrips;
  final double dripSpeed;
  final double fallSpeed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final overlayObject = overlayKey.currentContext?.findRenderObject();
    if (overlayObject is! RenderBox || !overlayObject.attached) return;
    final overlayOrigin = overlayObject.localToGlobal(Offset.zero);
    final cycleScale = _SplashScreenState._dripCycleScale(dripSpeed, fallSpeed);
    final dripSpeedFactor = _SplashScreenState._speedFactor(dripSpeed);
    final fallSpeedFactor = _SplashScreenState._speedFactor(fallSpeed);

    for (var letterIndex = 0; letterIndex < letterKeys.length; letterIndex++) {
      final letterObject = letterKeys[letterIndex].currentContext
          ?.findRenderObject();
      if (letterObject is! RenderBox || !letterObject.attached) continue;
      if (letterIndex >= glyphMetrics.length) continue;
      final metrics = glyphMetrics[letterIndex];
      final baselineLeft =
          letterObject.localToGlobal(Offset(0, metrics.baseline)) -
          overlayOrigin;
      final baselineRight =
          letterObject.localToGlobal(Offset(metrics.width, metrics.baseline)) -
          overlayOrigin;
      final textWidth = (baselineRight - baselineLeft).distance;
      final capSeed = _SplashScreenState._capSeedFor(letterIndex, cycleIndex);
      final random = math.Random(capSeed);
      final capPhase = (capSeed % 17) * 0.37;
      final baseY = metrics.height * capDepth;

      for (var dropIndex = 0; dropIndex < capDrips; dropIndex++) {
        // Mantiene exactamente el centro/anchura aleatorios que usa
        // buildSnowDripPath para que la gota caiga desde el mismo capdrip.
        final jitter = (random.nextDouble() - 0.5) * (0.7 / capDrips);
        final centerFraction = (dropIndex + 0.5) / capDrips + jitter;
        final halfWidth = metrics.width * (0.035 + random.nextDouble() * 0.05);
        random
            .nextDouble(); // longitud del clipper, consumida para mantener la semilla alineada.

        final seed = capSeed ^ (dropIndex * 0x45d9f3b);
        final growBase = _SplashScreenState._capGrowBase(seed);
        final fallBase = _SplashScreenState._capFallBase(seed);
        final grow = (growBase / dripSpeedFactor) / cycleScale;
        final fall = (fallBase / fallSpeedFactor) / cycleScale;
        final fallEndsAt = (grow + fall).clamp(grow + 0.02, 0.995);
        final dropSpeed = 0.55 + _variation(seed, 17) * 1.30;
        final sizeFactor = 0.70 + _variation(seed, 59) * 0.90;
        final swayAmount = 2.0 + _variation(seed, 43) * 8.0;
        final swayPhase = _variation(seed, 47) * math.pi * 2;
        final wave =
            math.sin(centerFraction * math.pi * 3 + capPhase) *
            metrics.height *
            0.012;
        final localX = centerFraction * metrics.width;
        final localEdgeY = baseY + wave;
        final edge =
            letterObject.localToGlobal(Offset(localX, localEdgeY)) -
            overlayOrigin;
        final baseline =
            letterObject.localToGlobal(Offset(localX, metrics.baseline)) -
            overlayOrigin;

        // El capdrip recortado crece durante esta fase. Al llegar al baseline,
        // comienza la caída exterior desde el mismo extremo.
        if (progress < grow) continue;
        final rawFall = (progress - grow) / (fallEndsAt - grow);
        final fallProgress = math
            .pow(
              Curves.easeInCubic.transform(rawFall.clamp(0.0, 1.0)),
              1 / dropSpeed,
            )
            .toDouble();
        final width = (halfWidth * 2 * (textWidth / metrics.width) * sizeFactor)
            .clamp(3.5, 18.0)
            .toDouble();
        final swayProgress = Curves.easeOut.transform(rawFall.clamp(0.0, 1.0));
        final sway =
            math.sin(progress * math.pi * 2 + swayPhase) *
            swayAmount *
            swayProgress;
        final x = edge.dx + sway;

        if (progress < fallEndsAt) {
          final bodyGrowth = Curves.easeOut.transform(fallProgress);
          final bodyWidth = width * (0.48 + bodyGrowth * 0.52);
          final bodyHeight = bodyWidth * 1.75;
          final dropTipY =
              baseline.dy +
              (size.height - bodyHeight * 1.22 - baseline.dy) * fallProgress;
          final dropCenterY = dropTipY + bodyHeight * 0.56;
          final thread = Path()
            ..moveTo(baseline.dx, baseline.dy)
            ..cubicTo(
              baseline.dx + sway * 0.25,
              baseline.dy + bodyHeight * 0.16,
              x - sway * 0.20,
              dropTipY + bodyHeight * 0.04,
              x,
              dropTipY,
            );
          canvas.drawPath(
            thread,
            Paint()
              ..color = color.withValues(alpha: 0.28)
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.8, width * 0.10)
              ..strokeCap = StrokeCap.round,
          );
          _drawFallingMucus(
            canvas,
            center: Offset(x, dropCenterY),
            width: bodyWidth,
          );
        } else {
          final impactAge = ((progress - fallEndsAt) / (1 - fallEndsAt)).clamp(
            0.0,
            1.0,
          );
          final opacity = (1 - impactAge).clamp(0.0, 1.0);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, size.height - 3),
              width: width * (0.8 + impactAge * 1.8),
              height: width * (0.16 + (1 - impactAge) * 0.2),
            ),
            Paint()..color = color.withValues(alpha: 0.72 * opacity),
          );
        }
      }
    }
  }

  /// Pseudoaleatorio reproducible por gota y atributo, sin cambios entre frames.
  double _variation(int seed, int salt) {
    var value = (seed * 1103515245 + 12345 + salt * 2654435761) & 0x7fffffff;
    value ^= value >> 13;
    value = (value * 1274126177) & 0x7fffffff;
    return (value & 0x7fffffff) / 0x7fffffff;
  }

  void _drawFallingMucus(
    Canvas canvas, {
    required Offset center,
    required double width,
  }) {
    final height = width * 1.75;
    final tailLength = width * 0.75;
    final tail = Path()
      ..moveTo(center.dx, center.dy - height * 0.42 - tailLength)
      ..quadraticBezierTo(
        center.dx - width * 0.08,
        center.dy - height * 0.55,
        center.dx,
        center.dy - height * 0.34,
      )
      ..quadraticBezierTo(
        center.dx + width * 0.08,
        center.dy - height * 0.55,
        center.dx,
        center.dy - height * 0.42 - tailLength,
      )
      ..close();
    _drawGlossyPath(canvas, tail);

    // Gota con punta arriba y cuerpo redondeado abajo, estirada por la caída.
    final drop = Path()
      ..moveTo(center.dx, center.dy - height * 0.56)
      ..cubicTo(
        center.dx - width * 0.08,
        center.dy - height * 0.20,
        center.dx - width * 0.52,
        center.dy + height * 0.08,
        center.dx - width * 0.38,
        center.dy + height * 0.34,
      )
      ..cubicTo(
        center.dx - width * 0.18,
        center.dy + height * 0.66,
        center.dx + width * 0.34,
        center.dy + height * 0.61,
        center.dx + width * 0.43,
        center.dy + height * 0.30,
      )
      ..cubicTo(
        center.dx + width * 0.55,
        center.dy - height * 0.02,
        center.dx + width * 0.10,
        center.dy - height * 0.22,
        center.dx,
        center.dy - height * 0.56,
      )
      ..close();
    _drawGlossyPath(canvas, drop);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - width * 0.14, center.dy + height * 0.18),
        width: width * 0.16,
        height: height * 0.22,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.52),
    );
  }

  void _drawGlossyPath(Canvas canvas, Path path) {
    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.lerp(color, Colors.white, 0.28)!,
            color,
            Color.lerp(color, Colors.black, 0.30)!,
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(covariant _BloodRainPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.cycleIndex != cycleIndex ||
      oldDelegate.color != color ||
      oldDelegate.capDepth != capDepth ||
      oldDelegate.capDrips != capDrips ||
      oldDelegate.letterKeys != letterKeys ||
      oldDelegate.overlayKey != overlayKey ||
      oldDelegate.glyphMetrics != glyphMetrics;
}

class _BloodGlyphMetrics {
  const _BloodGlyphMetrics({
    required this.width,
    required this.height,
    required this.baseline,
  });

  final double width;
  final double height;
  final double baseline;
}
