import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/romm_config.dart';

/// Persistencia de la configuración del servidor ROMM.
///
/// La URL y el id de dispositivo se guardan en [SharedPreferences]; el token
/// de acceso (Client API Token) se guarda en [FlutterSecureStorage].
class RommStorage {
  RommStorage({required this.secure});

  final FlutterSecureStorage secure;

  static const _kServerUrl = 'romm.server_url';
  static const _kToken = 'romm.access_token';
  static const _kDeviceId = 'romm.device_id';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveConfig(RommConfig config) async {
    final prefs = await _prefs;
    await prefs.setString(_kServerUrl, config.serverUrl);
  }

  Future<RommConfig?> loadConfig() async {
    final prefs = await _prefs;
    final serverUrl = prefs.getString(_kServerUrl);
    if (serverUrl == null || serverUrl.isEmpty) return null;
    final token = await secure.read(key: _kToken);
    return RommConfig(serverUrl: serverUrl, token: token);
  }

  Future<void> writeToken(String token) =>
      secure.write(key: _kToken, value: token);

  Future<String?> readToken() => secure.read(key: _kToken);

  Future<void> deleteToken() => secure.delete(key: _kToken);

  /// Id del dispositivo registrado en RomM (para el Device Sync Protocol).
  Future<String?> readDeviceId() async {
    final prefs = await _prefs;
    return prefs.getString(_kDeviceId);
  }

  Future<void> writeDeviceId(String id) async {
    final prefs = await _prefs;
    await prefs.setString(_kDeviceId, id);
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await Future.wait([
      secure.delete(key: _kToken),
      prefs.remove(_kServerUrl),
      prefs.remove(_kDeviceId),
    ]);
  }
}
