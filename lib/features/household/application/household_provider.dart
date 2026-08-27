import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../household/domain/household.dart';

class _HouseholdInitializedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

/// Indica si la casa ya se ha cargado desde el almacenamiento.
///
/// Permite distinguir entre "aún cargando" (false + household == null) y
/// "cargado y sin casa configurada" (true + household == null).
final householdInitializedProvider =
    NotifierProvider<_HouseholdInitializedNotifier, bool>(
  _HouseholdInitializedNotifier.new,
);

/// Casa configurada en el dispositivo (null si aún no hay).
final householdProvider =
    NotifierProvider<HouseholdNotifier, Household?>(HouseholdNotifier.new);

class HouseholdNotifier extends Notifier<Household?> {
  @override
  Household? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final household = await ref.read(sessionStorageProvider).loadHousehold();
    state = household;
    ref.read(householdInitializedProvider.notifier).state = true;
  }

  /// Guarda la casa y actualiza el estado de forma inmediata.
  Future<void> save(Household household) async {
    final saved =
        await ref.read(sessionStorageProvider).saveHousehold(household);
    state = saved;
    ref.read(householdInitializedProvider.notifier).state = true;
  }

  /// Borra la casa del dispositivo.
  Future<void> clear() async {
    await ref.read(sessionStorageProvider).clearHousehold();
    state = null;
    ref.read(householdInitializedProvider.notifier).state = true;
  }
}

/// Guarda la casa y refresca el estado.
Future<void> saveHousehold(WidgetRef ref, Household household) async {
  await ref.read(householdProvider.notifier).save(household);
}
