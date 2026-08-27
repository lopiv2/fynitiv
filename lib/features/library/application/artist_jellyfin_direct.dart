import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

/// Helper de prueba para comparar jellyfin_dart vs API directa
/// https://api.jellyfin.org/#tag/Artist/operation/GetArtistByName -> GET /Artists/{Name}
/// Exacto, sin parentId, con debugPrint y Stopwatch como pediste.

class ArtistDirectResult {
  const ArtistDirectResult({required this.elapsedMs, this.artist, this.items, this.error});
  final int elapsedMs;
  final BaseItemDto? artist;
  final List<BaseItemDto>? items;
  final String? error;
}

/// Llamada exacta sin parentId, con debugPrint, para benchmark
Future<ArtistDirectResult> fetchArtistByNameExactDirect({
  required String serverUrl,
  required String? token,
  required String? userId,
  required String artistName,
}) async {
  final name = artistName.trim();
  if (name.isEmpty || serverUrl.isEmpty) {
    return const ArtistDirectResult(elapsedMs: 0, error: 'empty params');
  }
  final dio = Dio(BaseOptions(
    baseUrl: serverUrl.replaceAll(RegExp(r'/$'), ''),
    headers: {
      if (token != null && token.isNotEmpty) 'X-Emby-Token': token,
      'Content-Type': 'application/json',
    },
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));
  final sw = Stopwatch()..start();
  try {
    // Intento 1: GET /Artists/{Name} exacto (docs api.jellyfin.org)
    // Algunos servidores requieren userId como query: /Artists/{Name}?userId={userId}
    Response? res;
    String? urlTried;
    try {
      urlTried = '/Artists/${Uri.encodeComponent(name)}';
      debugPrint('[DIRECT][ArtistByName] START exact GET $urlTried');
      res = await dio.get(urlTried, queryParameters: {
        if (userId != null) 'userId': userId,
      });
      debugPrint('[DIRECT][ArtistByName] exact ${sw.elapsedMilliseconds}ms status=${res.statusCode} data=${res.data is Map ? (res.data as Map).keys.take(5).toList() : res.data.runtimeType}');
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final dto = BaseItemDto.fromJson(res.data as Map<String, dynamic>);
        // Si lo encontramos exacto, traer sus pistas vía Items con artistIds (sin parentId como pediste)
        final sw2 = Stopwatch()..start();
        final itemsRes = await dio.get('/Users/$userId/Items', queryParameters: {
          'ArtistIds': dto.id,
          'IncludeItemTypes': 'Audio',
          'Recursive': true,
          'Limit': 50,
          'Fields': 'PrimaryImageAspectRatio',
          'EnableTotalRecordCount': false,
        });
        final itemsData = itemsRes.data as Map<String, dynamic>?;
        final items = (itemsData?['Items'] as List? ?? []).map((e) => BaseItemDto.fromJson(e as Map<String, dynamic>)).toList();
        debugPrint('[DIRECT][ArtistByName] getItems by ArtistIds ${sw2.elapsedMilliseconds}ms -> ${items.length} (total ${sw.elapsedMilliseconds}ms)');
        return ArtistDirectResult(elapsedMs: sw.elapsedMilliseconds, artist: dto, items: items);
      }
    } catch (e) {
      debugPrint('[DIRECT][ArtistByName] exact failed ${sw.elapsedMilliseconds}ms $e url=$urlTried');
    }

    // Intento 2: fallback Artists?searchTerm exact via /Artists?SearchTerm=
    try {
      final sw2 = Stopwatch()..start();
      final res2 = await dio.get('/Artists', queryParameters: {
        if (userId != null) 'userId': userId,
        'SearchTerm': name,
        'Limit': 5,
      });
      debugPrint('[DIRECT][ArtistByName] fallback /Artists?SearchTerm ${sw2.elapsedMilliseconds}ms status=${res2.statusCode}');
      final data = res2.data;
      List list;
      if (data is Map && data['Items'] is List) list = data['Items'] as List;
      else if (data is List) list = data;
      else list = const [];
      if (list.isNotEmpty) {
        final first = BaseItemDto.fromJson(list.first as Map<String, dynamic>);
        debugPrint('[DIRECT][ArtistByName] fallback found ${first.name} id=${first.id}');
        return ArtistDirectResult(elapsedMs: sw.elapsedMilliseconds, artist: first, items: const []);
      }
    } catch (e) {
      debugPrint('[DIRECT][ArtistByName] fallback error ${sw.elapsedMilliseconds}ms $e');
    }

    return ArtistDirectResult(elapsedMs: sw.elapsedMilliseconds, error: 'not found');
  } catch (e, st) {
    debugPrint('[DIRECT][ArtistByName] ERROR ${sw.elapsedMilliseconds}ms $e $st');
    return ArtistDirectResult(elapsedMs: sw.elapsedMilliseconds, error: '$e');
  }
}

/// Benchmark comparativo jellyfin_dart vs directo
Future<void> benchmarkArtistFetch({
  required String serverUrl,
  required String? token,
  required String? userId,
  required String artistName,
  required JellyfinDart? jellyfinClient,
}) async {
  debugPrint('=== BENCHMARK Artist "$artistName" server=$serverUrl user=$userId ===');
  // 1. jellyfin_dart Vía ArtistsApi
  final swJelly = Stopwatch()..start();
  try {
    if (jellyfinClient != null && userId != null) {
      final res = await jellyfinClient.getArtistsApi().getAlbumArtists(userId: userId, searchTerm: artistName, limit: 5).timeout(const Duration(seconds: 10));
      debugPrint('[BENCH][jellyfin_dart] ArtistsApi ${swJelly.elapsedMilliseconds}ms -> ${res.data?.items?.length ?? 0}');
      if (res.data?.items?.isNotEmpty == true) {
        final id = res.data!.items!.first.id!;
        final sw2 = Stopwatch()..start();
        final itemsRes = await jellyfinClient.getItemsApi().getItems(userId: userId, artistIds: [id], includeItemTypes: [BaseItemKind.audio], recursive: true, limit: 50).timeout(const Duration(seconds: 10));
        debugPrint('[BENCH][jellyfin_dart] getItems by artistId ${sw2.elapsedMilliseconds}ms -> ${itemsRes.data?.items?.length ?? 0} (total ${swJelly.elapsedMilliseconds}ms)');
      }
    }
  } catch (e) {
    debugPrint('[BENCH][jellyfin_dart] ERROR ${swJelly.elapsedMilliseconds}ms $e');
  }

  // 2. Directo exact sin parentId
  final direct = await fetchArtistByNameExactDirect(serverUrl: serverUrl, token: token, userId: userId, artistName: artistName);
  debugPrint('[BENCH][direct] ${direct.elapsedMs}ms artist=${direct.artist?.name} items=${direct.items?.length} error=${direct.error}');
  debugPrint('=== END BENCHMARK ===');
}
