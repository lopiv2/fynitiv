import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../auth/application/auth_controller.dart';

/// Consulta de subtítulos remotos: item + idioma (ISO 639-2/B, 3 letras).
class RemoteSubtitleQuery {
  const RemoteSubtitleQuery({required this.itemId, required this.language});

  final String itemId;
  final String language;

  @override
  bool operator ==(Object other) =>
      other is RemoteSubtitleQuery &&
      other.itemId == itemId &&
      other.language == language;

  @override
  int get hashCode => Object.hash(itemId, language);
}

/// Busca subtítulos remotos para un item e idioma usando la API de Jellyfin
/// (proveedor configurado en el servidor, p. ej. el plugin de OpenSubtitles).
final remoteSubtitleSearchProvider =
    FutureProvider.family<List<RemoteSubtitleInfo>, RemoteSubtitleQuery>((
  ref,
  query,
) async {
  final client = ref.watch(jellyfinClientProvider);
  if (client == null || query.itemId.isEmpty || query.language.isEmpty) {
    return const [];
  }

  // Cache corta: al reabrir la hoja o cambiar de idioma no se repite la
  // llamada de forma inmediata.
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 2), link.close);
  ref.onDispose(timer.cancel);

  final res = await client.getSubtitleApi().searchRemoteSubtitles(
        itemId: query.itemId,
        language: query.language,
      );
  return res.data ?? const <RemoteSubtitleInfo>[];
});
