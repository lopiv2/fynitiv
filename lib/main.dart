import 'dart:async';
import 'dart:io';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/audio/hover_sound_player.dart';
import 'core/audio/soloud_initializer.dart';
import 'core/constants/button_sounds.dart';
import 'core/network/image_http_overrides.dart';
import 'core/seasonal/active_seasonal_event.dart';

void _configEasyLoading() {
  // Estilo universal de notificaciones/toasts (ver AGENTS.md).
  EasyLoading.instance
    ..loadingStyle = EasyLoadingStyle.custom
    ..backgroundColor = const Color(0xFF1E1E2E)
    ..textColor = Colors.white
    ..indicatorColor = const Color(0xFF4DD0E1)
    ..fontSize = 13
    ..radius = 12
    ..toastPosition = EasyLoadingToastPosition.bottom
    ..displayDuration = const Duration(seconds: 2)
    ..dismissOnTap = true
    ..maskType = EasyLoadingMaskType.none;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = FynitivHttpOverrides();
  // Preferencia de certificados TLS no válidos (autofirmados). Se aplica antes
  // de cualquier petición (Jellyfin, imágenes, Seerr…).
  var seasonalOverride = SeasonalEventOverride.auto;
  try {
    final prefs = await SharedPreferences.getInstance();
    FynitivHttpOverrides.allowBadCertificates =
        prefs.getBool('app.allow_bad_certificates') ?? true;
    // La estación elegida se lee antes del primer frame para que splash y skin
    // arranquen ya con ella (sin parpadear a `auto`).
    seasonalOverride = seasonalEventOverrideFromName(
      prefs.getString(kSeasonalEventOverrideStorageKey),
    );
  } catch (_) {}
  MediaKit.ensureInitialized();
  _configEasyLoading();
  // SoLoud para música (con fallback a MediaKit si falla)
  await SoloudInitializer.ensureInitialized();
  // Precalienta el logo de la splash (un solo fichero, se espera) y los
  // FX de hover en segundo plano para que arranquen sin delay de decode.
  try {
    await HoverSoundPlayer.instance.preload([
      'audio/splash_reveal.mp3',
      // Presentaciones estacionales (el cambio de estación suena sin delay).
      'audio/halloween_splash_reveal.mp3',
      'audio/christmas_splash_reveal.mp3',
    ]);
  } catch (_) {}
  unawaited(
    HoverSoundPlayer.instance.preload([
      for (final s in kButtonSounds) s.asset,
    ]),
  );
  runApp(
    ProviderScope(
      overrides: [
        seasonalEventOverrideInitialProvider.overrideWithValue(
          seasonalOverride,
        ),
      ],
      child: const FynitivApp(),
    ),
  );
}
