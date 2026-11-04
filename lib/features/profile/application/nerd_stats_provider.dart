import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../games/application/romm_providers.dart';
import '../../library/application/library_providers.dart';
import '../domain/nerd_stats.dart';

/// Ticks de Jellyfin: 10 000 000 por segundo → 600 000 000 por minuto.
const int _kTicksPerMinute = 10000000 * 60;

/// Estadísticas de nerd del usuario actual.
///
/// Se calculan a partir de la biblioteca de Jellyfin (items marcados como
/// vistos y suma de sus duraciones) y, si ROMM está configurado, de la
/// ludoteca. Todo es tolerante a fallos: si una métrica no se puede obtener,
/// se queda a cero en lugar de romper la pantalla.
final nerdStatsProvider = FutureProvider<NerdStats>((ref) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);

  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);

  var moviesWatched = 0;
  var episodesWatched = 0;
  var seriesStarted = 0;
  var songsPlayed = 0;
  var booksRead = 0;
  var videoMinutes = 0;
  var musicMinutes = 0;

  if (client != null && userId != null) {
    Future<({int count, int minutes})> played({
      required List<BaseItemKind> types,
      int limit = 1000,
    }) async {
      final res = await client.getItemsApi().getItems(
        userId: userId,
        recursive: true,
        includeItemTypes: types,
        isPlayed: true,
        limit: limit,
        enableTotalRecordCount: true,
        enableImages: false,
        enableUserData: false,
        fields: const [],
      );
      final items = res.data?.items ?? const <BaseItemDto>[];
      final ticks = items.fold<int>(0, (sum, e) => sum + (e.runTimeTicks ?? 0));
      return (
        count: res.data?.totalRecordCount ?? items.length,
        minutes: ticks ~/ _kTicksPerMinute,
      );
    }

    try {
      final results = await Future.wait([
        played(types: [BaseItemKind.movie]),
        played(types: [BaseItemKind.episode], limit: 2000),
        played(types: [BaseItemKind.series], limit: 0),
        played(types: [BaseItemKind.audio], limit: 2000),
        played(types: [BaseItemKind.book], limit: 0),
      ]);
      moviesWatched = results[0].count;
      videoMinutes += results[0].minutes;
      episodesWatched = results[1].count;
      videoMinutes += results[1].minutes;
      seriesStarted = results[2].count;
      songsPlayed = results[3].count;
      musicMinutes += results[3].minutes;
      booksRead = results[4].count;
    } catch (_) {
      // Sin conexión o servidor antiguo: se muestran los ceros ya asignados.
    }
  }

  var gamesOwned = 0;
  var gamesPlayed = 0;
  var platforms = 0;
  final rommRepo = ref.watch(rommRepositoryProvider);
  if (rommRepo != null) {
    try {
      final all = await rommRepo.getGames(limit: 1);
      gamesOwned = all.total;
      final played = await rommRepo.getGames(limit: 1, lastPlayed: true);
      gamesPlayed = played.total;
      platforms = (await ref.watch(rommPlatformsProvider.future)).length;
    } catch (_) {
      // ROMM configurado pero caído: no se muestran sus métricas.
    }
  }

  return NerdStats(
    moviesWatched: moviesWatched,
    episodesWatched: episodesWatched,
    seriesStarted: seriesStarted,
    songsPlayed: songsPlayed,
    booksRead: booksRead,
    videoMinutes: videoMinutes,
    musicMinutes: musicMinutes,
    gamesOwned: gamesOwned,
    gamesPlayed: gamesPlayed,
    platforms: platforms,
  );
});
