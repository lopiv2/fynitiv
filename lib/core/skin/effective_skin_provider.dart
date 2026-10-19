import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../seasonal/active_seasonal_event.dart';
import '../seasonal/seasonal_event.dart';
import '../settings/seasonal_theme_controller.dart';
import 'skin.dart';
import 'skin_controller.dart';
import 'skin_presets.dart';

/// Skin activo con el matiz estacional aplicado cuando corresponde.
///
/// Si el tema estacional está activado, hay una temática de calendario activa y
/// la intensidad es mayor que cero, devuelve una copia teñida del skin (fondo,
/// acento y primario). En caso contrario devuelve el skin sin tocar. Nunca
/// modifica el skin persistido del usuario.
///
/// La estación elegida manualmente (Apariencia o barra de debug) sustituye a la
/// del calendario, pero el interruptor "Tema estacional" sigue mandando.
final effectiveSkinProvider = Provider<Skin>((ref) {
  final base =
      ref.watch(skinControllerProvider).value ?? SkinPresets.jellyfinDefault;
  final enabled = ref.watch(seasonalThemeEnabledProvider).value ?? true;
  if (!enabled) return base;
  final event = ref.watch(activeSeasonalEventProvider);
  if (event == null) return base;
  final intensity =
      ref.watch(seasonalThemeIntensityProvider).value ??
      kSeasonalThemeDefaultIntensity;
  return tintSkinForSeason(base, event, intensity);
});
