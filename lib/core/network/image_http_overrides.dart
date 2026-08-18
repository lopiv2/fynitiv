import 'dart:io';

/// Configura timeouts para el [HttpClient] de Flutter usado por `Image.network`
/// y otras descargas del framework. Sin esto, las imágenes de red se quedan
/// colgadas indefinidamente (semáforo agotado) cuando el servidor no responde.
class FynitivHttpOverrides extends HttpOverrides {
  static const Duration _connectionTimeout = Duration(seconds: 8);
  static const Duration _idleTimeout = Duration(seconds: 15);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionTimeout = _connectionTimeout;
    client.idleTimeout = _idleTimeout;
    return client;
  }
}
