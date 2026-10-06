import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:path/path.dart' as p;

const Set<String> _knownBookFormats = {
  'pdf',
  'epub',
  'cbz',
  'cb7',
  'cbt',
  'cbr',
};

/// Formato de un libro/cómic a partir de `Container` o de la extensión de la
/// ruta del fichero (la extensión gana cuando el container no es conocido).
String bookFormatOf(BaseItemDto item) {
  final container = (item.container ?? '')
      .trim()
      .toLowerCase()
      .replaceFirst('.', '');
  final ext = p.extension(item.path ?? '').replaceFirst('.', '').toLowerCase();
  if (_knownBookFormats.contains(container)) return container;
  if (_knownBookFormats.contains(ext)) return ext;
  return container.isNotEmpty ? container : ext;
}

/// Información del fichero de un libro/cómic: nombre con extensión y tamaño.
class BookFileInfo {
  const BookFileInfo({this.fileName, this.sizeBytes});

  final String? fileName;
  final int? sizeBytes;
}

/// Deriva el nombre y el tamaño del fichero desde `MediaSources`/`Path`.
/// `MediaSources` (con `Size` y `Path`) solo llega si se pide en los `fields`.
BookFileInfo bookFileInfoOf(BaseItemDto item) {
  String? rawPath = item.path;
  int? size;
  for (final source in item.mediaSources ?? const <MediaSourceInfo>[]) {
    final sourceSize = source.size;
    if (size == null && sourceSize != null && sourceSize > 0) {
      size = sourceSize;
    }
    final sourcePath = source.path;
    if ((rawPath == null || rawPath.trim().isEmpty) &&
        sourcePath != null &&
        sourcePath.trim().isNotEmpty) {
      rawPath = sourcePath;
    }
  }
  String? fileName;
  if (rawPath != null && rawPath.trim().isNotEmpty) {
    fileName = p.basename(rawPath.replaceAll('\\', '/'));
  } else {
    final name = (item.name ?? '').trim();
    if (name.isNotEmpty) {
      final format = bookFormatOf(item);
      fileName = format.isEmpty ? name : '$name.$format';
    }
  }
  return BookFileInfo(fileName: fileName, sizeBytes: size);
}

