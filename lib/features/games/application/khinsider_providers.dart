import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/khinsider/khinsider_models.dart';
import '../data/khinsider/khinsider_scraper.dart';
import 'romm_providers.dart';

final khinsiderScraperProvider = Provider<KhinsiderScraper>((ref) => KhinsiderScraper());

/// Tracks de Khinsider para un juego por su id (usa nombre del RommGame).
final khinsiderTracksProvider = FutureProvider.family<List<KhinsiderTrack>, int>((ref, gameId) async {
  final game = await ref.watch(rommGameProvider(gameId).future);
  final name = game.name.trim();
  if (name.isEmpty) return [];
  final scraper = ref.read(khinsiderScraperProvider);
  final tracks = await scraper.searchAndGetTracks(name);
  return tracks;
});

/// Album encontrado (opcional, para mostrar título)
final khinsiderAlbumProvider = FutureProvider.family<KhinsiderAlbum?, int>((ref, gameId) async {
  final game = await ref.watch(rommGameProvider(gameId).future);
  final name = game.name.trim();
  if (name.isEmpty) return null;
  final scraper = ref.read(khinsiderScraperProvider);
  return scraper.searchAlbum(name);
});
