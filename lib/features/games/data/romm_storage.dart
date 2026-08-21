import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/romm_config.dart';

/// Persistencia de la configuración del servidor ROMM.
///
/// La URL y el usuario se guardan en [SharedPreferences]; el token de acceso
/// y el API key se guardan en [FlutterSecureStorage] (no se persiste la contraseña).
class RommStorage {
  RommStorage({required this.secure});

  final FlutterSecureStorage secure;

  static const _kServerUrl = 'romm.server_url';
  static const _kUsername = 'romm.username';
  static const _kUseApiKey = 'romm.use_api_key';
  static const _kToken = 'romm.access_token';
  static const _kApiKey = 'romm.api_key';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveConfig(RommConfig config) async {
    final prefs = await _prefs;
    await prefs.setString(_kServerUrl, config.serverUrl);
    await prefs.setString(_kUsername, config.username);
    await prefs.setBool(_kUseApiKey, config.useApiKey);
  }

  Future<RommConfig?> loadConfig() async {
    final prefs = await _prefs;
    final serverUrl = prefs.getString(_kServerUrl);
    final username = prefs.getString(_kUsername);
    final useApiKey = prefs.getBool(_kUseApiKey) ?? false;
    if (serverUrl == null || serverUrl.isEmpty) return null;
    final apiKey = await secure.read(key: _kApiKey);
    return RommConfig(
      serverUrl: serverUrl,
      username: username ?? '',
      apiKey: apiKey,
      useApiKey: useApiKey,
    );
  }

  Future<void> writeToken(String token) =>
      secure.write(key: _kToken, value: token);

  Future<String?> readToken() => secure.read(key: _kToken);

  Future<void> deleteToken() => secure.delete(key: _kToken);

  Future<void> writeApiKey(String apiKey) =>
      secure.write(key: _kApiKey, value: apiKey);

  Future<String?> readApiKey() => secure.read(key: _kApiKey);

  Future<void> deleteApiKey() => secure.delete(key: _kApiKey);

  Future<void> clear() async {
    final prefs = await _prefs;
    await Future.wait([
      secure.delete(key: _kToken),
      secure.delete(key: _kApiKey),
      prefs.remove(_kServerUrl),
      prefs.remove(_kUsername),
      prefs.remove(_kUseApiKey),
    ]);
  }
}
