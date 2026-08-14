import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/debug/device_simulator_host.dart';
import 'core/i18n/locale_provider.dart';
import 'core/skin/skin_controller.dart';
import 'core/skin/skin_presets.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';

class JellyfinitiveApp extends ConsumerWidget {
  const JellyfinitiveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider).value ?? const Locale('es');
    final themeMode =
        ref.watch(themeModeProvider).value ?? ThemeMode.system;
    final skin = ref.watch(skinControllerProvider).value;
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.fromSkin(skin ?? SkinPresets.jellyfinDefault),
      darkTheme: AppTheme.fromSkin(skin ?? SkinPresets.jellyfinDefault),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: [
        ...AppLocalizations.localizationsDelegates,
        ...GlobalMaterialLocalizations.delegates,
      ],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => DeviceSimulatorHost(child: child),
    );
  }
}

