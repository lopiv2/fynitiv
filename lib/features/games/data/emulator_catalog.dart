import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/emulator_profile.dart';

/// Catálogo de emuladores cargado desde `assets/data/emulators.json`.
final emulatorCatalogProvider = FutureProvider<EmulatorCatalog>((ref) async {
  final raw = await rootBundle.loadString('assets/data/emulators.json');
  return EmulatorCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
});
