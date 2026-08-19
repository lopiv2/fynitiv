import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/romm_repository.dart';
import '../data/romm_storage.dart';
import '../domain/romm_config.dart';
import '../domain/romm_game.dart';
import '../domain/romm_platform.dart';

final rommStorageProvider = Provider<RommStorage>(
  (ref) => RommStorage(secure: ref.watch(flutterSecureStorageProvider)),
);

/// Configuración del servidor ROMM persistida en el dispositivo.
final rommConfigProvider = FutureProvider<RommConfig?>((ref) async {
  return ref.watch(rommStorageProvider).loadConfig();
});

/// Estado de autenticación contra ROMM.
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

  /// Restaura el token guardado y prepara el repositorio.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final config = await ref.read(rommConfigProvider.future);
    if (config == null) {
      state = const RommAuthState();
      return;
    }
    final token = await ref.read(rommStorageProvider).readToken();
    _repository = RommRepository(serverUrl: config.serverUrl);
    _repository!.setToken(token);
    if (token != null && token.isNotEmpty) {
      state = const RommAuthState(authenticated: true);
    } else {
      state = const RommAuthState();
    }
  }

  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    state = const RommAuthState(loading: true);
    try {
      final repo = RommRepository(serverUrl: serverUrl);
      await repo.login(username: username, password: password);
      final storage = ref.read(rommStorageProvider);
      await storage.saveConfig(
        RommConfig(serverUrl: serverUrl, username: username),
      );
      final token = repo.token;
      if (token == null || token.isEmpty) {
        state = const RommAuthState();
        return false;
      }
      await storage.writeToken(token);
      _repository = repo;
      state = const RommAuthState(authenticated: true);
      ref.invalidate(rommConfigProvider);
      return true;
    } catch (_) {
      state = const RommAuthState();
      rethrow;
    }
  }

  Future<void> logout() async {
    await ref.read(rommStorageProvider).clear();
    _repository = null;
    _initialized = false;
    state = const RommAuthState();
    ref.invalidate(rommConfigProvider);
  }
}

final rommAuthProvider =
    NotifierProvider<RommAuthController, RommAuthState>(RommAuthController.new);

/// Repositorio ROMM autenticado (null si no hay sesión).
final rommRepositoryProvider = Provider<RommRepository?>((ref) {
  final auth = ref.watch(rommAuthProvider);
  final repo = ref.read(rommAuthProvider.notifier).repository;
  if (!auth.authenticated || repo == null) return null;
  return repo;
});

/// Plataformas de la biblioteca ROMM.
final rommPlatformsProvider = FutureProvider<List<RommPlatform>>((ref) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) return const [];
  return repo.getPlatforms();
});

/// Juegos de una plataforma concreta (o toda la biblioteca si id es null).
final rommGamesProvider =
    FutureProvider.family<RommGamesPage, int?>((ref, platformId) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) return const RommGamesPage(items: [], total: 0);
  return repo.getGames(
    platformIds: platformId == null ? null : [platformId],
  );
});

/// Detalle de un juego.
final rommGameProvider = FutureProvider.family<RommGame, int>((ref, id) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) throw StateError('No hay sesión ROMM');
  return repo.getGame(id);
});

/// Indica si una plataforma tiene streaming disponible.
final rommStreamingProvider =
    FutureProvider.family<bool, String>((ref, platformSlug) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) return false;
  return repo.hasStreamingFor(platformSlug);
});