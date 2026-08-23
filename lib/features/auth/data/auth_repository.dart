import 'package:dio/dio.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/concurrency_limit_interceptor.dart';
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
    final normalized = _normalizeUrl(serverUrl);
    final dio = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    // Limita la concurrencia para no saturar el servidor Jellyfin.
    dio.interceptors.add(ConcurrencyLimitInterceptor(maxConcurrent: 3));
    final client = JellyfinDart(
      dio: dio,
      basePathOverride: normalized,
    );
    client.setMediaBrowserAuth(
      deviceId: deviceId,
      version: AppConstants.appVersion,
      client: AppConstants.clientName,
      device: AppConstants.deviceName,
      token: token,
    );
    return client;
  }

  String _normalizeUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) {
      throw const FormatException('URL del servidor vacía');
    }
    // Casos borde como "https://" que el loop anterior convertía en "http://https:"
    if (u == 'http://' ||
        u == 'https://' ||
        u == 'http:/' ||
        u == 'https:/' ||
        u == 'https:' ||
        u == 'http:') {
      throw const FormatException('URL del servidor no válida');
    }
    if (!u.contains('://')) {
      u = 'http://$u';
    }
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      throw const FormatException('La URL debe empezar por http:// o https://');
    }
    final uri = Uri.tryParse(u);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException('URL del servidor no válida');
    }
    if (uri.host == 'https' || uri.host == 'http') {
      throw const FormatException('URL del servidor no válida: falta el host');
    }
    // Reconstruir sin barra final, pero conservando sub-path si existe (p.ej. /jellyfin)
    var normalized = uri.toString();
    final hostBase = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    while (normalized.endsWith('/') && normalized.length > hostBase.length) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    // Si queda exactamente "https://host/" lo dejamos sin barra.
    if (normalized.endsWith('/') && normalized == '$hostBase/') {
      normalized = hostBase;
    }
    return normalized;
  }

  /// Autentica por nombre de usuario y contraseña.
  Future<AuthenticationResult> authenticate({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final client = await createClient(serverUrl);
    final api = client.getUserApi();
    // Jellyfin: para usuarios sin contraseña, algunos servidores prefieren
    // omitir el campo Pw en lugar de enviar cadena vacía.
    final pw = password.isEmpty ? null : password;
    final response = await api.authenticateUserByName(
      authenticateUserByName: AuthenticateUserByName(
        username: username,
        pw: pw,
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
