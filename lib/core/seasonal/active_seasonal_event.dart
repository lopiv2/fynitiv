import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'seasonal_event.dart';

/// Override manual de la estación activa, usado solo desde la barra de debug.
///
/// `auto` (por defecto) usa la fecha real del dispositivo; el resto fuerza una
/// temática concreta o su ausencia (`none`) para poder probar skins y
/// presentaciones sin esperar al calendario.
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

/// Selección manual del tema estacional (debug). No se persiste: arranca en
/// [SeasonalEventOverride.auto] en cada ejecución.
class SeasonalEventOverrideController extends Notifier<SeasonalEventOverride> {
  @override
  SeasonalEventOverride build() => SeasonalEventOverride.auto;

  void select(SeasonalEventOverride value) => state = value;
}

final seasonalEventOverrideProvider =
    NotifierProvider<SeasonalEventOverrideController, SeasonalEventOverride>(
      SeasonalEventOverrideController.new,
    );

/// True cuando la barra de debug está forzando una estación (o su ausencia),
/// es decir, cuando el override debe anular los ajustes de Ajustes.
final seasonalEventOverrideActiveProvider = Provider<bool>(
  (ref) =>
      ref.watch(seasonalEventOverrideProvider) != SeasonalEventOverride.auto,
);

/// Estación activa: el override de debug si lo hay, o la del calendario.
final activeSeasonalEventProvider = Provider<SeasonalEvent?>((ref) {
  final override = ref.watch(seasonalEventOverrideProvider);
  if (override == SeasonalEventOverride.auto) {
    return seasonalEventForDate(DateTime.now());
  }
  return seasonalEventOfOverride(override);
});
