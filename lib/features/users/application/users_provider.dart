import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../auth/application/auth_controller.dart';
import '../../household/application/household_provider.dart';

/// Lista de usuarios públicos del servidor Jellyfin configurado.
final publicUsersProvider = FutureProvider<List<UserDto>>((ref) {
  return ref.read(authControllerProvider.notifier).fetchPublicUsers();
});

/// Usuarios de la casa configurada: filtra la lista pública por los ids de la
/// casa. Si no hay casa, devuelve la lista vacía.
final householdUsersProvider = FutureProvider<List<UserDto>>((ref) {
  final household = ref.watch(householdProvider);
  return ref.watch(publicUsersProvider.future).then(
        (users) => household == null
            ? const <UserDto>[]
            : users.where((u) => household.userIds.contains(u.id)).toList(),
      );
});
