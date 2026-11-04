import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../features/library/application/library_providers.dart';

/// Destino de reproducción para la vista detalle, según el tipo de contenido.
///
/// - Película y vídeo (`movie`, `episode`, `video`, `trailer`, `musicVideo`):
///   reproductor de vídeo (`/player`, media_kit).
/// - Música (`audio`, `audioBook`): mismo `/player`, que resuelve el audio
///   con SoLoud.
/// - Libro (`book`): lector (`/ereader/read/:id`).
/// - No reproducibles directos (serie, temporada, álbum, artista, playlist…):
///   [unsupported] (la serie ya tiene su propio VER por episodio).
enum DetailPlayTarget { videoPlayer, bookReader, unsupported }

/// Clasifica un item de la vista detalle en su reproductor.
DetailPlayTarget playTargetFor(BaseItemDto item) {
  switch (item.type) {
    case BaseItemKind.book:
      return DetailPlayTarget.bookReader;
    case BaseItemKind.movie:
    case BaseItemKind.episode:
    case BaseItemKind.video:
    case BaseItemKind.trailer:
    case BaseItemKind.musicVideo:
    case BaseItemKind.audio:
    case BaseItemKind.audioBook:
      return DetailPlayTarget.videoPlayer;
    default:
      return DetailPlayTarget.unsupported;
  }
}

/// Acción de "Ver ahora" en la vista detalle: empuja al reproductor que toca
/// según el tipo. Devuelve `true` si navegó. Con id vacío o tipo no
/// reproducible muestra el toast genérico (cadena ARB existente).
bool pushPlayForDetail(BuildContext context, BaseItemDto item) {
  final id = item.id;
  if (id == null || id.isEmpty) {
    final l10n = AppLocalizations.of(context);
    if (l10n != null) {
      unawaited(
        EasyLoading.showError(
          l10n.playbackFailed,
          dismissOnTap: true,
          maskType: EasyLoadingMaskType.none,
        ),
      );
    }
    return false;
  }
  switch (playTargetFor(item)) {
    case DetailPlayTarget.bookReader:
      context.push('/ereader/read/$id', extra: item);
      return true;
    case DetailPlayTarget.videoPlayer:
      context.push('/player/$id', extra: item);
      return true;
    case DetailPlayTarget.unsupported:
      final l10n = AppLocalizations.of(context);
      if (l10n != null) {
        unawaited(
          EasyLoading.showError(
            l10n.playbackFailed,
            dismissOnTap: true,
            maskType: EasyLoadingMaskType.none,
          ),
        );
      }
      return false;
  }
}

/// Tap en la fila de relacionados del detalle: lo reproducible directo va a
/// su reproductor y las colecciones a su ficha (que ya tiene reproducir).
void pushRelatedForDetail(BuildContext context, BaseItemDto item) {
  if (playTargetFor(item) == DetailPlayTarget.videoPlayer) {
    pushPlayForDetail(context, item);
    return;
  }
  pushDetailForType(context, item);
}

/// Abre la ficha que corresponde al tipo (no reproduce): libro → detalle del
/// lector, álbum/playlist/artista → sus pantallas de Música, temporada →
/// detalle de su serie, resto → detalle genérico.
void pushDetailForType(BuildContext context, BaseItemDto item) {
  final id = item.id;
  if (id == null || id.isEmpty) return;
  switch (item.type) {
    case BaseItemKind.book:
      context.push('/ereader/details/$id', extra: item);
    case BaseItemKind.musicAlbum:
      context.push('/music/album/$id', extra: item);
    case BaseItemKind.playlist:
      context.push('/music/playlist/$id', extra: item);
    case BaseItemKind.musicArtist:
      final name = (item.name ?? '').trim();
      if (name.isEmpty) {
        context.push('/home/details/$id', extra: item);
      } else {
        context.push(
          '/music/artist/${Uri.encodeComponent(name)}',
          extra: {'jellyfin': item},
        );
      }
    case BaseItemKind.season:
      final target = seriesDetailTarget(item);
      final targetId = target.id;
      if (targetId != null && targetId.isNotEmpty) {
        context.push(
          '/home/details/$targetId',
          extra: targetId == id ? item : target,
        );
      } else {
        context.push('/home/details/$id', extra: item);
      }
    default:
      context.push('/home/details/$id', extra: item);
  }
}
