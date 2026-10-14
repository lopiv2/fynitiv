import 'package:flutter_riverpod/flutter_riverpod.dart';

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
final effectiveSkinProvider = Provider<Skin>((ref) {
  final base =
      ref.watch(skinControllerProvider).value ?? SkinPresets.jellyfinDefault;
  final enabled = ref.watch(seasonalThemeEnabledProvider).value ?? true;
  if (!enabled) return base;
  final event = seasonalEventForDate(DateTime.now());
  if (event == null) return base;
  final intensity =
      ref.watch(seasonalThemeIntensityProvider).value ??
      kSeasonalThemeDefaultIntensity;
  return tintSkinForSeason(base, event, intensity);
});
