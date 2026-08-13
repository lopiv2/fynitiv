import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persistencia de la sesión Jellyfin.
///
/// Los datos sensibles (token de acceso, id de usuario, deviceId) se guardan
/// con [FlutterSecureStorage]; la URL del servidor se guarda en
/// [SharedPreferences].
class SessionStorage {
  SessionStorage({required this.secure});

  final FlutterSecureStorage secure;

  static const _kServerUrl = 'jellyfin.server_url';
  static const _kToken = 'jellyfin.access_token';
  static const _kUserId = 'jellyfin.user_id';
  static const _kDeviceId = 'jellyfin.device_id';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Devuelve el deviceId persistido o genera uno nuevo (UUID v4) la primera vez.
  Future<String> getOrCreateDeviceId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final deviceId = const Uuid().v4();
    await prefs.setString(_kDeviceId, deviceId);
    return deviceId;
  }

  Future<void> writeServerUrl(String url) async {
    final prefs = await _prefs;
    await prefs.setString(_kServerUrl, url);
  }

  Future<String?> readServerUrl() async {
    final prefs = await _prefs;
    return prefs.getString(_kServerUrl);
  }

  Future<void> writeToken(String token) =>
      secure.write(key: _kToken, value: token);

  Future<String?> readToken() => secure.read(key: _kToken);

  Future<void> writeUserId(String id) =>
      secure.write(key: _kUserId, value: id);

  Future<String?> readUserId() => secure.read(key: _kUserId);

  Future<void> clear() async {
    final prefs = await _prefs;
    await Future.wait([
      secure.delete(key: _kToken),
      secure.delete(key: _kUserId),
      prefs.remove(_kServerUrl),
    ]);
  }
}
