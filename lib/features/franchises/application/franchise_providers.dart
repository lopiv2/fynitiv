import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Entrada de una franquicia: item curado + lo que hay en Jellyfin.
class FranchiseEntry {
  const FranchiseEntry({required this.item, this.owned});

  final CuratedFranchiseItem item;

  /// Item real de Jellyfin (null = no está en la biblioteca).
  final BaseItemDto? owned;

  bool get isOwned => owned != null;
}

/// Metadatos externos de Seerr para los títulos que faltan en la biblioteca.
typedef FranchiseExternalMedia = Map<TmdbKey, SeerrMedia>;

/// Mapa vacío reutilizable para cuando aún no hay fichas externas.
const FranchiseExternalMedia emptyFranchiseExternal = {};

/// Ficha externa de [item], si ya se cargó.
SeerrMedia? franchiseExternalFor(
  FranchiseExternalMedia externals,
  CuratedFranchiseItem item,
) => externals[(type: _tmdbType(item.type), tmdbId: item.tmdbId)];

BaseItemDto? _indexedItem(
  Map<TmdbKey, BaseItemDto> index,
  CuratedFranchiseItem item,
) => index[(type: _tmdbType(item.type), tmdbId: item.tmdbId)];

bool _isOwnedItem(BaseItemDto? item) {
  final id = item?.id;
  return item != null &&
      id != null &&
      id.isNotEmpty &&
      !isPlaceholderItem(item);
}

bool _isOwnedInIndex(
  Map<TmdbKey, BaseItemDto> index,
  CuratedFranchiseItem item,
) => _isOwnedItem(_indexedItem(index, item));

/// Orden elegido en la pantalla de franquicia; se conserva al navegar entre
/// sagas y entre reinicios de la app.
const _kFranchiseSortOrderKey = 'app.franchise_sort_order';

class FranchiseSortOrderController extends Notifier<FranchiseSortOrder> {
  @override
  FranchiseSortOrder build() {
    _load();
    return FranchiseSortOrder.release;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFranchiseSortOrderKey);
    if (raw == null) return;
    final stored = FranchiseSortOrder.values.asNameMap()[raw];
    if (stored != null) state = stored;
  }

  Future<void> set(FranchiseSortOrder order) async {
    state = order;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFranchiseSortOrderKey, order.name);
  }
}

final franchiseSortOrderProvider =
    NotifierProvider<FranchiseSortOrderController, FranchiseSortOrder>(
      FranchiseSortOrderController.new,
    );

/// Ordena las entradas por estreno o cronología, con el orden del catálogo
/// como desempate.
List<FranchiseEntry> sortedFranchiseEntries(
  List<FranchiseEntry> entries,
  FranchiseSortOrder order,
) {
  final indexed = entries.asMap().entries.toList();
  indexed.sort((a, b) {
    final byKey = a.value.item
        .sortKey(order, catalogIndex: a.key)
        .compareTo(b.value.item.sortKey(order, catalogIndex: b.key));
    return byKey != 0 ? byKey : a.key.compareTo(b.key);
  });
  return [for (final entry in indexed) entry.value];
}

/// Elementos de una franquicia en el orden curado: catálogo + biblioteca.
///
/// No espera a Seerr: los metadatos de los faltantes se cargan aparte en
/// [franchiseExternalProvider] para que el grid aparezca cuanto antes.
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

      final ownedIds = <String>[];
      for (final item in franchise.items) {
        final hit = _indexedItem(index, item);
        if (_isOwnedItem(hit)) ownedIds.add(hit!.id!);
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

      return [
        for (final item in franchise.items)
          FranchiseEntry(
            item: item,
            owned: _isOwnedItem(_indexedItem(index, item))
                ? hydrated[_indexedItem(index, item)!.id]
                : null,
          ),
      ];
    });

/// Metadatos de Seerr para los títulos de una franquicia que no están en la
/// biblioteca. Se piden en lotes pequeños y con timeout, emitiendo el mapa
/// conforme llegan para que las carátulas se completen sin bloquear el grid.
final franchiseExternalProvider =
    StreamProvider.family<FranchiseExternalMedia, String>((
      ref,
      franchiseId,
    ) async* {
      final api = ref.watch(seerrApiProvider);
      if (api == null) return;
      final catalog = await ref.watch(franchiseCatalogProvider.future);
      final franchise = catalog.byId(franchiseId);
      if (franchise == null) return;

      final index = await ref.watch(libraryTmdbIndexProvider.future);
      final missing = [
        for (final item in franchise.items)
          if (!_isOwnedInIndex(index, item)) item,
      ];
      if (missing.isEmpty) return;

      final out = <TmdbKey, SeerrMedia>{};
      const batchSize = 6;
      const timeout = Duration(seconds: 8);
      for (var start = 0; start < missing.length; start += batchSize) {
        final batch = missing.skip(start).take(batchSize).toList();
        final before = out.length;
        final results = await Future.wait(
          batch.map((item) async {
            try {
              // `read` y no `watch`: la ficha se pide una vez y no debe
              // reejecutar este provider cada vez que responde una.
              return await ref
                  .read(
                    seerrDetailProvider((
                      mediaType: item.type,
                      tmdbId: item.tmdbId,
                    )).future,
                  )
                  .timeout(timeout);
            } catch (_) {
              return null;
            }
          }),
        );
        for (var i = 0; i < batch.length; i++) {
          final media = results[i];
          if (media == null) continue;
          out[(type: _tmdbType(batch[i].type), tmdbId: batch[i].tmdbId)] = media;
        }
        if (out.length != before) {
          yield Map<TmdbKey, SeerrMedia>.of(out);
        }
      }
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
