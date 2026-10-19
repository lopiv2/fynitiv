import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'seasonal_event.dart';

/// Clave de `SharedPreferences` con la temática estacional elegida.
const kSeasonalEventOverrideStorageKey = 'jellyfin.seasonal_event_override';

/// Selección manual de la temática estacional.
///
/// `auto` (por defecto) usa la fecha real del dispositivo; el resto fuerza una
/// temática concreta o su ausencia (`none`) sin esperar al calendario. Se
/// comparte entre Apariencia y la barra de debug.
enum SeasonalEventOverride {
  auto,
  none,
  halloween,
  christmas,
  valentinesDay,
  easter,
}

/// Temática asociada a un override, o `null` para `auto`/`none`.
SeasonalEvent? seasonalEventOfOverride(SeasonalEventOverride override) =>
    switch (override) {
      SeasonalEventOverride.halloween => SeasonalEvent.halloween,
      SeasonalEventOverride.christmas => SeasonalEvent.christmas,
      SeasonalEventOverride.valentinesDay => SeasonalEvent.valentinesDay,
      SeasonalEventOverride.easter => SeasonalEvent.easter,
      SeasonalEventOverride.auto || SeasonalEventOverride.none => null,
    };

/// Convierte un nombre persistido en su override, con `auto` como fallback.
SeasonalEventOverride seasonalEventOverrideFromName(String? name) =>
    SeasonalEventOverride.values.asNameMap()[name] ??
    SeasonalEventOverride.auto;

/// Valor persistido leído en `main` antes de crear el `ProviderScope`.
///
/// Inyectarlo como override evita que la app arranque en `auto` y cambie de
/// estación (splash, skin) un instante después de cargar las preferencias.
final seasonalEventOverrideInitialProvider = Provider<SeasonalEventOverride>(
  (ref) => SeasonalEventOverride.auto,
);

/// Selección manual del tema estacional (persistida).
class SeasonalEventOverrideController extends Notifier<SeasonalEventOverride> {
  @override
  SeasonalEventOverride build() =>
      ref.watch(seasonalEventOverrideInitialProvider);

  Future<void> select(SeasonalEventOverride value) async {
    if (state == value) return;
    state = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(kSeasonalEventOverrideStorageKey, value.name);
  }
}

final seasonalEventOverrideProvider =
    NotifierProvider<SeasonalEventOverrideController, SeasonalEventOverride>(
      SeasonalEventOverrideController.new,
    );

/// Estación activa: la selección manual si la hay, o la del calendario.
final activeSeasonalEventProvider = Provider<SeasonalEvent?>((ref) {
  final override = ref.watch(seasonalEventOverrideProvider);
  if (override == SeasonalEventOverride.auto) {
    return seasonalEventForDate(DateTime.now());
  }
  return seasonalEventOfOverride(override);
});
