import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../library/application/library_providers.dart';

class DeezerTrack {
  const DeezerTrack({
    required this.id,
    required this.title,
    required this.artistName,
    required this.artistPicture,
    required this.cover,
    required this.preview,
    required this.explicit,
    required this.position,
    this.duration = 0,
  });

  final int id;
  final String title;
  final String artistName;
  final String artistPicture;
  final String cover;
  final String preview;
  final bool explicit;
  final int position;
  final int duration;

  factory DeezerTrack.fromJson(Map<String, dynamic> json) {
    final artist = json['artist'] as Map<String, dynamic>? ?? {};
    final album = json['album'] as Map<String, dynamic>? ?? {};
    return DeezerTrack(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      artistName: (artist['name'] as String?) ?? '',
      artistPicture: (artist['picture_xl'] as String?) ?? (artist['picture_big'] as String?) ?? '',
      cover: (album['cover_xl'] as String?) ?? (album['cover_big'] as String?) ?? (json['md5_image'] as String?) ?? '',
      preview: (json['preview'] as String?) ?? '',
      explicit: json['explicit_lyrics'] == true,
      position: (json['position'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeezerArtist {
  const DeezerArtist({
    required this.id,
    required this.name,
    required this.picture,
    required this.position,
  });

  final int id;
  final String name;
  final String picture;
  final int position;

  factory DeezerArtist.fromJson(Map<String, dynamic> json) {
    return DeezerArtist(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      picture: (json['picture_xl'] as String?) ?? (json['picture_big'] as String?) ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeezerChart {
  const DeezerChart({required this.tracks, required this.artists, required this.albums});
  final List<DeezerTrack> tracks;
  final List<DeezerArtist> artists;
  final List<Map<String, dynamic>> albums;
}

final _dioDeezer = Dio();

final deezerChartProvider = FutureProvider<DeezerChart>((ref) async {
  final res = await _dioDeezer.get('https://api.deezer.com/chart', queryParameters: {'limit': 20});
  final data = res.data as Map<String, dynamic>;
  final tracks = ((data['tracks'] as Map?)?['data'] as List? ?? [])
      .map((e) => DeezerTrack.fromJson(e as Map<String, dynamic>))
      .toList();
  final artists = ((data['artists'] as Map?)?['data'] as List? ?? [])
      .map((e) => DeezerArtist.fromJson(e as Map<String, dynamic>))
      .toList();
  final albums = ((data['albums'] as Map?)?['data'] as List? ?? []).cast<Map<String, dynamic>>();
  return DeezerChart(tracks: tracks, artists: artists, albums: albums);
});

final deezerTrendingSongsProvider = FutureProvider<List<DeezerTrack>>((ref) async {
  final chart = await ref.watch(deezerChartProvider.future);
  return chart.tracks;
});

final deezerPopularArtistsProvider = FutureProvider<List<DeezerArtist>>((ref) async {
  final chart = await ref.watch(deezerChartProvider.future);
  return chart.artists;
});

/// Top tracks de un artista en Deezer (máx 20) por id o por búsqueda nombre.
final deezerArtistTopTracksProvider = FutureProvider.family<List<DeezerTrack>, String>((ref, artistQuery) async {
  return ref.watch(deezerArtistTopTracksWithLimitProvider(DeezerTopTracksArgs(query: artistQuery, limit: 20)).future);
});

class DeezerTopTracksArgs {
  const DeezerTopTracksArgs({required this.query, required this.limit});
  final String query;
  final int limit;
  @override
  bool operator ==(Object other) => other is DeezerTopTracksArgs && other.query == query && other.limit == limit;
  @override
  int get hashCode => Object.hash(query, limit);
}

/// Top tracks con límite configurable (para rellenar huecos por duplicados internos Deezer).
final deezerArtistTopTracksWithLimitProvider =
    FutureProvider.family<List<DeezerTrack>, DeezerTopTracksArgs>((ref, args) async {
  final artistQuery = args.query;
  final limit = args.limit;
  try {
    if (artistQuery.startsWith('id:')) {
      final id = artistQuery.substring(3);
      final res = await _dioDeezer.get('https://api.deezer.com/artist/$id/top', queryParameters: {'limit': limit});
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List? ?? []).map((e) => DeezerTrack.fromJson(e as Map<String, dynamic>)).toList();
      if (list.isNotEmpty) return list;
    }
    final res = await _dioDeezer.get('https://api.deezer.com/search/track', queryParameters: {'q': 'artist:"$artistQuery"', 'limit': limit});
    final data = res.data as Map<String, dynamic>;
    final list = (data['data'] as List? ?? []).map((e) => DeezerTrack.fromJson(e as Map<String, dynamic>)).toList();
    return list;
  } catch (_) {
    return const [];
  }
});

/// Detalle artista Deezer para nb_fan / picture.
final deezerArtistDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, artistId) async {
  if (artistId.startsWith('id:')) {
    final id = artistId.substring(3);
    try {
      final res = await _dioDeezer.get('https://api.deezer.com/artist/$id');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
  return null;
});

/// Verifica si un DeezerTrack existe en la biblioteca Jellyfin (por búsqueda título+artista).
final deezerTrackExistsInJellyfinProvider = FutureProvider.family<bool, DeezerTrack>((ref, track) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return false;
  try {
    final res = await client.getItemsApi().getItems(
          userId: userId,
          recursive: true,
          searchTerm: '${track.title} ${track.artistName}',
          includeItemTypes: [BaseItemKind.audio],
          limit: 2,
        );
    final items = res.data?.items ?? const [];
    return items.any((e) => (e.name ?? '').toLowerCase().contains(track.title.toLowerCase()));
  } catch (_) {
    return false;
  }
});
