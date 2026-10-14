import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSeasonalSuggestionsKey = 'jellyfin.seasonal_suggestions_enabled';

/// Preferencia persistente para mostrar recomendaciones de temporada en Inicio.
class SeasonalSuggestionsNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_kSeasonalSuggestionsKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_kSeasonalSuggestionsKey, enabled);
  }
}

final seasonalSuggestionsEnabledProvider =
    AsyncNotifierProvider<SeasonalSuggestionsNotifier, bool>(
      SeasonalSuggestionsNotifier.new,
    );
