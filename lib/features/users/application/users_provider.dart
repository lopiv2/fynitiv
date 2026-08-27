import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../household/application/household_provider.dart';

/// Usuarios de la casa configurada: convierte los [HouseholdMember] locales
/// en [UserDto] sintéticos para la UI. Ya no consulta el endpoint público
/// del servidor, evitando exponer la lista de usuarios a cualquier dispositivo.
///
/// Permanece en estado `loading` hasta que [householdInitializedProvider] sea
/// true, de modo que la UI puede mostrar [AppLoader] mientras se lee el
/// household de [SharedPreferences].
final householdUsersProvider = FutureProvider<List<UserDto>>((ref) async {
  final initialized = ref.watch(householdInitializedProvider);
  if (!initialized) {
    // Mantiene el provider en AsyncLoading hasta que el HouseholdNotifier
    // termine de cargar. Cuando [householdInitializedProvider] cambie a true,
    // Riverpod recreará este provider y seguirá con la lógica real.
    await Completer<List<UserDto>>().future;
    return const <UserDto>[];
  }
  final household = ref.watch(householdProvider);
  if (household == null) return const <UserDto>[];
  return household.members
      .map(
        (m) => UserDto(
          id: m.id,
          name: m.name,
          primaryImageTag: m.primaryImageTag,
        ),
      )
      .toList();
});
