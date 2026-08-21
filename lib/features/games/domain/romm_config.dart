/// Configuración del servidor ROMM guardada en el dispositivo.
class RommConfig {
  const RommConfig({
    required this.serverUrl,
    required this.username,
    this.password,
    this.apiKey,
    this.useApiKey = false,
  });

  final String serverUrl;
  final String username;

  /// Contraseña en memoria (nunca se persiste en claro; solo se usa para
  /// obtener el token). Se mantiene mientras dura la sesión del provider.
  final String? password;

  /// API Key / Bearer token estático para RomM (alternativa a usuario/contraseña).
  /// Si [useApiKey] es true, se usa directamente como Bearer sin llamar a /api/token.
  final String? apiKey;
  final bool useApiKey;

  bool get isApiKeyMode => useApiKey && apiKey != null && apiKey!.isNotEmpty;

  String get displayName {
    final uri = Uri.tryParse(serverUrl);
    return uri?.host ?? serverUrl;
  }

  RommConfig copyWith({
    String? serverUrl,
    String? username,
    String? password,
    String? apiKey,
    bool? useApiKey,
  }) {
    return RommConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      apiKey: apiKey ?? this.apiKey,
      useApiKey: useApiKey ?? this.useApiKey,
    );
  }
}
