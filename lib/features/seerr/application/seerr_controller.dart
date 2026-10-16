import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/seerr_api.dart';

const _kSeerrUrl = 'app.seerr_url';
const _kSeerrIsApiKey = 'app.seerr_api_key_mode';
const _kSeerrCredential = 'app.seerr_credential';

/// Conexión configurada con Seerr.
class SeerrConnection {
  const SeerrConnection({
    required this.baseUrl,
    required this.credential,
    required this.isApiKey,
  });

  final String baseUrl;

  /// Cookie de sesión (`connect.sid=...`) o API key según [isApiKey].
  final String credential;
  final bool isApiKey;
}

/// Persistencia de la conexión: URL en `SharedPreferences`, credencial en
/// almacén seguro.
class SeerrConnectionNotifier extends AsyncNotifier<SeerrConnection?> {
  static const _secure = FlutterSecureStorage();

  @override
  Future<SeerrConnection?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_kSeerrUrl);
    if (url == null || url.trim().isEmpty) return null;
    final credential = await _secure.read(key: _kSeerrCredential) ?? '';
    return SeerrConnection(
      baseUrl: url.trim(),
      credential: credential,
      isApiKey: prefs.getBool(_kSeerrIsApiKey) ?? false,
    );
  }

  Future<void> save({
    required String baseUrl,
    required String credential,
    required bool isApiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final url = baseUrl.trim();
    await prefs.setString(_kSeerrUrl, url);
    await prefs.setBool(_kSeerrIsApiKey, isApiKey);
    await _secure.write(key: _kSeerrCredential, value: credential);
    state = AsyncData(
      SeerrConnection(baseUrl: url, credential: credential, isApiKey: isApiKey),
    );
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSeerrUrl);
    await prefs.remove(_kSeerrIsApiKey);
    await _secure.delete(key: _kSeerrCredential);
    state = const AsyncData(null);
  }
}

final seerrConnectionProvider =
    AsyncNotifierProvider<SeerrConnectionNotifier, SeerrConnection?>(
      SeerrConnectionNotifier.new,
    );

/// Cliente Seerr listo para usar (`null` si no hay conexión configurada).
final seerrApiProvider = Provider<SeerrApi?>((ref) {
  final conn = ref.watch(seerrConnectionProvider).value;
  if (conn == null || conn.baseUrl.isEmpty || conn.credential.isEmpty) {
    return null;
  }
  return SeerrApi(
    baseUrl: conn.baseUrl,
    credential: conn.isApiKey ? null : conn.credential,
    apiKey: conn.isApiKey ? conn.credential : null,
  );
});

/// `true` si hay conexión con Seerr configurada.
final seerrConnectedProvider = Provider<bool>(
  (ref) => ref.watch(seerrApiProvider) != null,
);
