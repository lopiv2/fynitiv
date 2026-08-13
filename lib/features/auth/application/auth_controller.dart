import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../../core/di/providers.dart';
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

  Future<AuthState>? _sessionFuture;

  @override
  AuthState build() {
    _sessionFuture = _loadSession();
    return const AuthState(status: AuthStatus.unknown);
  }

  /// Resuelve la sesión precargada y entra en la app.
  /// La splash queda en espera hasta que el usuario pulsa "play".
  Future<void> enterApp() async {
    final session = await _sessionFuture;
    state = session ?? const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<AuthState> _loadSession() async {
    final storage = ref.read(sessionStorageProvider);
    final serverUrl = await storage.readServerUrl();
    final token = await storage.readToken();
    final userId = await storage.readUserId();
    if (serverUrl == null || token == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    try {
      final client =
          await ref.read(authRepositoryProvider).createClient(serverUrl, token: token);
      _client = client;
      return AuthState(
        status: AuthStatus.authenticated,
        serverUrl: serverUrl,
        userId: userId,
      );
    } catch (_) {
      return const AuthState(status: AuthStatus.unauthenticated);
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
    return e.message ?? 'Error de conexión con el servidor.';
  }
}
