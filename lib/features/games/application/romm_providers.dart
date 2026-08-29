import 'package:dio/dio.dart';
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

  /// Restaura la API key guardada y prepara el repositorio.
  /// El modo usuario/contraseÃ±a fue eliminado, solo API Key es soportado.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final config = await ref.read(rommConfigProvider.future);
    if (config == null) {
      state = const RommAuthState();
      return;
    }
    if (config.isApiKeyMode && config.apiKey != null && config.apiKey!.isNotEmpty) {
      _repository = RommRepository(serverUrl: config.serverUrl);
      _repository!.setToken(config.apiKey);
      state = const RommAuthState(authenticated: true);
      return;
    }
    // Config antigua por usuario/contraseÃ±a: forzar migraciÃ³n a API Key
    if (!config.isApiKeyMode) {
      await ref.read(rommStorageProvider).deleteToken();
      state = const RommAuthState();
      return;
    }
    state = const RommAuthState();
  }

  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
    String? apiKey,
    bool useApiKey = false,
  }) async {
    // Solo API Key permitido - usuario/contraseÃ±a eliminado
    if (!useApiKey) {
      throw Exception('ConexiÃ³n por usuario/contraseÃ±a deshabilitada. Usa API Key en RomM â†’ Perfil â†’ API Keys.');
    }
    state = const RommAuthState(loading: true);
    try {
      final storage = ref.read(rommStorageProvider);
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API Key vacÃ­a');
      }
      final repo = RommRepository(serverUrl: serverUrl);
      repo.setToken(apiKey);
      // ValidaciÃ³n rÃ¡pida: intenta listar plataformas
      try {
        await repo.getPlatforms();
      } catch (e)   {
        throw Exception('Error ROMM: ${e.toString()}');
      }
      await storage.saveConfig(RommConfig(serverUrl: serverUrl, username: username, apiKey: apiKey, useApiKey: true));
      await storage.writeApiKey(apiKey);
      await storage.deleteToken();
      _repository = repo;
      state = const RommAuthState(authenticated: true);
      ref.invalidate(rommConfigProvider);
      return true;
    } on DioException {
      state = const RommAuthState();
      rethrow;
    } catch (e) {
      state = const RommAuthState();
      rethrow;
    }
  }

  /// Login directo con API key (atajo para UI)
  Future<bool> loginWithApiKey({
    required String serverUrl,
    required String apiKey,
    String username = 'api',
  }) =>
      login(serverUrl: serverUrl, username: username, password: '', apiKey: apiKey, useApiKey: true);

  Future<void> logout() async {
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

/// Indica si una plataforma tiene streaming disponible.
final rommStreamingProvider = FutureProvider.family<bool, String>((
  ref,
  platformSlug,
) async {
  final repo = ref.watch(rommRepositoryProvider);
  if (repo == null) return false;
  return _withRommRecovery(ref, () => repo.hasStreamingFor(platformSlug));
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
