import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';

import '../domain/emulator_profile.dart';
import 'emulator_preferences.dart';

/// Resultado de intentar lanzar el emulador.
class EmulatorLaunchResult {
  const EmulatorLaunchResult.ok({this.exit, this.pid})
    : ok = true,
      error = null;
  const EmulatorLaunchResult.fail(this.error)
    : ok = false,
      exit = null,
      pid = null;

  final bool ok;
  final String? error;

  /// Futuro que completa con el código de salida cuando el proceso del
  /// emulador termina (solo en Windows; null en el resto).
  final Future<int>? exit;
  final int? pid;
}

/// Lanza un emulador externo con un ROM local.
///
/// - Android: Intent con extras `ROM` / `LIBRETRO` (core) / `CONFIGFILE`.
/// - Windows: ejecutable configurable con plantilla de args (`%ROM%`).
class EmulatorLauncher {
  EmulatorLauncher();

  /// Mantién vivos los procesos lanzados (que no los recoja el GC antes de
  /// que completen su `exitCode`).
  static final List<Process> _live = <Process>[];

  /// Nombre de imagen (Windows) del último emulador lanzado, para poder
  /// limpiar instancias residentes al volver a la app.
  static String? lastImageName;

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  Future<EmulatorLaunchResult> launch({
    required Emulator emulator,
    required EmulatorOsSpec spec,
    required String romPath,
    required EmulatorPreferences prefs,
    String? coreName,
    String? configFilePath,
    List<String> extraArgs = const [],
  }) async {
    if (kIsWeb) return const EmulatorLaunchResult.fail('unsupported');
    if (Platform.isAndroid) {
      return _launchAndroid(
        emulator,
        spec,
        romPath,
        prefs,
        coreName,
        configFilePath,
      );
    }
    if (Platform.isWindows) {
      return _launchWindows(
        emulator,
        spec,
        romPath,
        prefs,
        coreName,
        configFilePath,
        extraArgs,
      );
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
      final isCore = spec.retroarchCore != null;
      final pkg = isCore
          ? (await prefs.androidPackage('retroarch') ?? 'com.retroarch')
          : (await prefs.androidPackage(emulator.id) ?? spec.package);
      if (pkg == null || pkg.isEmpty) {
        return const EmulatorLaunchResult.fail('no-package');
      }
      final activity = isCore
          ? 'com.retroarch.browser.retroactivity.RetroActivityFuture'
          : spec.activity;
      final core = isCore ? spec.retroarchCore : coreName;
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        package: pkg,
        componentName: activity != null ? '$pkg/$activity' : null,
        arguments: <String, dynamic>{
          'ROM': romPath,
          if (core != null && core.isNotEmpty)
            'LIBRETRO': '/data/data/$pkg/cores/${core}_libretro_android.so',
          if (configFilePath != null && configFilePath.isNotEmpty)
            'CONFIGFILE': configFilePath,
        },
      );
      await intent.launch();
      debugPrint(
        '[EmulatorLauncher] android pkg=$pkg activity=$activity rom=$romPath core=$core',
      );
      return const EmulatorLaunchResult.ok();
    } catch (e) {
      debugPrint('[EmulatorLauncher] android FAILED $e');
      return EmulatorLaunchResult.fail('$e');
    }
  }

  static Future<void> killProcess(int pid) async {
    try {
      if (Platform.isWindows) {
        // taskkill /F /T mata el proceso Y todos sus hijos
        await Process.run('taskkill', ['/F', '/T', '/PID', '$pid']);
      } else {
        Process.killPid(pid);
      }
    } catch (e) {
      debugPrint('[EmulatorLauncher] kill pid=$pid failed: $e');
    }
  }

  /// Mata todos los procesos con ese nombre de imagen en Windows
  /// (p. ej. `retroarch.exe`). RetroArch deja instancias residentes tras
  /// cerrar con ciertos cores (bug conocido) o en "handoff" de instancia
  /// única; esto limpia huérfanos por PID ya distinto al que lanzamos.
  static Future<void> killByImage(String imageName) async {
    if (!Platform.isWindows || imageName.isEmpty) return;
    try {
      await Process.run('taskkill', ['/F', '/T', '/IM', imageName]);
    } catch (e) {
      debugPrint('[EmulatorLauncher] kill image=$imageName failed: $e');
    }
  }

  Future<EmulatorLaunchResult> _launchWindows(
    Emulator emulator,
    EmulatorOsSpec spec,
    String romPath,
    EmulatorPreferences prefs,
    String? coreName,
    String? configFilePath,
    List<String> extraArgs,
  ) async {
    // ── Alternativa que es un core de RetroArch ──────────────────────────────
    if (spec.retroarchCore != null) {
      final raExe = await prefs.windowsExe('retroarch');
      if (raExe == null || raExe.isEmpty) {
        debugPrint(
          '[EmulatorLauncher] no retroarch exe for core ${spec.retroarchCore}',
        );
        return const EmulatorLaunchResult.fail('no-emulator');
      }
      final corePath =
          '${File(raExe).parent.path}${Platform.pathSeparator}cores'
          '${Platform.pathSeparator}${spec.retroarchCore}_libretro.dll';
      var args = '-L "$corePath" "$romPath"';
      if (configFilePath != null && configFilePath.isNotEmpty) {
        args = '--config "$configFilePath" $args';
      }
      if (extraArgs.isNotEmpty) {
        args = '$args ${extraArgs.join(' ')}';
      }
      return _startWindowsProcess(raExe, args);
    }

    final exe = await prefs.windowsExe(emulator.id);
    if (exe == null || exe.isEmpty) {
      debugPrint('[EmulatorLauncher] windows no exe for ${emulator.id}');
      return const EmulatorLaunchResult.fail('no-emulator');
    }

    // ── ScummVM: lanzamiento especial ────────────────────────────────────────
    if (emulator.id == 'scummvm') {
      return _launchScummVm(exe, romPath, configFilePath, extraArgs);
    }

    // ── Resto de emuladores: plantilla normal ─────────────────────────────────
    final template =
        await prefs.windowsArgs(emulator.id) ?? spec.args ?? '"%ROM%"';
    var args = template.replaceAll('%ROM%', romPath);
    // RetroArch base: fija el core de la plataforma con `-L` (si el catálogo
    // lo define) para no arrancar sin core.
    if (emulator.id == 'retroarch' &&
        coreName != null &&
        coreName.isNotEmpty) {
      final corePath =
          '${File(exe).parent.path}${Platform.pathSeparator}cores'
          '${Platform.pathSeparator}${coreName}_libretro.dll';
      args = '-L "$corePath" $args';
    }
    if (configFilePath != null && configFilePath.isNotEmpty) {
      args = '--config "$configFilePath" $args';
    }
    if (extraArgs.isNotEmpty) {
      args = '$args ${extraArgs.join(' ')}';
    }
    return _startWindowsProcess(exe, args);
  }

  Future<EmulatorLaunchResult> _startWindowsProcess(
    String exe,
    String args,
  ) async {
    final imageName = exe.split(RegExp(r'[/\\]+')).last;
    lastImageName = imageName;
    try {
      // Limpia instancias huérfanas previas del mismo emulador (RetroArch
      // puede quedar residente tras una sesión y provocar "handoff" en la
      // siguiente: el nuevo proceso sale con code=1 sin arrancar el juego).
      await killByImage(imageName);
      final exeFile = File(exe);
      final process = await Process.start(
        exe,
        _splitArgs(args),
        workingDirectory: await exeFile.exists() ? exeFile.parent.path : null,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );
      debugPrint(
        '[EmulatorLauncher] windows pid=${process.pid} launched: $exe $args',
      );
      _live.add(process);
      unawaited(
        process.exitCode
            .then((code) {
              _live.remove(process);
              debugPrint(
                '[EmulatorLauncher] windows exited pid=${process.pid} code=$code',
              );
              // Cierra cualquier hijo/instancia que quede residente.
              unawaited(killByImage(imageName));
            })
            .timeout(
              const Duration(minutes: 30),
              onTimeout: () async {
                debugPrint(
                  '[EmulatorLauncher] timeout pid=${process.pid} — forzando kill',
                );
                await killProcess(process.pid);
                _live.remove(process);
              },
            ),
      );
      return EmulatorLaunchResult.ok(exit: process.exitCode, pid: process.pid);
    } catch (e) {
      debugPrint(
        '[EmulatorLauncher] windows FAILED exe="$exe" args="$args": $e',
      );
      return EmulatorLaunchResult.fail('$e');
    }
  }

  /// Lanzamiento específico para ScummVM en Windows.
  ///
  /// Prioridad para resolver el gameid:
  ///   1. El playable es un archivo .scummvm → lee el gameid del interior.
  ///   2. La carpeta del playable contiene un .scummvm → ídem.
  ///   3. Fallback: abre ScummVM con --path apuntando a la carpeta (muestra launcher).
  ///
  /// Con gameid resuelto lanza: `scummvm.exe --path <dir> <gameid>`.
  /// Sin gameid lanza: `scummvm.exe --path=<dir>` (launcher normal).
  Future<EmulatorLaunchResult> _launchScummVm(
    String exe,
    String romPath,
    String? configFilePath,
    List<String> extraArgs,
  ) async {
    // 1 · Intenta leer el gameid desde el archivo .scummvm
    String? gameId = await readScummVmGameId(romPath);

    // 2 · Si el playable es una carpeta, busca un .scummvm dentro
    if (gameId == null) {
      final dir = Directory(romPath);
      if (await dir.exists()) {
        final scummFile = dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.scummvm'))
            .firstOrNull;
        if (scummFile != null) {
          gameId = await readScummVmGameId(scummFile.path);
        }
      }
    }

    debugPrint(
      '[EmulatorLauncher] scummvm gameid resuelto: ${gameId ?? "(ninguno, abriendo launcher)"}',
    );

    // Construye los argumentos según si tenemos gameid o no
    final List<String> scummArgs;
    if (gameId != null && gameId.isNotEmpty) {
      // Resuelve la carpeta: si el playable es un .scummvm, su padre es la carpeta del juego
      final gameFolder =
          File(romPath).existsSync() &&
              romPath.toLowerCase().endsWith('.scummvm')
          ? File(romPath).parent.path
          : romPath;

      scummArgs = [
        '--path=$gameFolder', // ← dónde están los archivos del juego
        if (configFilePath != null && configFilePath.isNotEmpty) ...[
          '-c',
          configFilePath,
        ],
        ...extraArgs.where(
          (a) =>
              !a.contains('--auto-run') &&
              !a.contains('--auto-detect') &&
              !a.contains('--path') &&
              !a.contains('--quit-after-play'),
        ),
        gameId, // ← el gameid SIEMPRE al final (si no: "Stray argument")
      ];
    } else {
      // Fallback: abre el launcher apuntando a la carpeta
      final folder = File(romPath).existsSync()
          ? File(romPath).parent.path
          : romPath;
      scummArgs = [
        '--path=$folder',
        if (configFilePath != null && configFilePath.isNotEmpty) ...[
          '-c',
          configFilePath,
        ],
        ...extraArgs.where(
          (a) => !a.contains('--auto-run') && !a.contains('--auto-detect'),
        ),
      ];
    }

    lastImageName = exe.split(RegExp(r'[/\\]+')).last;
    try {
      final exeFile = File(exe);
      final process = await Process.start(
        exe,
        scummArgs,
        workingDirectory: await exeFile.exists() ? exeFile.parent.path : null,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );
      debugPrint(
        '[EmulatorLauncher] scummvm pid=${process.pid} launched: $exe ${scummArgs.join(' ')}',
      );
      _live.add(process);
      unawaited(
        process.exitCode
            .then((code) async {
              _live.remove(process);
              debugPrint(
                '[EmulatorLauncher] scummvm exited pid=${process.pid} code=$code',
              );
              // Limpia cualquier proceso hijo que ScummVM haya dejado vivo
              await killProcess(process.pid);
              await killByImage(exe.split(RegExp(r'[/\\]+')).last);
            })
            .timeout(
              const Duration(minutes: 30),
              onTimeout: () async {
                debugPrint(
                  '[EmulatorLauncher] scummvm timeout pid=${process.pid} — forzando kill',
                );
                await killProcess(process.pid);
                _live.remove(process);
              },
            ),
      );
      return EmulatorLaunchResult.ok(exit: process.exitCode, pid: process.pid);
    } catch (e) {
      debugPrint(
        '[EmulatorLauncher] scummvm FAILED exe="$exe" args="${scummArgs.join(' ')}": $e',
      );
      return EmulatorLaunchResult.fail('$e');
    }
  }

  /// Lee el gameid de un `.scummvm` (texto plano, primera línea no vacía).
  /// Acepta tanto la ruta del `.scummvm` como la carpeta del juego (busca el
  /// `.scummvm` dentro). Público para reutilizarlo al generar los metadatos
  /// de sync y mapear las partidas de ScummVM (`<gameid>.sNN`).
  static Future<String?> readScummVmGameId(String path) async {
    var target = path;
    if (!path.toLowerCase().endsWith('.scummvm')) {
      final dir = Directory(path);
      if (!await dir.exists()) return null;
      final scumm = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.scummvm'))
          .firstOrNull;
      if (scumm == null) return null;
      target = scumm.path;
    }
    try {
      final content = await File(target).readAsString();
      var id = content.trim().split('\n').first.trim();
      // ScummVM guarda "engine:gameid" (p.ej. "scumm:monkey2") pero el
      // argumento de línea de comandos solo acepta la parte del gameid
      if (id.contains(':')) id = id.split(':').last.trim();
      return id.isNotEmpty ? id : null;
    } catch (e) {
      debugPrint('[EmulatorLauncher] no se pudo leer .scummvm "$target": $e');
      return null;
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
