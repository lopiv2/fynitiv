/// Configuración del servidor ROMM guardada en el dispositivo.
class RommConfig {
  const RommConfig({required this.serverUrl, this.token});

  final String serverUrl;

  /// Client API Token obtenido por emparejamiento QR (device authorization).
  /// Se guarda en almacenamiento seguro, no aquí en claro.
  final String? token;

  bool get isPaired => token != null && token!.isNotEmpty;

  String get displayName {
    final uri = Uri.tryParse(serverUrl);
    return uri?.host ?? serverUrl;
  }

  RommConfig copyWith({String? serverUrl, String? token}) {
    return RommConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      token: token ?? this.token,
    );
  }
}
