/// Log de diagnóstico del reproductor de Live TV.
///
/// Añade contexto (canal, URL redactada, eventos del motor) para poder
/// investigar por qué un stream no arranca cuando sí funciona en otras apps.
library;

import 'dart:developer' as developer;

/// Activa el log verboso de mpv (nivel `v`) y el probe de la URL del stream.
/// Útil para diagnosticar fallos de reproducción; mantener en `false` en uso
/// normal porque genera muchísimo ruido y golpea al servidor en cada canal.
const bool kLiveTvVerbose = false;

/// Redacta secretos de una URL para no volcar el token en los logs.
String redactUrl(String? url) {
  if (url == null) return '<null>';
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final query = uri.queryParameters;
  for (final key in ['api_key', 'ApiKey', 'X-Emby-Token']) {
    if (query.containsKey(key)) query[key] = '***';
  }
  return uri.replace(queryParameters: query).toString();
}

/// Emite un log de Live TV con etiqueta fija para filtrar fácilmente.
void liveTvLog(String message, {Object? error, StackTrace? stack}) {
  developer.log(
    message,
    name: 'LiveTV',
    error: error,
    stackTrace: stack,
  );
}
