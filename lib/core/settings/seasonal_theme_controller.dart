import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSeasonalThemeEnabledKey = 'jellyfin.seasonal_theme_enabled';
const _kSeasonalThemeIntensityKey = 'jellyfin.seasonal_theme_intensity';

/// Intensidad por defecto del matiz estacional (0..1): suave para no tapar la
/// identidad de skins con colores muy definidos.
const double kSeasonalThemeDefaultIntensity = 0.35;

/// Preferencia persistente para teñir el skin según la estación del año.
class SeasonalThemeEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_kSeasonalThemeEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_kSeasonalThemeEnabledKey, enabled);
  }
}

/// Preferencia persistente con la intensidad del matiz estacional (0..1).
class SeasonalThemeIntensityNotifier extends AsyncNotifier<double> {
  @override
  Future<double> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getDouble(_kSeasonalThemeIntensityKey) ??
        kSeasonalThemeDefaultIntensity;
  }

  Future<void> setIntensity(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    state = AsyncData(clamped);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_kSeasonalThemeIntensityKey, clamped);
  }
}

final seasonalThemeEnabledProvider =
    AsyncNotifierProvider<SeasonalThemeEnabledNotifier, bool>(
      SeasonalThemeEnabledNotifier.new,
    );

final seasonalThemeIntensityProvider =
    AsyncNotifierProvider<SeasonalThemeIntensityNotifier, double>(
      SeasonalThemeIntensityNotifier.new,
    );
