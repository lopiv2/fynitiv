import 'package:material_ui/material_ui.dart';

import '../../domain/splash_presentation.dart';

/// Presentación por defecto (sin estación activa): replica exacta de la splash
/// original — degradado plateado → azul → morado y audio `splash_reveal.mp3`.
const SplashPresentation kDefaultSplashPresentation = SplashPresentation(
  id: 'default',
  audioAsset: 'audio/splash_reveal.mp3',
  backgroundAsset: 'assets/images/backgrounds/splash_back.png',
  letterStops: [
    Color(0xFFE9EEF6), // plateado/blanco azulado
    Color(0xFF1CA0FD), // azul
    Color(0xFFDB45FD), // morado
  ],
  taglineColors: [
    Color(0xFFE9EEF6), // Watch.   — plateado/blanco
    Color(0xFF1CA0FD), // Read.    — azul
    Color(0xFFC13FFD), // Play.    — morado intermedio
    Color(0xFFDB45FD), // Anything — morado final
  ],
  extrusionDark: Color(0xFF170A4D),
  extrusionLight: Color(0xFF4A2AA0),
  glowColor: Color(0xFFB06EFF),
);
