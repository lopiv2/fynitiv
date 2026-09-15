import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/audio/soloud_initializer.dart';
import 'core/network/image_http_overrides.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = FynitivHttpOverrides();
  MediaKit.ensureInitialized();
  // SoLoud para música (con fallback a MediaKit si falla)
  await SoloudInitializer.ensureInitialized();
  runApp(const ProviderScope(child: FynitivApp()));
}
