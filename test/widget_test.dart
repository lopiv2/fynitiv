import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jellyfinitive/app.dart';
import 'package:jellyfinitive/router/splash_screen.dart';

void main() {
  testWidgets('La app arranca con la pantalla de login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: JellyfinitiveApp()));

    // La splash animada se muestra al arrancar.
    expect(find.byType(SplashScreen), findsOneWidget);

    // Al pulsar play, se resuelve la sesión y se entra en la app.
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Jellyfinitive'), findsOneWidget);
    expect(find.text('URL del servidor'), findsOneWidget);
  });
}
