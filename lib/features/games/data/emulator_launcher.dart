import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';

import '../domain/emulator_profile.dart';
import 'emulator_preferences.dart';

/// Resultado de intentar lanzar el emulador.
class EmulatorLaunchResult {
  const EmulatorLaunchResult.ok() : ok = true, error = null;
  const EmulatorLaunchResult.fail(this.error) : ok = false;

  final bool ok;
  final String? error;
}

/// Lanza un emulador externo con un ROM local.
///
/// - Android: Intent con extras `ROM` / `LIBRETRO` (core) / `CONFIGFILE`.
/// - Windows: ejecutable configurable con plantilla de args (`%ROM%`).
class EmulatorLauncher {
  EmulatorLauncher();

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  Future<EmulatorLaunchResult> launch({
    required Emulator emulator,
    required EmulatorOsSpec spec,
    required String romPath,
    required EmulatorPreferences prefs,
    String? coreName,
    String? configFilePath,
  }) async {
    if (kIsWeb) return const EmulatorLaunchResult.fail('unsupported');
    if (Platform.isAndroid) {
      return _launchAndroid(emulator, spec, romPath, prefs, coreName, configFilePath);
    }
    if (Platform.isWindows) {
      return _launchWindows(emulator, spec, romPath, prefs, configFilePath);
    }
    return const EmulatorLaunchResult.fail('unsupported');
  }

  Future<EmulatorLaunchResult> _launchAndroid(
    Emulator emulator,
    EmulatorOsSpec spec,
    String romPath,
    EmulatorPreferences prefs,
    String? coreName,
    String? configFilePath,
  ) async {
    try {
      final pkg = await prefs.androidPackage(emulator.id) ?? spec.package;
      if (pkg == null || pkg.isEmpty) {
        return const EmulatorLaunchResult.fail('no-package');
      }
      final activity = spec.activity;
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        package: pkg,
        componentName: activity != null ? '$pkg/$activity' : null,
        arguments: <String, dynamic>{
          'ROM': romPath,
          if (coreName != null && coreName.isNotEmpty)
            'LIBRETRO': '/data/data/$pkg/cores/${coreName}_libretro_android.so',
          if (configFilePath != null && configFilePath.isNotEmpty)
            'CONFIGFILE': configFilePath,
        },
      );
      await intent.launch();
      return const EmulatorLaunchResult.ok();
    } catch (e) {
      return EmulatorLaunchResult.fail('$e');
    }
  }

  Future<EmulatorLaunchResult> _launchWindows(
    Emulator emulator,
    EmulatorOsSpec spec,
    String romPath,
    EmulatorPreferences prefs,
    String? configFilePath,
  ) async {
    final exe = await prefs.windowsExe(emulator.id);
    if (exe == null || exe.isEmpty) {
      return const EmulatorLaunchResult.fail('no-emulator');
    }
    final template = await prefs.windowsArgs(emulator.id) ??
        spec.args ??
        '"%ROM%"';
    var args = template.replaceAll('%ROM%', romPath);
    if (configFilePath != null && configFilePath.isNotEmpty) {
      args = '--config "$configFilePath" $args';
    }
    try {
      await Process.start(
        exe,
        _splitArgs(args),
        runInShell: false,
        mode: ProcessStartMode.detached,
      );
      return const EmulatorLaunchResult.ok();
    } catch (e) {
      return EmulatorLaunchResult.fail('$e');
    }
  }

  /// Divide una plantilla de argumentos respetando comillas dobles.
  static List<String> _splitArgs(String input) {
    final out = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (final ch in input.runes) {
      final c = String.fromCharCode(ch);
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ' ' && !inQuotes) {
        if (buffer.isNotEmpty) {
          out.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(c);
      }
    }
    if (buffer.isNotEmpty) out.add(buffer.toString());
    return out;
  }
}
