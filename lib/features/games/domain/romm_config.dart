/// Configuración del servidor ROMM guardada en el dispositivo.
class RommConfig {
  const RommConfig({
    required this.serverUrl,
    required this.username,
    this.password,
  });

  final String serverUrl;
  final String username;

  /// Contraseña en memoria (nunca se persiste en claro; solo se usa para
  /// obtener el token). Se mantiene mientras dura la sesión del provider.
  final String? password;

  String get displayName {
    final uri = Uri.tryParse(serverUrl);
    return uri?.host ?? serverUrl;
  }

  RommConfig copyWith({String? serverUrl, String? username, String? password}) {
    return RommConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}