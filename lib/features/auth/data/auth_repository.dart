import 'package:dio/dio.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/storage/session_storage.dart';

class AuthRepository {
  AuthRepository({required this.storage});

  final SessionStorage storage;

  /// Crea un cliente [JellyfinDart] configurado con MediaBrowser auth.
  Future<JellyfinDart> createClient(
    String serverUrl, {
    String? token,
  }) async {
    final deviceId = await storage.getOrCreateDeviceId();
    final client = JellyfinDart(basePathOverride: serverUrl);
    client.setMediaBrowserAuth(
      deviceId: deviceId,
      version: AppConstants.appVersion,
      client: AppConstants.clientName,
      device: AppConstants.deviceName,
      token: token,
    );
    return client;
  }

  /// Autentica por nombre de usuario y contraseña.
  Future<AuthenticationResult> authenticate({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final client = await createClient(serverUrl);
    final api = client.getUserApi();
    final response = await api.authenticateUserByName(
      authenticateUserByName: AuthenticateUserByName(
        username: username,
        pw: password,
      ),
    );
    final result = response.data;
    if (result == null || result.accessToken == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        error: 'El servidor no devolvió un token de acceso.',
      );
    }
    return result;
  }
}
