import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jellyfinitive/app.dart';
import 'package:jellyfinitive/features/household/presentation/household_wizard_screen.dart';
import 'package:jellyfinitive/features/users/application/users_provider.dart';
import 'package:jellyfinitive/features/users/presentation/user_selection_screen.dart';

void main() {
  testWidgets('Gestionar casa: guardar vuelve a la selección de usuarios',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'jellyfin.server_url': 'https://jellyfin.example.com',
      'jellyfin.server_id': 'server-1',
      'jellyfin.household': jsonEncode({
        'name': 'Casa Test',
        'userIds': <String>['u1'],
        'serverId': 'server-1',
        'pinHash': null,
      }),
    });
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(ProviderScope(
      overrides: [
        publicUsersProvider.overrideWith((ref) async => [
              UserDto(name: 'Ana', id: 'u1'),
              UserDto(name: 'Luis', id: 'u2'),
            ]),
      ],
      child: const JellyfinitiveApp(),
    ));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // En la selección de usuarios, abrimos gestión de la casa.
    expect(find.byType(UserSelectionScreen), findsOneWidget);
    await tester.tap(find.text('Gestionar casa'));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdWizardScreen), findsOneWidget);

    // Paso de usuarios → siguiente.
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    // Paso de nombre + PIN. Nombre precargado, PIN vacío (mantener actual).
    expect(find.text('Guardar'), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdWizardScreen), findsNothing);
    expect(find.byType(UserSelectionScreen), findsOneWidget);
  });
}
