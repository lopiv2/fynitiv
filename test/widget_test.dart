import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fynitiv/app.dart';
import 'package:fynitiv/core/widgets/language_selector.dart';
import 'package:fynitiv/features/household/presentation/household_wizard_screen.dart';
import 'package:fynitiv/features/users/presentation/user_selection_screen.dart';
import 'package:fynitiv/router/splash_screen.dart';

void main() {
  testWidgets('La app sin servidor arranca con el wizard de configuración',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: FynitivApp()));

    // La splash animada se muestra al arrancar.
    expect(find.byType(SplashScreen), findsOneWidget);

    // El selector de idiomas está en la splash.
    expect(find.byType(LanguageSelector), findsOneWidget);

    // Al pulsar play, se resuelve la sesión y se entra en la app.
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Sin servidor, el wizard pide la URL en su primer paso.
    expect(find.byType(HouseholdWizardScreen), findsOneWidget);
    expect(find.text('URL del servidor'), findsOneWidget);
  });

  testWidgets('Con servidor y sin casa configurada entra al asistente',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'jellyfin.server_url': 'https://jellyfin.example.com',
    });
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: FynitivApp()));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdWizardScreen), findsOneWidget);
    expect(find.text('¿Quiénes son de esta casa?'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('Con servidor y casa configurada entra a la selección de usuarios',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'jellyfin.server_url': 'https://jellyfin.example.com',
      'jellyfin.server_id': 'server-1',
      'jellyfin.household': jsonEncode({
        'name': 'Casa Test',
        'members': [],
        'serverId': 'server-1',
      }),
    });
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: FynitivApp()));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(UserSelectionScreen), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('Casa de otro servidor va al asistente', (tester) async {
    SharedPreferences.setMockInitialValues({
      'jellyfin.server_url': 'https://jellyfin.example.com',
      'jellyfin.server_id': 'server-2',
      'jellyfin.household': jsonEncode({
        'name': 'Casa Antigua',
        'members': [],
        'serverId': 'server-1',
      }),
    });
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: FynitivApp()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdWizardScreen), findsOneWidget);
  });

  testWidgets('Desde la selección de usuarios se puede gestionar la casa',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'jellyfin.server_url': 'https://jellyfin.example.com',
      'jellyfin.server_id': 'server-1',
      'jellyfin.household': jsonEncode({
        'name': 'Casa Test',
        'members': [],
        'serverId': 'server-1',
      }),
    });
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: FynitivApp()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(UserSelectionScreen), findsOneWidget);

    // Abrimos la gestión de la casa desde el footer.
    await tester.tap(find.text('Gestionar casa'));
    await tester.pumpAndSettle();

    expect(find.byType(HouseholdWizardScreen), findsOneWidget);
    expect(find.text('¿Quiénes son de esta casa?'), findsOneWidget);
  });

  testWidgets('Migración desde formato antiguo userIds funciona',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'jellyfin.server_url': 'https://jellyfin.example.com',
      'jellyfin.server_id': 'server-1',
      'jellyfin.household': jsonEncode({
        'name': 'Casa Antigua',
        'userIds': <String>['old1'],
        'serverId': 'server-1',
      }),
    });
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: FynitivApp()));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Debe migrar y entrar a selección de usuarios.
    expect(find.byType(UserSelectionScreen), findsOneWidget);
  });
}
