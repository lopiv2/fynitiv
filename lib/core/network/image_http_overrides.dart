import 'dart:io';

/// Configura timeouts para el [HttpClient] de Flutter usado por `Image.network`
/// y otras descargas del framework. Sin esto, las imágenes de red se quedan
/// colgadas indefinidamente (semáforo agotado) cuando el servidor no responde.
///
/// También controla si se aceptan certificados TLS no válidos (autofirmados o
/// emitidos por una CA no confiable), habituales en servidores caseros
/// (Jellyfin, Seerr, ROMm…). Lo gestiona la preferencia "Aceptar certificados
/// no válidos".
class FynitivHttpOverrides extends HttpOverrides {
  static const Duration _connectionTimeout = Duration(seconds: 8);
  static const Duration _idleTimeout = Duration(seconds: 15);

  /// Si es `true`, se aceptan certificados TLS no válidos.
  static bool allowBadCertificates = true;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionTimeout = _connectionTimeout;
    client.idleTimeout = _idleTimeout;
    client.badCertificateCallback =
        (cert, host, port) => allowBadCertificates;
    return client;
  }
}
