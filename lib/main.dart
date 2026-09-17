import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/audio/hover_sound_player.dart';
import 'core/audio/soloud_initializer.dart';
import 'core/constants/button_sounds.dart';
import 'core/network/image_http_overrides.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = FynitivHttpOverrides();
  MediaKit.ensureInitialized();
  // SoLoud para música (con fallback a MediaKit si falla)
  await SoloudInitializer.ensureInitialized();
  // Precalienta el logo de la splash (un solo fichero, se espera) y los
  // FX de hover en segundo plano para que arranquen sin delay de decode.
  try {
    await HoverSoundPlayer.instance.preload(['audio/splash_reveal.mp3']);
  } catch (_) {}
  unawaited(
    HoverSoundPlayer.instance.preload([
      for (final s in kButtonSounds) s.asset,
    ]),
  );
  runApp(const ProviderScope(child: FynitivApp()));
}
