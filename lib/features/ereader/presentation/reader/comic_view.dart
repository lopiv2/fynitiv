import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:another_rar/rar_reader.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/widgets/app_loader.dart';
import '../../../../l10n/app_localizations.dart';
import 'spread_reader.dart';

/// Visor de cómics CBZ (ZIP) y CBR (RAR): extrae las imágenes a un directorio
/// temporal, las ordena de forma natural y las muestra en un lector paginado a
/// doble página con flechas.
///
/// Las páginas se pintan con `Image.file` para no mantener todas las imágenes
/// descomprimidas en memoria (los cómics pueden pesar cientos de MB).
class ComicView extends StatefulWidget {
  const ComicView({super.key, required this.file});

  final File file;

  @override
  State<ComicView> createState() => _ComicViewState();
}

class _ComicViewState extends State<ComicView> {
  List<File> _pages = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory(
        p.join(tmp.path, 'fynitiv_comic_${widget.file.path.hashCode}'),
      );
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);

      final ext = p.extension(widget.file.path).toLowerCase();
      final isRar = ext == '.cbr' || ext == '.rar';
      final pages = isRar
          ? await _extractRar(widget.file.path, dir.path)
          : await _extractZip(widget.file.path, dir.path);

      if (!mounted) return;
      setState(() {
        _pages = pages;
        _loading = false;
        _error = pages.isEmpty;
      });
      if (pages.isEmpty) {
        unawaited(
          EasyLoading.showError(
            AppLocalizations.of(context)!.eReaderUnsupported,
            duration: const Duration(seconds: 2),
            maskType: EasyLoadingMaskType.none,
            dismissOnTap: true,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[ComicView] error: $e\n$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  /// Extrae las imágenes de un CBZ (ZIP) por streaming, sin cargar el archivo
  /// completo ni todas las páginas en memoria.
  static Future<List<File>> _extractZip(String path, String outDir) async {
    final input = InputFileStream(path);
    try {
      final archive = ZipDecoder().decodeStream(input);
      var entries = archive.files
          .where((f) => f.isFile && _isImageName(f.name))
          .toList();
      if (entries.isEmpty) {
        entries = archive.files.where((f) => f.isFile && _zipLooksLikeImage(f)).toList();
      }
      entries.sort((a, b) => _naturalCompare(a.name, b.name));

      final pages = <File>[];
      for (var i = 0; i < entries.length; i++) {
        final out = File(p.join(outDir, '${i.toString().padLeft(5, '0')}.img'));
        try {
          final output = OutputFileStream(out.path);
          entries[i].writeContent(output);
          output.closeSync();
        } catch (e) {
          debugPrint('[ComicView] entry ${entries[i].name} failed: $e');
          if (out.existsSync()) out.deleteSync();
          continue;
        }
        pages.add(out);
      }
      return pages;
    } finally {
      input.closeSync();
    }
  }

  static bool _zipLooksLikeImage(ArchiveFile file) {
    try {
      final bytes = file.readBytes();
      return bytes != null && _looksLikeImageBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  /// Extrae las imágenes de un CBR (RAR) en un isolate para no bloquear la UI.
  ///
  /// Usa `another_rar` (Dart puro): descomprime RAR4 (store/normal). Los CBR con
  /// filtros RarVM o RAR5-comprimidos no se pueden descomprimir y quedarán sin
  /// páginas (se avisa al usuario).
  static Future<List<File>> _extractRar(String path, String outDir) async {
    final paths = await Isolate.run(() async {
      final rar = await RarArchiveReader.open(path);
      final entries = await rar.getArchiveEntries();

      var images = entries
          .where((e) => !e.isDirectory && _isImageName(e.name))
          .toList();
      if (images.isEmpty) {
        // Sin extensiones fiables: detectar por firma de los bytes extraídos.
        final sniffed = <RarArchiveEntry>[];
        for (final e in entries.where((e) => !e.isDirectory)) {
          try {
            final bytes = await rar.extractEntry(entry: e);
            if (_looksLikeImageBytes(bytes)) sniffed.add(e);
          } catch (_) {}
        }
        images = sniffed;
      }
      images.sort((a, b) => _naturalCompare(a.name, b.name));

      final out = <String>[];
      var i = 0;
      for (final e in images) {
        try {
          final bytes = await rar.extractEntry(entry: e);
          if (bytes.isEmpty) continue;
          final f = File(p.join(outDir, '${i.toString().padLeft(5, '0')}.img'));
          await f.writeAsBytes(bytes, flush: false);
          out.add(f.path);
          i++;
        } catch (err) {
          debugPrint('[ComicView] rar entry ${e.name} failed: $err');
        }
      }
      return out;
    });
    return paths.map(File.new).toList();
  }

  static bool _isImageName(String name) {
    final n = name.toLowerCase();
    if (n.contains('__macosx/')) return false;
    return n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.jfif') ||
        n.endsWith('.png') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif') ||
        n.endsWith('.bmp') ||
        n.endsWith('.tif') ||
        n.endsWith('.tiff') ||
        n.endsWith('.avif') ||
        n.endsWith('.jxl');
  }

  /// Detecta el tipo de imagen por su firma (magic bytes) cuando la extensión
  /// no es fiable.
  static bool _looksLikeImageBytes(List<int> b) {
    if (b.length < 12) return false;
    // JPEG
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    // PNG
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return true;
    }
    // GIF
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return true;
    // BMP
    if (b[0] == 0x42 && b[1] == 0x4D) return true;
    // WEBP (RIFF....WEBP)
    if (b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return true;
    }
    // ISO-BMFF (AVIF/HEIC): ....ftyp
    if (b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: AppLoader());
    }
    if (_error || _pages.isEmpty) {
      return const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
      );
    }
    return SpreadReader(
      pageCount: _pages.length,
      pageBuilder: (context, i) => Padding(
        padding: kReaderPagePadding,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.file(
              _pages[i],
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white38,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compara nombres ordenando los números de forma natural (2 < 10).
int _naturalCompare(String a, String b) {
  final ra = _chunks(a);
  final rb = _chunks(b);
  final n = ra.length < rb.length ? ra.length : rb.length;
  for (var i = 0; i < n; i++) {
    final x = ra[i];
    final y = rb[i];
    final xn = int.tryParse(x);
    final yn = int.tryParse(y);
    if (xn != null && yn != null) {
      final c = xn.compareTo(yn);
      if (c != 0) return c;
    } else {
      final c = x.compareTo(y);
      if (c != 0) return c;
    }
  }
  return ra.length.compareTo(rb.length);
}

List<String> _chunks(String s) => RegExp(
  r'\d+|\D+',
).allMatches(s.toLowerCase()).map((m) => m.group(0)!).toList();
