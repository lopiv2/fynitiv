import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../household/application/household_provider.dart';

/// Usuarios de la casa configurada: convierte los [HouseholdMember] locales
/// en [UserDto] sintéticos para la UI. Ya no consulta el endpoint público
/// del servidor, evitando exponer la lista de usuarios a cualquier dispositivo.
final householdUsersProvider = FutureProvider<List<UserDto>>((ref) async {
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
