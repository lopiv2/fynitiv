import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

class RadioNowPlaying {
  const RadioNowPlaying({this.artist, this.title, this.raw});
  final String? artist;
  final String? title;
  final String? raw;

  bool get hasData => (artist != null && artist!.isNotEmpty) || (title != null && title!.isNotEmpty);

  String get display {
    if (artist != null && title != null) return '$artist — $title';
    return raw ?? title ?? artist ?? '';
  }
}

String _fixUtf(String raw) {
  // Radio Browser streams suelen mandar StreamTitle en UTF-8 pero lo leemos como latin1 → mojibake (MÃºsica)
  try {
    final bytes = latin1.encode(raw);
    final decoded = utf8.decode(bytes, allowMalformed: false);
    // Si el re-decode cambia y contiene acentos válidos, usarlo
    if (decoded != raw && (raw.contains('Ã') || raw.contains('Â') || decoded.runes.any((r) => r > 127))) {
      return decoded;
    }
  } catch (_) {}
  // Fallback: intentar utf8 directo si raw ya es utf8 mal decodificado con allowMalformed no aplica
  return raw;
}

RadioNowPlaying _split(String raw) {
  final s = _fixUtf(raw.trim());
  if (s.isEmpty) return const RadioNowPlaying();
  // Formato típico "Artist - Title"
  final sep = s.contains(' - ') ? ' - ' : (s.contains('-') ? '-' : null);
  if (sep != null) {
    final parts = s.split(sep);
    if (parts.length >= 2) {
      final artist = parts.first.trim();
      final title = parts.sublist(1).join(sep).trim();
      return RadioNowPlaying(artist: artist.isEmpty ? null : artist, title: title.isEmpty ? null : title, raw: s);
    }
  }
  return RadioNowPlaying(title: s, raw: s);
}

/// Intenta obtener StreamTitle vía cabecera ICY. Solo para la emisora que suena.
Future<RadioNowPlaying> fetchIcyNowPlaying(String streamUrl) async {
  if (streamUrl.isEmpty) return const RadioNowPlaying();
  final dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
    sendTimeout: const Duration(seconds: 4),
    followRedirects: true,
    validateStatus: (_) => true,
  ));
  try {
    // 1) Intento rápido: cabeceras que algunos servidores ya traen
    try {
      final head = await dio.head(streamUrl, options: Options(headers: {'Icy-MetaData': '1', 'User-Agent': 'Fynitiv/1.0'}));
      final hTitle = head.headers.map['icy-title']?.first ?? head.headers.map['x-audiocast-title']?.first ?? head.headers.map['ice-audio-info']?.first;
      if (hTitle != null && hTitle.trim().isNotEmpty) return _split(hTitle);
    } catch (_) {}

    // 2) Stream con Icy-MetaData: leer bloque icy
    final resp = await dio.get<ResponseBody>(
      streamUrl,
      options: Options(
        headers: {'Icy-MetaData': '1', 'User-Agent': 'Fynitiv/1.0', 'Connection': 'close'},
        responseType: ResponseType.stream,
        followRedirects: true,
        validateStatus: (s) => s != null && s < 400,
      ),
    );
    final headers = resp.headers;
    final icyMetaInt = int.tryParse(headers.map['icy-metaint']?.first ?? headers.map['icy-metaint']?.first ?? '');
    // Si no hay icy-metaint, intentar leer StreamTitle suelto en los primeros bytes
    final stream = resp.data!.stream;
    final buffer = <int>[];
    final completer = Completer<RadioNowPlaying>();
    StreamSubscription<List<int>>? sub;
    Timer? timer;
    timer = Timer(const Duration(seconds: 4), () {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(const RadioNowPlaying());
    });

    int total = 0;
    sub = stream.listen((chunk) {
      if (completer.isCompleted) return;
      buffer.addAll(chunk);
      total += chunk.length;
      // Buscar StreamTitle='...' en buffer latin1
      try {
        final str = latin1.decode(buffer, allowInvalid: true);
        final m = RegExp(r"StreamTitle='([^']*)'").firstMatch(str);
        if (m != null) {
          final raw = (m.group(1) ?? '').trim();
          timer?.cancel();
          sub?.cancel();
          if (!completer.isCompleted) completer.complete(_split(raw));
          return;
        }
      } catch (_) {}
      // Si no hayicy-metaint y ya leímos 16KB sin hallar, abortar
      if (total > 16384 && icyMetaInt == null) {
        timer?.cancel();
        sub?.cancel();
        if (!completer.isCompleted) {
          // Último intento: buscar título en cabeceras icy-title ya revisadas
          completer.complete(const RadioNowPlaying());
        }
      }
      // Si hay icy-metaint, el bloque está cada icyMetaInt bytes; con 16KB ya debería aparecer
      if (total > (icyMetaInt ?? 8192) * 2 + 2048) {
        timer?.cancel();
        sub?.cancel();
        if (!completer.isCompleted) completer.complete(const RadioNowPlaying());
      }
    }, onError: (_) {
      timer?.cancel();
      if (!completer.isCompleted) completer.complete(const RadioNowPlaying());
    }, onDone: () {
      timer?.cancel();
      if (!completer.isCompleted) completer.complete(const RadioNowPlaying());
    });

    final result = await completer.future;
    try { dio.close(force: true); } catch (_) {}
    return result;
  } catch (_) {
    try { dio.close(force: true); } catch (_) {}
    return const RadioNowPlaying();
  }
}
