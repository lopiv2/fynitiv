import 'dart:convert';
import 'dart:io';

import 'package:another_rar/rar_reader.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

/// Metadatos leídos del `ComicInfo.xml` interno de un cómic
/// (CBZ/CB7/CBT/CBR). Es lo que permite agrupar sagas aunque el servidor no
/// traiga `SeriesName`.
class ComicMetadata {
  const ComicMetadata({
    this.series,
    this.number,
    this.authors = const [],
    this.genre,
    this.publisher,
  });

  final String? series;
  final String? number;
  final List<String> authors;
  final String? genre;
  final String? publisher;

  bool get isEmpty =>
      (series == null || series!.isEmpty) &&
      authors.isEmpty &&
      (genre == null || genre!.isEmpty) &&
      (publisher == null || publisher!.isEmpty);
}

/// Parsea un `ComicInfo.xml` ya leído. Autor = `Writer` (varios separados por
/// `,`/`;`) con fallback a dibujantes si no hay escritor.
ComicMetadata? parseComicInfoXml(String xmlText) {
  try {
    final doc = XmlDocument.parse(xmlText);
    final root = doc.rootElement;

    String? textOf(String tag) {
      final wanted = tag.toLowerCase();
      for (final el in root.descendants.whereType<XmlElement>()) {
        if (el.name.local.toLowerCase() == wanted) {
          final text = el.innerText.trim();
          if (text.isNotEmpty) return text;
        }
      }
      return null;
    }

    List<String> splitNames(String? raw) {
      if (raw == null || raw.trim().isEmpty) return const [];
      return raw
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    var authors = splitNames(textOf('Writer'));
    if (authors.isEmpty) {
      // Sin escritor declarado: primer dibujante disponible.
      for (final tag in [
        'Penciller',
        'Inker',
        'Colorist',
        'Letterer',
        'CoverArtist',
        'Artist',
      ]) {
        authors = splitNames(textOf(tag));
        if (authors.isNotEmpty) break;
      }
    }

    return ComicMetadata(
      series: textOf('Series'),
      number: textOf('Number'),
      authors: authors,
      genre: textOf('Genre'),
      publisher: textOf('Publisher'),
    );
  } catch (_) {
    return null;
  }
}

/// Busca y parsea el `ComicInfo.xml` de un cómic basado en ZIP
/// (CBZ/CB7/CBT) a partir de sus bytes.
ComicMetadata? parseComicInfoFromZip(List<int> bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final f in archive.files) {
      if (f.isFile && p.basename(f.name).toLowerCase() == 'comicinfo.xml') {
        return parseComicInfoXml(utf8.decode(f.content, allowMalformed: true));
      }
    }
  } catch (_) {}
  return null;
}

/// Busca y parsea el `ComicInfo.xml` de un CBR (RAR) a partir de sus bytes.
///
/// `another_rar` solo abre desde fichero, así que se vuelca a un temporal que
/// se borra al terminar. Como en el lector: RAR5 comprimidos o con filtros
/// RarVM no se pueden leer y devuelven `null`.
Future<ComicMetadata?> parseComicInfoFromRar(List<int> bytes) async {
  File? tmp;
  try {
    final dir = await getTemporaryDirectory();
    tmp = File(
      p.join(
        dir.path,
        'fynitiv_comicinfo_${DateTime.now().microsecondsSinceEpoch}.cbr',
      ),
    );
    await tmp.writeAsBytes(bytes, flush: true);
    final rar = await RarArchiveReader.open(tmp.path);
    final entries = await rar.getArchiveEntries();
    for (final e in entries) {
      if (!e.isDirectory &&
          p.basename(e.name).toLowerCase() == 'comicinfo.xml') {
        final data = await rar.extractEntry(entry: e);
        if (data.isEmpty) return null;
        return parseComicInfoXml(utf8.decode(data, allowMalformed: true));
      }
    }
  } catch (_) {
    return null;
  } finally {
    try {
      if (tmp != null && await tmp.exists()) await tmp.delete();
    } catch (_) {}
  }
  return null;
}
