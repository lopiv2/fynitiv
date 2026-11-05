import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

import '../../library/application/image_url.dart';
import '../../library/application/library_providers.dart';
import '../../library/application/library_tmdb_index.dart';
import '../../seerr/application/seerr_controller.dart';
import '../../seerr/application/seerr_providers.dart';
import '../../seerr/domain/seerr_models.dart';
import '../domain/curated_franchise.dart';

TmdbMediaType _tmdbType(SeerrMediaType type) =>
    type == SeerrMediaType.movie ? TmdbMediaType.movie : TmdbMediaType.series;

/// Catálogo curado cargado desde `assets/data/franchises.json`.
final franchiseCatalogProvider =
    FutureProvider<CuratedFranchiseCatalog>((ref) async {
      final raw = await rootBundle.loadString('assets/data/franchises.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const CuratedFranchiseCatalog(version: 1, franchises: []);
      }
      return CuratedFranchiseCatalog.fromJson(
        decoded.cast<String, dynamic>(),
      );
    });

/// Entrada de una franquicia: item curado + lo que hay en Jellyfin o los
/// metadatos de Seerr para los que faltan.
class FranchiseEntry {
  const FranchiseEntry({required this.item, this.owned, this.external});

  final CuratedFranchiseItem item;

  /// Item real de Jellyfin (null = no está en la biblioteca).
  final BaseItemDto? owned;

  /// Ficha de Seerr para pintar el faltante (título/carátula) y poder pedirlo.
  final SeerrMedia? external;

  bool get isOwned => owned != null;
}

/// Elementos de una franquicia en el orden curado, mezclando lo que hay en
/// Jellyfin y lo que falta (con metadatos de Seerr si está configurado).
final franchiseEntriesProvider =
    FutureProvider.family<List<FranchiseEntry>, String>((
      ref,
      franchiseId,
    ) async {
      final catalog = await ref.watch(franchiseCatalogProvider.future);
      final franchise = catalog.byId(franchiseId);
      if (franchise == null) return const [];
      final index = await ref.watch(libraryTmdbIndexProvider.future);
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      final api = ref.watch(seerrApiProvider);

      BaseItemDto? indexed(CuratedFranchiseItem item) =>
          index[(type: _tmdbType(item.type), tmdbId: item.tmdbId)];

      bool isOwnedItem(BaseItemDto? item) {
        final id = item?.id;
        return item != null &&
            id != null &&
            id.isNotEmpty &&
            !isPlaceholderItem(item);
      }

      final ownedIds = <String>[];
      for (final item in franchise.items) {
        final hit = indexed(item);
        if (isOwnedItem(hit)) ownedIds.add(hit!.id!);
      }

      final hydrated = <String, BaseItemDto>{};
      if (client != null && userId != null && ownedIds.isNotEmpty) {
        final res = await client.getItemsApi().getItems(
          userId: userId,
          ids: ownedIds,
          fields: const [
            ItemFields.primaryImageAspectRatio,
            ItemFields.overview,
            ItemFields.genres,
          ],
          enableImageTypes: const [
            ImageType.primary,
            ImageType.backdrop,
            ImageType.logo,
          ],
          enableUserData: true,
        );
        for (final item in res.data?.items ?? const <BaseItemDto>[]) {
          final id = item.id;
          if (id != null && id.isNotEmpty) hydrated[id] = item;
        }
      }

      final missing = <CuratedFranchiseItem>[];
      for (final item in franchise.items) {
        final hit = indexed(item);
        final owned = isOwnedItem(hit) ? hydrated[hit!.id] : null;
        if (owned == null) missing.add(item);
      }

      final externals = <TmdbKey, SeerrMedia>{};
      if (api != null && missing.isNotEmpty) {
        final results = await Future.wait(
          missing.map((item) async {
            try {
              return await ref.watch(
                seerrDetailProvider((
                  mediaType: item.type,
                  tmdbId: item.tmdbId,
                )).future,
              );
            } catch (_) {
              return null;
            }
          }),
        );
        for (var i = 0; i < missing.length; i++) {
          final media = results[i];
          if (media == null) continue;
          externals[(
            type: _tmdbType(missing[i].type),
            tmdbId: missing[i].tmdbId,
          )] = media;
        }
      }

      final entries = <FranchiseEntry>[];
      for (final item in franchise.items) {
        final hit = indexed(item);
        final owned = isOwnedItem(hit) ? hydrated[hit!.id] : null;
        if (owned != null) {
          entries.add(FranchiseEntry(item: item, owned: owned));
        } else {
          entries.add(
            FranchiseEntry(
              item: item,
              external: externals[(type: _tmdbType(item.type), tmdbId: item.tmdbId)],
            ),
          );
        }
      }
      return entries;
    });

/// Entrada del hub "Franquicias": progreso y carátula para la fila.
class FranchiseHubEntry {
  const FranchiseHubEntry({
    required this.franchise,
    required this.owned,
    required this.total,
    this.imageUrl,
    this.logo,
  });

  final CuratedFranchise franchise;
  final int owned;
  final int total;
  final String? imageUrl;

  /// Logo de la franquicia para superponer sobre la imagen de la película.
  final String? logo;
}

/// Franquicias del catálogo con cuántos títulos tienes y una carátula.
final franchiseHubProvider =
    FutureProvider<List<FranchiseHubEntry>>((ref) async {
      final catalog = await ref.watch(franchiseCatalogProvider.future);
      final index = await ref.watch(libraryTmdbIndexProvider.future);
      final client = ref.watch(jellyfinClientProvider);
      final userId = ref.watch(currentUserIdProvider);
      final serverUrl = ref.watch(authServerUrlProvider);
      final api = ref.watch(seerrApiProvider);
      final hasSeerr = api != null;

      final ownedCounts = <String, int>{};
      final firstOwnedId = <String, String>{};
      for (final franchise in catalog.franchises) {
        var count = 0;
        for (final item in franchise.items) {
          final hit = index[(type: _tmdbType(item.type), tmdbId: item.tmdbId)];
          final id = hit?.id;
          if (hit == null ||
              id == null ||
              id.isEmpty ||
              isPlaceholderItem(hit)) {
            continue;
          }
          count++;
          firstOwnedId.putIfAbsent(franchise.id, () => id);
        }
        ownedCounts[franchise.id] = count;
      }

      final hydrated = <String, BaseItemDto>{};
      final ids = firstOwnedId.values.toSet().toList();
      if (client != null && userId != null && ids.isNotEmpty) {
        final res = await client.getItemsApi().getItems(
          userId: userId,
          ids: ids,
          fields: const [ItemFields.primaryImageAspectRatio],
          enableImageTypes: const [ImageType.primary, ImageType.logo],
          enableUserData: false,
        );
        for (final item in res.data?.items ?? const <BaseItemDto>[]) {
          final id = item.id;
          if (id != null && id.isNotEmpty) hydrated[id] = item;
        }
      }

      final out = <FranchiseHubEntry>[];
      for (final franchise in catalog.franchises) {
        final owned = ownedCounts[franchise.id] ?? 0;
        // Sin Seerr, una franquicia de la que no tienes nada no aporta.
        if (owned == 0 && !hasSeerr) continue;
        final firstId = firstOwnedId[franchise.id];
        final firstItem = firstId == null ? null : hydrated[firstId];
        // Imagen de una película de la franquicia: carátula de la primera que
        // tengas; si no tienes ninguna, la de la primera en Seerr.
        // Imagen local del usuario (posterAsset del JSON): prioridad máxima.
        // El resto (Jellyfin/Seerr/TMDB) solo es fallback.
        String? imageUrl = franchise.posterAsset?.trim();
        if (imageUrl != null && imageUrl.isEmpty) imageUrl = null;
        if (imageUrl == null && serverUrl != null && firstItem != null) {
          imageUrl = itemImageUrl(serverUrl, firstItem);
        }
        if (imageUrl == null && api != null && franchise.items.isNotEmpty) {
          final first = franchise.items.first;
          try {
            final media = await ref.watch(
              seerrDetailProvider((
                mediaType: first.type,
                tmdbId: first.tmdbId,
              )).future,
            );
            imageUrl = media.posterUrl();
          } catch (_) {}
        }
        imageUrl ??= franchise.posterUrl();
        out.add(
          FranchiseHubEntry(
            franchise: franchise,
            owned: owned,
            total: franchise.items.length,
            imageUrl: imageUrl,
            logo: franchise.logo,
          ),
        );
      }
      return out;
    });
