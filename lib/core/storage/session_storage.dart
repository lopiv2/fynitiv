import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/household/domain/household.dart';

/// Credencial de acceso persistida de un usuario.
class CachedUserToken {
  const CachedUserToken({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;

  bool get isValid => expiresAt.isAfter(DateTime.now());

  factory CachedUserToken.fromJson(Map<String, dynamic> json) {
    return CachedUserToken(
      token: json['token'] as String? ?? '',
      expiresAt:
          DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'expiresAt': expiresAt.toIso8601String(),
      };
}

/// Persistencia de la sesión Jellyfin.
///
/// Los datos sensibles (token de acceso, id de usuario, deviceId) se guardan
/// con [FlutterSecureStorage]; la URL del servidor se guarda en
/// [SharedPreferences].
class SessionStorage {
  SessionStorage({required this.secure});

  final FlutterSecureStorage secure;

  static const _kServerUrl = 'jellyfin.server_url';
  static const _kServerId = 'jellyfin.server_id';
  static const _kToken = 'jellyfin.access_token';
  static const _kUserId = 'jellyfin.user_id';
  static const _kDeviceId = 'jellyfin.device_id';
  static const _kHousehold = 'jellyfin.household';
  static const _kUserTokenPrefix = 'jellyfin.user_token.';

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

  Future<void> writeServerId(String id) async {
    final prefs = await _prefs;
    await prefs.setString(_kServerId, id);
  }

  Future<String?> readServerId() async {
    final prefs = await _prefs;
    return prefs.getString(_kServerId);
  }

  Future<void> writeToken(String token) =>
      secure.write(key: _kToken, value: token);

  Future<String?> readToken() => secure.read(key: _kToken);

  Future<void> writeUserId(String id) =>
      secure.write(key: _kUserId, value: id);

  Future<String?> readUserId() => secure.read(key: _kUserId);

  /// --- Casa (household) ---

  /// Guarda la casa. Si [household.serverId] es null pero hay un serverId
  /// registrado, se asocia automáticamente. Devuelve el household persistido
  /// (con el serverId resuelto), para que los estados lo reflejen.
  Future<Household> saveHousehold(Household household) async {
    final prefs = await _prefs;
    final serverId = household.serverId ?? prefs.getString(_kServerId);
    final toSave = serverId != null
        ? household.copyWith(serverId: serverId)
        : household;
    await prefs.setString(
      _kHousehold,
      jsonEncode(toSave.toJson()),
    );
    return toSave;
  }

  Future<Household?> loadHousehold() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_kHousehold);
    if (raw == null) return null;
    try {
      return Household.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Borra la casa guardada en el dispositivo.
  Future<void> clearHousehold() async {
    final prefs = await _prefs;
    await prefs.remove(_kHousehold);
  }

  /// --- Tokens persistentes por usuario ---

  Future<void> saveUserToken(
    String userId,
    CachedUserToken cached,
  ) async {
    await secure.write(
      key: '$_kUserTokenPrefix$userId',
      value: jsonEncode(cached.toJson()),
    );
  }

  Future<CachedUserToken?> loadUserToken(String userId) async {
    final raw = await secure.read(key: '$_kUserTokenPrefix$userId');
    if (raw == null) return null;
    try {
      return CachedUserToken.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteUserToken(String userId) async {
    await secure.delete(key: '$_kUserTokenPrefix$userId');
  }

  /// Borra todos los datos de configuración (servidor, casa, tokens).
  Future<void> clear() async {
    final prefs = await _prefs;
    await Future.wait([
      // Borra el token de sesión, el de usuario y todos los tokens por usuario
      // (claves jellyfin.user_token.*) del almacén seguro.
      secure.deleteAll(),
      prefs.remove(_kServerUrl),
      prefs.remove(_kServerId),
      prefs.remove(_kHousehold),
    ]);
  }

  /// Borra solo la sesión (token + usuario), conservando la URL del servidor
  /// para poder mostrar de nuevo la selección de usuarios.
  Future<void> clearSession() async {
    await Future.wait([
      secure.delete(key: _kToken),
      secure.delete(key: _kUserId),
    ]);
  }
}
