import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../library/application/library_providers.dart';
import '../data/book_format.dart';
import '../data/comic_info.dart';
import '../data/epub_metadata.dart';

/// Colección on-the-fly agrupada por metadatos locales.
class EReaderCollection {
  const EReaderCollection({required this.title, required this.items});

  final String title;
  final List<BaseItemDto> items;
}

/// Colecciones generadas en cliente a partir de metadatos locales:
/// Serie (`seriesName`) → Autor (`artists` o `people` tipo autor) →
/// Género (`genres`).
/// Solo grupos con 2+ libros (género 3+ para evitar ruido). Cada libro aparece
/// como máximo en una colección y los sueltos quedan en "Todos los libros".
/// Llamada propia (una sola) porque las páginas del grid no traen `people`.
final eReaderCollectionsProvider = FutureProvider<List<EReaderCollection>>((
  ref,
) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  try {
    final total = await ref.watch(eReaderBooksCountProvider.future);
    if (total == 0) {
      debugPrint('[ereader] collections: biblioteca sin libros');
      return const [];
    }
    final res = await client.getItemsApi().getItems(
      userId: userId,
      recursive: true,
      includeItemTypes: const [BaseItemKind.book],
      startIndex: 0,
      // Tope de seguridad: 5000 libros.
      limit: total.clamp(1, 5000),
      sortBy: const [ItemSortBy.sortName],
      sortOrder: const [SortOrder.ascending],
      fields: const [
        ItemFields.primaryImageAspectRatio,
        ItemFields.overview,
        ItemFields.genres,
        ItemFields.people,
      ],
      enableImageTypes: const [ImageType.primary],
    );
    final all = excludePlaceholders(res.data?.items ?? []);
    if (all.isEmpty) {
      debugPrint('[ereader] collections: total=$total pero sin items');
      return const [];
    }

    // Metadatos embebidos (OPF de EPUB / ComicInfo.xml de cómics) con caché
    // persistente, solo para los que no traen serie ni autor del servidor.
    // En segundo plano y con topes: no bloquea la pantalla, las filas
    // aparecen al resolverse el provider.
    final embedded = await _embeddedMetaForMissing(client, all);

    bool isUsed(BaseItemDto item, Set<String> used) =>
        item.id != null && used.contains(item.id);

    void markUsed(List<BaseItemDto> items, Set<String> used) {
      for (final item in items) {
        final id = item.id;
        if (id != null) used.add(id);
      }
    }

    final used = <String>{};
    final collections = <EReaderCollection>[];

    // 1. Por serie/saga (servidor o embebida).
    final bySeries = <String, List<BaseItemDto>>{};
    for (final item in all) {
      final series = _seriesOf(item, embedded);
      if (series.isEmpty) continue;
      (bySeries[series] ??= []).add(item);
    }
    final seriesNames = bySeries.keys.toList()..sort();
    for (final name in seriesNames) {
      final items = bySeries[name]!;
      if (items.length < 2) continue;
      collections.add(EReaderCollection(title: name, items: items));
      markUsed(items, used);
    }

    // 2. Por autor (restantes, servidor o embebido).
    final byAuthor = <String, List<BaseItemDto>>{};
    for (final item in all) {
      if (isUsed(item, used)) continue;
      final author = _authorOf(item, embedded);
      if (author.isEmpty) continue;
      (byAuthor[author] ??= []).add(item);
    }
    final authorNames = byAuthor.keys.toList()
      ..sort((a, b) => byAuthor[b]!.length.compareTo(byAuthor[a]!.length));
    for (final name in authorNames) {
      final items = byAuthor[name]!;
      if (items.length < 2) continue;
      collections.add(EReaderCollection(title: name, items: items));
      markUsed(items, used);
    }

    // 3. Por género (restantes: primero del servidor o embebido).
    final byGenre = <String, List<BaseItemDto>>{};
    for (final item in all) {
      if (isUsed(item, used)) continue;
      final genre = _genreOf(item, embedded);
      if (genre.isEmpty) continue;
      (byGenre[genre] ??= []).add(item);
    }
    final genreNames = byGenre.keys.toList()
      ..sort((a, b) => byGenre[b]!.length.compareTo(byGenre[a]!.length));
    for (final name in genreNames) {
      final items = byGenre[name]!;
      if (items.length < 3) continue;
      collections.add(EReaderCollection(title: name, items: items));
      markUsed(items, used);
    }

    debugPrint(
      '[ereader] collections: ${all.length} libros -> '
      '${collections.length} filas '
      '(${collections.map((c) => '${c.title} x${c.items.length}').take(20).join(', ')})',
    );
    return collections;
  } catch (e) {
    debugPrint('[ereader] collections failed: $e');
    rethrow;
  }
});

/// Serie de un libro: `seriesName` del servidor o serie embebida
/// (Calibre en OPF / `Series` de ComicInfo.xml).
String _seriesOf(BaseItemDto item, Map<String, _EmbeddedMeta> embedded) {
  final series = item.seriesName?.trim() ?? '';
  if (series.isNotEmpty) return series;
  final id = item.id;
  if (id != null) return embedded[id]?.series.trim() ?? '';
  return '';
}

/// Autor de un libro: `artists`/`people` del servidor o autor embebido
/// (creador del OPF / `Writer` de ComicInfo.xml).
String _authorOf(BaseItemDto item, Map<String, _EmbeddedMeta> embedded) {
  final server = _bookAuthorOf(item);
  if (server.isNotEmpty) return server;
  final id = item.id;
  if (id != null) return embedded[id]?.author.trim() ?? '';
  return '';
}

/// Primer género: del servidor o embebido (`subject` del OPF / `Genre` de
/// ComicInfo.xml).
String _genreOf(BaseItemDto item, Map<String, _EmbeddedMeta> embedded) {
  final genres = item.genres;
  if (genres != null) {
    for (final genre in genres) {
      final name = genre.trim();
      if (name.isNotEmpty) return name;
    }
  }
  final id = item.id;
  if (id != null) return embedded[id]?.genre.trim() ?? '';
  return '';
}

/// Autor de un libro según el servidor: `artists` y, si viene vacío,
/// `people` con tipo o rol de autor/escritor (en ES o EN).
String _bookAuthorOf(BaseItemDto item) {
  final artists = item.artists;
  if (artists != null) {
    for (final artist in artists) {
      final name = artist.trim();
      if (name.isNotEmpty) return name;
    }
  }
  final people = item.people;
  if (people != null) {
    for (final person in people) {
      if (person.type == PersonKind.author) {
        final name = person.name?.trim() ?? '';
        if (name.isNotEmpty) return name;
      }
    }
    for (final person in people) {
      final role = person.role?.trim().toLowerCase() ?? '';
      if (role == 'author' ||
          role == 'writer' ||
          role == 'autor' ||
          role == 'escritor') {
        final name = person.name?.trim() ?? '';
        if (name.isNotEmpty) return name;
      }
    }
  }
  return '';
}

/// Metadatos embebidos mínimos para agrupar (serie/autor/género).
class _EmbeddedMeta {
  const _EmbeddedMeta({this.series = '', this.author = '', this.genre = ''});

  final String series;
  final String author;
  final String genre;

  Map<String, String> toJson() => {'s': series, 'a': author, 'g': genre};

  static _EmbeddedMeta fromJson(Map<String, dynamic> json) => _EmbeddedMeta(
    series: (json['s'] as String?) ?? '',
    author: (json['a'] as String?) ?? '',
    genre: (json['g'] as String?) ?? '',
  );
}

/// Clave de `SharedPreferences` con los metadatos embebidos ya resueltos
/// (`itemId` → serie/autor/género, vacíos si el fichero no traía nada).
const _kEmbeddedMetaStorageKey = 'ereader.embeddedMeta.v1';

/// Máximo de ficheros a descargar por ejecución para resolver metadatos
/// embebidos. El resto queda pendiente hasta la próxima apertura (la caché
/// evita repetir descargas).
const _kEmbeddedResolveCap = 80;

/// Resuelve serie/autor/género embebidos solo para los libros que no traen
/// serie ni autor del servidor. EPUB → OPF (serie Calibre + creadores);
/// CBZ/CB7/CBT → ComicInfo.xml; CBR → ComicInfo.xml vía `another_rar`;
/// PDF y resto se omiten (sin estándar de serie). Todo con caché
/// persistente, en secuencia para no saturar al servidor.
Future<Map<String, _EmbeddedMeta>> _embeddedMetaForMissing(
  JellyfinDart client,
  List<BaseItemDto> all,
) async {
  final prefs = await SharedPreferences.getInstance();
  final result = <String, _EmbeddedMeta>{};
  try {
    final raw = prefs.getString(_kEmbeddedMetaStorageKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          result[entry.key] = _EmbeddedMeta.fromJson(value);
        }
      }
    }
  } catch (_) {}

  var resolved = 0;
  for (final item in all) {
    final id = item.id;
    if (id == null || id.isEmpty || result.containsKey(id)) continue;
    // Solo los que de verdad lo necesitan.
    if (_seriesOf(item, result).isNotEmpty) continue;
    if (_authorOf(item, result).isNotEmpty) continue;
    if (resolved >= _kEmbeddedResolveCap) break;
    final meta = await _readEmbeddedMeta(client, item);
    result[id] = meta;
    resolved++;
  }

  try {
    await prefs.setString(
      _kEmbeddedMetaStorageKey,
      jsonEncode({for (final e in result.entries) e.key: e.value.toJson()}),
    );
  } catch (_) {}
  if (resolved > 0) {
    debugPrint('[ereader] embedded meta: $resolved ficheros leídos');
  }
  return result;
}

/// Lee serie/autor/género del propio fichero. Devuelve meta vacía (y se
/// cachea) si el formato no aplica o falla la lectura.
Future<_EmbeddedMeta> _readEmbeddedMeta(
  JellyfinDart client,
  BaseItemDto item,
) async {
  const empty = _EmbeddedMeta();
  final id = item.id;
  if (id == null || id.isEmpty) return empty;
  final format = bookFormatOf(item);
  if (format != 'epub' &&
      format != 'cbz' &&
      format != 'cb7' &&
      format != 'cbt' &&
      format != 'cbr' &&
      format != 'rar') {
    return empty;
  }
  try {
    final res = await client.getLibraryApi().getFile(itemId: id);
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) return empty;
    if (format == 'epub') {
      final meta = parseEpubMetadata(bytes);
      if (meta == null) return empty;
      return _EmbeddedMeta(
        series: meta.series?.trim() ?? '',
        author: meta.authors.isNotEmpty ? meta.authors.first.trim() : '',
        genre: meta.subjects.isNotEmpty ? meta.subjects.first.trim() : '',
      );
    }
    final comic = format == 'cbr' || format == 'rar'
        ? await parseComicInfoFromRar(bytes)
        : parseComicInfoFromZip(bytes);
    if (comic == null) return empty;
    return _EmbeddedMeta(
      series: comic.series?.trim() ?? '',
      author: comic.authors.isNotEmpty ? comic.authors.first.trim() : '',
      genre: comic.genre?.trim() ?? '',
    );
  } catch (e) {
    debugPrint('[ereader] embedded meta failed for ${item.name}: $e');
    return empty;
  }
}

/// Libros/cómics recién añadidos a la biblioteca (para la fila superior).
final eReaderLatestBooksProvider = FutureProvider<List<BaseItemDto>>((
  ref,
) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null) return const [];
  final res = await client.getItemsApi().getItems(
    userId: userId,
    recursive: true,
    includeItemTypes: const [BaseItemKind.book],
    sortBy: const [ItemSortBy.dateCreated],
    sortOrder: const [SortOrder.descending],
    limit: 20,
    fields: const [
      ItemFields.dateCreated,
      ItemFields.overview,
      ItemFields.primaryImageAspectRatio,
    ],
    enableImageTypes: const [ImageType.primary],
  );
  return res.data?.items ?? [];
});

/// Args del grid paginado de todos los libros/cómics.
class EReaderBooksArgs {
  const EReaderBooksArgs({required this.pageIndex, this.sortAscending = true});
  final int pageIndex;
  final bool sortAscending;

  @override
  bool operator ==(Object other) =>
      other is EReaderBooksArgs &&
      other.pageIndex == pageIndex &&
      other.sortAscending == sortAscending;

  @override
  int get hashCode => Object.hash(pageIndex, sortAscending);
}

/// Página del grid con todos los libros/cómics (reutiliza el paginado genérico).
final eReaderBooksPageProvider =
    FutureProvider.family<List<BaseItemDto>, EReaderBooksArgs>((ref, args) {
      return ref.watch(
        libraryFilteredPageProvider(
          LibraryFilteredArgs(
            viewId: '',
            pageIndex: args.pageIndex,
            sortAscending: args.sortAscending,
            includeItemTypes: const [BaseItemKind.book],
          ),
        ).future,
      );
    });

/// Total de libros/cómics (para calcular el número de páginas).
final eReaderBooksCountProvider = FutureProvider<int>((ref) {
  return ref.watch(
    libraryFilteredCountProvider(
      const LibraryFilteredArgs(
        viewId: '',
        pageIndex: 0,
        includeItemTypes: [BaseItemKind.book],
      ),
    ).future,
  );
});

/// Información del fichero (nombre con extensión y tamaño) de un libro/cómic.
///
/// `MediaSources` trae `Size`/`Path` solo si se piden en `fields`, por eso se
/// consulta el item por id con esos campos. La llamada es DIO.
final bookFileInfoProvider = FutureProvider.family<BookFileInfo?, String>((
  ref,
  itemId,
) async {
  final client = ref.watch(jellyfinClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (client == null || userId == null || itemId.isEmpty) return null;
  try {
    final res = await client.getItemsApi().getItems(
      userId: userId,
      ids: [itemId],
      fields: const [ItemFields.mediaSources, ItemFields.path],
      limit: 1,
    );
    final items = res.data?.items ?? const <BaseItemDto>[];
    if (items.isEmpty) return null;
    return bookFileInfoOf(items.first);
  } catch (e) {
    debugPrint('[ereader] file info failed: $e');
    return null;
  }
});

/// Metadatos embebidos (OPF de Dublin Core) de un EPUB descargado de Jellyfin.
///
/// Jellyfin puede no tener poblados autor/editorial/ISBN si no ha refrescado
/// los metadatos del libro; en ese caso se leen directamente del fichero. La
/// llamada es DIO: el llamador debe mostrar el loader mientras carga.
final epubMetadataProvider = FutureProvider.family<BookMetadata?, String>((
  ref,
  itemId,
) async {
  final client = ref.watch(jellyfinClientProvider);
  if (client == null || itemId.isEmpty) return null;
  try {
    final res = await client.getLibraryApi().getFile(itemId: itemId);
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) return null;
    return parseEpubMetadata(bytes);
  } catch (e) {
    debugPrint('[ereader] epub metadata failed: $e');
    return null;
  }
});

/// Metadatos embebidos (`ComicInfo.xml`) de un cómic descargado de Jellyfin.
///
/// Como el OPF para EPUB: si al servidor le falta serie/autores, se leen del
/// propio fichero (CBZ/CB7/CBT por ZIP, CBR por `another_rar`). La llamada es
/// DIO: el llamador debe mostrar el loader mientras carga.
final comicMetadataProvider = FutureProvider.family<ComicMetadata?, String>((
  ref,
  itemId,
) async {
  final client = ref.watch(jellyfinClientProvider);
  if (client == null || itemId.isEmpty) return null;
  try {
    final res = await client.getLibraryApi().getFile(itemId: itemId);
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) return null;
    // El formato se decide por contenido: ZIP (PK) o RAR (Rar!).
    final isZip = bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    if (isZip) return parseComicInfoFromZip(bytes);
    return await parseComicInfoFromRar(bytes);
  } catch (e) {
    debugPrint('[ereader] comic metadata failed: $e');
    return null;
  }
});
