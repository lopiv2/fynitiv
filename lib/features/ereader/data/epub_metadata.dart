import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Metadatos leídos del OPF interno de un EPUB (Dublin Core).
class BookMetadata {
  const BookMetadata({
    this.title,
    this.authors = const [],
    this.publisher,
    this.isbn,
    this.language,
    this.date,
    this.description,
    this.subjects = const [],
  });

  final String? title;
  final List<String> authors;
  final String? publisher;
  final String? isbn;
  final String? language;
  final String? date;
  final String? description;
  final List<String> subjects;

  bool get isEmpty =>
      (title == null || title!.isEmpty) &&
      authors.isEmpty &&
      (publisher == null || publisher!.isEmpty) &&
      (isbn == null || isbn!.isEmpty) &&
      (language == null || language!.isEmpty) &&
      (date == null || date!.isEmpty) &&
      (description == null || description!.isEmpty) &&
      subjects.isEmpty;
}

/// Extrae los metadatos del OPF de un EPUB a partir de sus bytes.
/// Devuelve `null` si no es un EPUB válido o no se puede leer el OPF.
BookMetadata? parseEpubMetadata(List<int> bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final opf = _readOpf(archive);
    if (opf == null) return null;
    final doc = XmlDocument.parse(opf);
    final metadata = doc.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'metadata')
        .firstOrNull;
    final scope = metadata ?? doc.rootElement;

    String? single(String name) {
      for (final el in scope.descendants.whereType<XmlElement>()) {
        if (el.name.local.toLowerCase() == name) {
          final text = el.innerText.trim();
          if (text.isNotEmpty) return text;
        }
      }
      return null;
    }

    List<String> many(String name) {
      final out = <String>[];
      for (final el in scope.descendants.whereType<XmlElement>()) {
        if (el.name.local.toLowerCase() == name) {
          final text = el.innerText.trim();
          if (text.isNotEmpty && !out.contains(text)) out.add(text);
        }
      }
      return out;
    }

    final identifiers = many('identifier');
    final isbn = identifiers
        .map(_normalizeIsbn)
        .whereType<String>()
        .firstOrNull;

    return BookMetadata(
      title: single('title'),
      authors: [...many('creator'), ...many('contributor')],
      publisher: single('publisher'),
      isbn: isbn,
      language: single('language'),
      date: single('date'),
      description: single('description'),
      subjects: many('subject'),
    );
  } catch (_) {
    return null;
  }
}

String? _readOpf(Archive archive) {
  String? containerXml;
  for (final f in archive.files) {
    if (f.isFile && f.name.toLowerCase() == 'meta-inf/container.xml') {
      containerXml = utf8.decode(f.content, allowMalformed: true);
      break;
    }
  }
  String? opfPath;
  if (containerXml != null) {
    try {
      final doc = XmlDocument.parse(containerXml);
      for (final el in doc.descendants.whereType<XmlElement>()) {
        if (el.name.local == 'rootfile') {
          opfPath = el.getAttribute('full-path');
          break;
        }
      }
    } catch (_) {}
  }
  if (opfPath != null) {
    final normalized = opfPath.replaceAll('\\', '/').toLowerCase();
    for (final f in archive.files) {
      if (f.isFile && f.name.toLowerCase() == normalized) {
        return utf8.decode(f.content, allowMalformed: true);
      }
    }
  }
  // Fallback: primer .opf del contenedor.
  for (final f in archive.files) {
    if (f.isFile && f.name.toLowerCase().endsWith('.opf')) {
      return utf8.decode(f.content, allowMalformed: true);
    }
  }
  return null;
}

String? _normalizeIsbn(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9Xx]'), '');
  if (cleaned.length == 13 && RegExp(r'^(97[89])\d{9}$').hasMatch(cleaned)) {
    return cleaned;
  }
  if (cleaned.length == 10 && RegExp(r'^\d{9}[\dXx]$').hasMatch(cleaned)) {
    return cleaned.toUpperCase();
  }
  return null;
}
