import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/security/pin_hasher.dart';
import '../../../core/storage/session_storage.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(storage: ref.watch(sessionStorageProvider)),
);

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Cliente Jellyfin activo de la sesión. Se refresca junto con el estado de auth.
final jellyfinClientProvider = Provider<JellyfinDart?>(
  (ref) => ref.watch(authControllerProvider.notifier).client,
);

class AuthController extends Notifier<AuthState> {
  JellyfinDart? _client;

  JellyfinDart? get client => _client;

  @override
  AuthState build() {
    _loadSession();
    return const AuthState(status: AuthStatus.unknown);
  }

  /// Resuelve la sesión actual y entra en la app.
  /// La splash queda en espera hasta que el usuario pulsa "play".
  ///
  /// Con servidor configurado, se muestra siempre la selección de usuarios
  /// (estilo Disney+), aunque exista una sesión guardada.
  Future<void> enterApp() async {
    final session = await _loadSession();
    if (session.serverUrl == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    state = AuthState(
      status: AuthStatus.unauthenticated,
      serverUrl: session.serverUrl,
      serverId: session.serverId,
    );
  }

  Future<AuthState> _loadSession() async {
    final storage = ref.read(sessionStorageProvider);
    final serverUrl = await storage.readServerUrl();
    var serverId = await storage.readServerId();
    if (serverUrl == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    try {
      // Cliente sin token: permite endpoints públicos (usuarios, imágenes).
      final client =
          await ref.read(authRepositoryProvider).createClient(serverUrl);
      _client = client;

      // Si el serverId no está guardado (p. ej. servidor configurado antes de
      // esta versión), lo consultamos para vincular la casa. Con un timeout
      // corto para no bloquear el arranque.
      if (serverId == null) {
        try {
          final info = await client
              .getSystemApi()
              .getPublicSystemInfo()
              .timeout(const Duration(seconds: 4));
          final id = info.data?.id;
          if (id != null && id.isNotEmpty) {
            serverId = id;
            await storage.writeServerId(id);
          }
        } catch (_) {
          // No crítico: la casa quedará sin vincular y se reconfigurará.
        }
      }

      final token = await storage.readToken();
      if (token == null) {
        return AuthState(
          status: AuthStatus.unauthenticated,
          serverUrl: serverUrl,
          serverId: serverId,
        );
      }
      final userId = await storage.readUserId();
      client.setToken(token);

      // Obtenemos los datos del usuario actual (nombre, foto).
      UserDto? user;
      try {
        final userRes = await client
            .getUserApi()
            .getCurrentUser()
            .timeout(const Duration(seconds: 4));
        user = userRes.data;
      } catch (_) {
        // No crítico: usamos userId como fallback.
      }

      return AuthState(
        status: AuthStatus.authenticated,
        serverUrl: serverUrl,
        serverId: serverId,
        userId: userId,
        user: user,
      );
    } catch (_) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Devuelve los usuarios públicos del servidor configurado.
  Future<List<UserDto>> fetchPublicUsers() async {
    final client = await _ensureClient();
    final response = await client
        .getUserApi()
        .getPublicUsers()
        .timeout(const Duration(seconds: 10));
    return response.data ?? [];
  }

  /// Asegura que existe un cliente sin token basado en la URL guardada.
  Future<JellyfinDart> _ensureClient() async {
    final existing = _client;
    if (existing != null) return existing;

    final storage = ref.read(sessionStorageProvider);
    final serverUrl = await storage.readServerUrl();
    if (serverUrl == null) {
      throw StateError('No hay servidor configurado.');
    }
    final client =
        await ref.read(authRepositoryProvider).createClient(serverUrl);
    _client = client;
    return client;
  }

  /// Guarda (o actualiza) la URL del servidor, consulta su serverId y recrea
  /// el cliente.
  Future<void> saveServerUrl(String serverUrl) async {
    final normalized = _normalizeUrl(serverUrl);
    final storage = ref.read(sessionStorageProvider);
    await storage.writeServerUrl(normalized);
    _client = await ref.read(authRepositoryProvider).createClient(normalized);

    String? serverId;
    try {
      final info = await _client!.getSystemApi().getPublicSystemInfo();
      serverId = info.data?.id;
      if (serverId != null && serverId.isNotEmpty) {
        await storage.writeServerId(serverId);
      }
    } catch (_) {
      // Si no se puede obtener el serverId, la casa quedará huérfana y se
      // reconfigurará al conectar.
    }

    state = AuthState(
      status: AuthStatus.unauthenticated,
      serverUrl: normalized,
      serverId: serverId,
    );
  }

  /// Indica si el usuario tiene un token persistido todavía válido.
  Future<bool> hasValidToken(String userId) async {
    final storage = ref.read(sessionStorageProvider);
    final cached = await storage.loadUserToken(userId);
    return cached != null && cached.isValid;
  }

  /// Entra con el usuario seleccionado.
  ///
  /// Si existe un token persistido válido se entra directamente; si no (o el
  /// servidor lo rechaza), se autentica con contraseña y se renueva el token
  /// con una validez de [AppConstants.tokenValidityDays].
  ///
  /// Devuelve `true` si la autenticación tuvo éxito.
  Future<bool> loginAsUser(
    String username, {
    String? userId,
    String? password,
  }) async {
    final serverUrl = state.serverUrl;
    if (serverUrl == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    final storage = ref.read(sessionStorageProvider);

    // 1) Intento con token persistido si no se aportó contraseña.
    if (password == null && userId != null) {
      final cached = await storage.loadUserToken(userId);
      if (cached != null && cached.isValid) {
        try {
          final client = await ref
              .read(authRepositoryProvider)
              .createClient(serverUrl, token: cached.token);
          final userRes = await client.getUserApi().getCurrentUser();
          _client = client;
          state = AuthState(
            status: AuthStatus.authenticated,
            user: userRes.data,
            userId: userId,
            serverUrl: serverUrl,
          );
          return true;
        } on DioException {
          // Token revocado: caemos a autenticación con contraseña.
        }
      }
    }

    // 2) Autenticación con credenciales.
    try {
      final repository = ref.read(authRepositoryProvider);
      final result = await repository.authenticate(
        serverUrl: serverUrl,
        username: username,
        password: password ?? '',
      );
      final token = result.accessToken!;
      final resolvedUserId = userId ?? result.user?.id ?? '';

      _client = await repository.createClient(serverUrl, token: token);
      if (resolvedUserId.isNotEmpty) {
        await storage.saveUserToken(
          resolvedUserId,
          CachedUserToken(
            token: token,
            expiresAt: DateTime.now().add(
              const Duration(days: AppConstants.tokenValidityDays),
            ),
          ),
        );
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        userId: resolvedUserId,
        serverUrl: serverUrl,
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _dioErrorMessage(e));
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final normalized = _normalizeUrl(serverUrl);
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repository = ref.read(authRepositoryProvider);
      final result = await repository.authenticate(
        serverUrl: normalized,
        username: username,
        password: password,
      );
      final token = result.accessToken!;

      final storage = ref.read(sessionStorageProvider);
      await storage.writeServerUrl(normalized);
      await storage.writeToken(token);
      final userId = result.user?.id ?? '';
      if (userId.isNotEmpty) await storage.writeUserId(userId);

      _client = await repository.createClient(normalized, token: token);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: result.user,
        userId: userId,
        serverUrl: normalized,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _dioErrorMessage(e));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    await ref.read(sessionStorageProvider).clearSession();
    _client?.setToken(null);
    _client = null;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Elimina el token persistido de un usuario (p. ej. al reconfigurar la casa).
  Future<void> clearUserToken(String userId) async {
    await ref.read(sessionStorageProvider).deleteUserToken(userId);
  }

  /// Verifica el PIN de la casa. Acepta tanto el PIN normal como el PIN
  /// maestro de recuperación.
  Future<bool> verifyHousePin(String pin) async {
    final storage = ref.read(sessionStorageProvider);
    final household = await storage.loadHousehold();
    if (household == null) return false;
    final deviceId = await storage.getOrCreateDeviceId();

    final pinHash = household.pinHash;
    if (pinHash != null && pinHash.isNotEmpty) {
      if (PinHasher.verify(pin, pinHash, salt: deviceId)) return true;
    }
    final masterHash = household.masterPinHash;
    if (masterHash != null && masterHash.isNotEmpty) {
      return PinHasher.verify(pin, masterHash, salt: deviceId);
    }
    // Sin PIN configurado: acceso libre.
    return true;
  }

  /// Comprueba si la casa configurada tiene PIN.
  Future<bool> houseHasPin() async {
    final storage = ref.read(sessionStorageProvider);
    final household = await storage.loadHousehold();
    return household?.pinHash != null && household!.pinHash!.isNotEmpty;
  }

  /// Genera el PIN maestro de recuperación de la casa.
  String generateMasterPin() {
    final random = Random.secure();
    return List.generate(8, (_) => random.nextInt(10)).join();
  }

  /// Borra todos los datos de configuración (servidor, casa, tokens) para
  /// poder probar de nuevo los wizards desde cero.
  Future<void> resetAppData() async {
    await ref.read(sessionStorageProvider).clear();
    _client?.setToken(null);
    _client = null;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _normalizeUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  String _dioErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) return data;
    if (data is Map && data.isNotEmpty) return data.toString();
    return '${e.response?.statusCode ?? ''} ${e.message ?? 'Error de conexión con el servidor.'}'
        .trim();
  }
}
