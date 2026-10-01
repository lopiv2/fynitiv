import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/di/providers.dart';
import '../../downloads/application/download_manager_provider.dart';
import '../data/emulator_catalog.dart';
import '../data/emulator_launcher.dart';
import '../data/emulator_preferences.dart';
import '../data/local_game_store.dart';
import '../data/romm_repository.dart';
import '../data/romm_storage.dart';
import '../domain/emulator_profile.dart';
import '../domain/romm_config.dart';
import '../domain/romm_game.dart';
import '../domain/romm_platform.dart';

/// Scopes que pide fynitiv al emparejar por QR.
const kRommRequestedScopes = <String>[
  'me.read',
  'me.write',
  'roms.read',
  'roms.user.read',
  'roms.user.write',
  'platforms.read',
  'assets.read',
  'assets.write',
  'devices.read',
  'devices.write',
  'firmware.read',
];

/// Resultado final del emparejamiento por QR.
enum RommPairOutcome { approved, denied, expired, cancelled }


final rommStorageProvider = Provider<RommStorage>(
  (ref) => RommStorage(secure: ref.watch(flutterSecureStorageProvider)),
);

/// Almacén local de ROMs descargadas.
final localGameStoreProvider = Provider<LocalGameStore>(
  (ref) => LocalGameStore(),
);

/// Lanzador de emulador externo (Android RetroArch / Windows exe).
final emulatorLauncherProvider = Provider<EmulatorLauncher>(
  (ref) => EmulatorLauncher(),
);

/// Preferencias de emuladores (asociación por plataforma y overrides).
final emulatorPreferencesProvider = Provider<EmulatorPreferences>(
  (ref) => EmulatorPreferences(),
);

/// Estados del flujo de juego local.
enum LocalPlayStatus { downloading, downloaded, launched, noFile, noEmulator, error }

class LocalPlayResult {
  const LocalPlayResult(this.status, {this.path, this.message});

  final LocalPlayStatus status;
  final String? path;
  final String? message;
}

/// Orquesta BIOS → ROM → lanzamiento en el emulador asociado a la plataforma.
class LocalPlayController {
  LocalPlayController(this.ref);

  final Ref ref;

  Future<LocalPlayResult> play(
    RommGame game, {
    required String doneMessage,
    required String failMessage,
  }) async {
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) {
      return const LocalPlayResult(LocalPlayStatus.error, message: 'no-session');
    }
    final fileName = game.firstFile;
    if (fileName == null || fileName.isEmpty) {
      return const LocalPlayResult(LocalPlayStatus.noFile);
    }
    final store = ref.read(localGameStoreProvider);
    final prefs = ref.read(emulatorPreferencesProvider);
    final catalog = await ref.read(emulatorCatalogProvider.future);

    // Emulador asociado (o recomendado por SO) para la plataforma.
    final platformEmus = catalog.forPlatform(game.platformSlug);
    final associated = await prefs.association(game.platformSlug);
    final recommended = _isAndroid
        ? platformEmus?.recommendedAndroid
        : platformEmus?.recommendedWindows;
    final emulator = catalog.emulatorById(associated) ??
        catalog.emulatorById(recommended);
    final spec = emulator == null ? null : _specForOs(emulator);
    if (emulator == null || spec == null) {
      return const LocalPlayResult(LocalPlayStatus.noEmulator);
    }

    final dir = await store.platformDir(game.platformSlug);
    final localPath = store.localPathFor(dir, fileName);
    final hasRom = await store.isDownloaded(localPath);

    if (!hasRom) {
      await ref.read(downloadManagerProvider.notifier).enqueue(
            url: repo.downloadUrl(game.id, fileName),
            fileName: fileName,
            sourceLabel: game.name,
            destinationDir: dir,
            headers: _authHeaders(repo),
            doneMessage: doneMessage,
            failMessage: failMessage,
          );
    }
    // BIOS: best-effort, en segundo plano y solo si falta el ROM.
    unawaitedOrNull(_ensureBios(repo, store, prefs, emulator.id, game.platformId));

    if (!hasRom) {
      return LocalPlayResult(LocalPlayStatus.downloading, path: localPath);
    }

    final playable = await store.resolvePlayableFile(localPath);
    final launcher = ref.read(emulatorLauncherProvider);
    if (!launcher.isSupported) {
      return const LocalPlayResult(LocalPlayStatus.noEmulator);
    }
    String? configPath;
    if (emulator.id == 'retroarch') {
      configPath = await _writeRetroArchConfig(store);
    }
    final core = spec.cores[catalog.canonicalSlug(game.platformSlug)];
    final res = await launcher.launch(
      emulator: emulator,
      spec: spec,
      romPath: playable,
      prefs: prefs,
      coreName: core,
      configFilePath: configPath,
    );
    if (!res.ok) {
      return LocalPlayResult(
        LocalPlayStatus.error,
        path: playable,
        message: res.error,
      );
    }
    return LocalPlayResult(LocalPlayStatus.launched, path: playable);
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  EmulatorOsSpec? _specForOs(Emulator emulator) {
    if (kIsWeb) return null;
    if (Platform.isAndroid) return emulator.android ?? emulator.windows;
    if (Platform.isWindows) return emulator.windows;
    return null;
  }

  Map<String, String> _authHeaders(RommRepository repo) => {
        if (repo.token?.trim().isNotEmpty == true)
          'Authorization': 'Bearer ${repo.token!.trim()}',
      };

  Future<void> _ensureBios(
    RommRepository repo,
    LocalGameStore store,
    EmulatorPreferences prefs,
    String emulatorId,
    int platformId,
  ) async {
    try {
      final biosDir = await prefs.biosDir(emulatorId) ?? await store.biosDir();
      await store.ensureDir(biosDir);
      final firmwares = await repo.getFirmware(platformId: platformId);
      for (final fw in firmwares) {
        if (fw.missingFromFs) continue;
        final path = '$biosDir${Platform.pathSeparator}${fw.fileName}';
        if (await store.fileExists(path)) continue;
        try {
          await repo.downloadUrlTo(
            repo.firmwareDownloadUrl(fw.id, fw.fileName),
            path,
          );
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<String> _writeRetroArchConfig(LocalGameStore store) async {
    final states = await store.statesDir();
    final bios = await store.biosDir();
    final saves = await store.savesDir();
    await store.ensureDir(states);
    await store.ensureDir(bios);
    await store.ensureDir(saves);
    final path = '$states${Platform.pathSeparator}retroarch_override.cfg';
    final content = 'system_directory = "$bios"\n'
        'savefile_directory = "$saves"\n'
        'savestate_directory = "$states"\n'
        'savefile_in_content = "false"\n';
    await File(path).writeAsString(content);
    return path;
  }
}

/// Ejecuta un futuro sin esperar y silencia errores (fire-and-forget).
void unawaitedOrNull(Future<void> future) {
  future.catchError((_) {});
}

final localPlayControllerProvider = Provider<LocalPlayController>(
  (ref) => LocalPlayController(ref),
);

/// ConfiguraciÃ³n del servidor ROMM persistida en el dispositivo.
final rommConfigProvider = FutureProvider<RommConfig?>((ref) async {
  return ref.watch(rommStorageProvider).loadConfig();
});

/// Estado de autenticaciÃ³n contra ROMM.
class RommAuthState {
  const RommAuthState({this.authenticated = false, this.loading = false});

  final bool authenticated;
  final bool loading;
}

/// Controla el login/logout contra el servidor ROMM y expone el repositorio
/// autenticado.
class RommAuthController extends Notifier<RommAuthState> {
  RommRepository? _repository;
  bool _initialized = false;

  // Estado del emparejamiento por QR en curso.
  RommRepository? _pairRepo;
  String? _pairServerUrl;
  bool _pairCancelled = false;

  RommRepository? get repository => _repository;

  @override
  RommAuthState build() {
    ref.onDispose(() {
      _repository = null;
      _initialized = false;
    });
    init();
    return const RommAuthState(loading: true);
  }

  /// Restaura el token guardado (obtenido por emparejamiento QR) y prepara
  /// el repositorio autenticado.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final config = await ref.read(rommConfigProvider.future);
    if (config == null || !config.isPaired) {
      state = const RommAuthState();
      return;
    }
    _repository = RommRepository(serverUrl: config.serverUrl);
    _repository!.setToken(config.token);
    state = const RommAuthState(authenticated: true);
  }

  /// Arranca el emparejamiento por QR contra RomM (device authorization flow).
  /// Devuelve los datos para pintar el QR y el código. No autentica todavía.
  Future<RommDeviceAuthStart> beginQrPairing({
    required String serverUrl,
    required String deviceName,
  }) async {
    final repo = RommRepository(serverUrl: serverUrl);
    final deviceId = await ref
        .read(sessionStorageProvider)
        .getOrCreateDeviceId();
    final version = await _clientVersion();
    final start = await repo.deviceAuthInit(
      clientDeviceIdentifier: deviceId,
      name: deviceName,
      client: 'fynitiv',
      platform: _platformSlug(),
      clientVersion: version,
      requestedScopes: kRommRequestedScopes,
    );
    _pairRepo = repo;
    _pairServerUrl = serverUrl;
    _pairCancelled = false;
    return start;
  }

  /// Hace polling hasta que el usuario aprueba, deniega, caduca o se cancela.
  Future<RommPairOutcome> pollQrPairing(RommDeviceAuthStart start) async {
    final repo = _pairRepo;
    final serverUrl = _pairServerUrl;
    if (repo == null || serverUrl == null) return RommPairOutcome.cancelled;

    var interval = start.interval > 0 ? start.interval : 5;
    final deadline = DateTime.now().add(Duration(seconds: start.expiresIn));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(seconds: interval));
      if (_pairCancelled) return RommPairOutcome.cancelled;
      RommDeviceAuthPollResult result;
      try {
        result = await repo.deviceAuthPoll(start.deviceCode);
      } catch (_) {
        continue;
      }
      if (result.approved) {
        await _commitPairedToken(
          repo: repo,
          serverUrl: serverUrl,
          token: result.accessToken!,
          deviceId: result.deviceId,
        );
        return RommPairOutcome.approved;
      }
      switch (result.status) {
        case RommDeviceAuthStatus.pending:
        case null:
          break;
        case RommDeviceAuthStatus.slowDown:
          interval += 5;
        case RommDeviceAuthStatus.denied:
          return RommPairOutcome.denied;
        case RommDeviceAuthStatus.expired:
          return RommPairOutcome.expired;
      }
    }
    return _pairCancelled ? RommPairOutcome.cancelled : RommPairOutcome.expired;
  }

  /// Cancela un emparejamiento en curso (cierre del diálogo).
  void cancelQrPairing() {
    _pairCancelled = true;
  }

  Future<void> _commitPairedToken({
    required RommRepository repo,
    required String serverUrl,
    required String token,
    String? deviceId,
  }) async {
    repo.setToken(token);
    final storage = ref.read(rommStorageProvider);
    await storage.saveConfig(RommConfig(serverUrl: serverUrl, token: token));
    await storage.writeToken(token);
    if (deviceId != null && deviceId.isNotEmpty) {
      await storage.writeDeviceId(deviceId);
    }
    _repository = repo;
    state = const RommAuthState(authenticated: true);
    ref.invalidate(rommConfigProvider);
  }

  Future<String?> _clientVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return null;
    }
  }

  static String _platformSlug() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<void> logout() async {
    _pairCancelled = true;
    _pairRepo = null;
    _pairServerUrl = null;
    await ref.read(rommStorageProvider).clear();
    _repository = null;
    _initialized = false;
    state = const RommAuthState();
    ref.invalidate(rommConfigProvider);
  }

  /// Llamado cuando la API devuelve 401: el token expirÃ³ o es invÃ¡lido.
  /// Borra solo el token, mantiene serverUrl/username para que el usuario
  /// solo tenga que reintroducir la contraseÃ±a en Ajustes.
  Future<void> handleUnauthorized() async {
    await ref.read(rommStorageProvider).deleteToken();
    _repository?.setToken(null);
    state = const RommAuthState();
  }
}

final rommAuthProvider = NotifierProvider<RommAuthController, RommAuthState>(
  RommAuthController.new,
);

/// Repositorio ROMM autenticado (null si no hay sesiÃ³n).
final rommRepositoryProvider = Provider<RommRepository?>((ref) {
  final auth = ref.watch(rommAuthProvider);
  final repo = ref.read(rommAuthProvider.notifier).repository;
  if (!auth.authenticated || repo == null) return null;
  return repo;
});

String _rommFriendlyMessage(DioException e) {
  final code = e.response?.statusCode;
  if (code == 401) {
    return 'SesiÃ³n ROMM expirada (401). Vuelve a iniciar sesiÃ³n en Ajustes > Juego online.';
  }
  if (code == 403) {
    return 'Acceso denegado (403 Forbidden). Tu usuario ROMM no tiene permiso para este recurso. Verifica permisos o inicia sesiÃ³n de nuevo.';
  }
  if (code == 500) {
    final data = e.response?.data;
    final detail = data is String && data.isNotEmpty ? data : data is Map ? (data['detail'] ?? data['message'] ?? data.toString()) : '';
    return 'Error interno del servidor RomM (500). Revisa `docker logs romm` en el servidor https://romm.lopivhouse.page. Detalle: ${detail.toString().isNotEmpty ? detail : "Internal Server Error"}.\nPosible causa: token sin scopes (actual scopes="") o RomM desactualizado. Prueba cerrar sesiÃ³n y volver a iniciar sesiÃ³n en Ajustes > Juego online.';
  }
  final data = e.response?.data;
  if (data is String && data.isNotEmpty) return data;
  if (data is Map && data.isNotEmpty) {
    final msg = data['detail'] ?? data['error'] ?? data['message'];
    if (msg is String && msg.isNotEmpty) return msg;
    return data.toString();
  }
  return e.message ?? 'Error de conexiÃ³n con ROMM';
}

Future<T> _withRommRecovery<T>(Ref ref, Future<T> Function() fn) async {
  try {
    return await fn();
  } on DioException catch (e) {
    if (e.response?.statusCode == 401) {
      // Token expirado: invalida la sesiÃ³n para que la UI muestre "reconfigurar"
      await ref.read(rommAuthProvider.notifier).handleUnauthorized();
    }
    throw Exception(_rommFriendlyMessage(e));
  }
}

/// Plataformas de la biblioteca ROMM.
final rommPlatformsProvider = FutureProvider<List<RommPlatform>>((ref) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) return const [];
  return _withRommRecovery(ref, () => repo.getPlatforms());
}, retry: (retryCount, error) {
  // No reintentar automÃ¡ticamente en 500 (error del servidor) para evitar bucle
  if (error.toString().contains('500') || error.toString().contains('Internal Server Error')) return null;
  if (retryCount >= 2) return null;
  return const Duration(seconds: 2);
});

/// Juegos de una plataforma concreta.
/// Si [platformId] es null no se cargan juegos (evita 403/overhead en bibliotecas grandes).
/// Usa siempre un filtro por plataforma.
final rommGamesProvider = FutureProvider.family<RommGamesPage, int?>((
  ref,
  platformId,
) async {
  if (platformId == null) return const RommGamesPage(items: [], total: 0);
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) return const RommGamesPage(items: [], total: 0);
  return _withRommRecovery(
    ref,
    () => repo.getGames(platformIds: [platformId]),
  );
}, retry: (retryCount, error) {
  if (error.toString().contains('500')) return null;
  if (retryCount >= 2) return null;
  return const Duration(seconds: 2);
});

/// Detalle de un juego.
final rommGameProvider = FutureProvider.family<RommGame, int>((ref, id) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) throw StateError('No hay sesiÃ³n ROMM');
  return _withRommRecovery(ref, () => repo.getGame(id));
});

/// Slugs con streaming en navegador (una sola petición compartida por
/// todas las tarjetas de plataforma).
final rommStreamingSlugsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) return const {};
  return _withRommRecovery(ref, () => repo.streamingPlatformSlugs());
});

/// Indica si una plataforma tiene streaming disponible.
final rommStreamingProvider = FutureProvider.family<bool, String>((
  ref,
  platformSlug,
) async {
  final slugs = await ref.watch(rommStreamingSlugsProvider.future);
  return slugs.contains(platformSlug.toLowerCase());
});

/// “Continuar jugando” – últimos ROMs con last_played, ordenados por fecha descendente.
/// Usa GET /api/roms?last_played=true&order_by=last_played&order_dir=desc
final rommContinuePlayingProvider = FutureProvider<List<RommGame>>((ref) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) return const [];
  return _withRommRecovery(ref, () async {
    final page = await repo.getGames(lastPlayed: true, orderBy: 'last_played', orderDir: 'desc', limit: 20);
    // Filtra por seguridad los que realmente tienen lastPlayed y ordena desc
    final filtered = page.items.where((g) => g.lastPlayed != null).toList();
    filtered.sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    return filtered;
  });
}, retry: (retryCount, error) {
  if (error.toString().contains('500')) return null;
  if (retryCount >= 1) return null;
  return const Duration(seconds: 2);
});
