import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/app_loader.dart';
import 'spread_reader.dart';

/// Visor de cómics CBZ: descomprime el zip, ordena las imágenes de forma
/// natural y las muestra en un lector paginado a doble página con flechas.
class ComicView extends StatefulWidget {
  const ComicView({super.key, required this.file});

  final File file;

  @override
  State<ComicView> createState() => _ComicViewState();
}

class _ComicViewState extends State<ComicView> {
  List<Uint8List> _pages = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final entries =
          archive.files.where((f) => f.isFile && _isImage(f.name)).toList()
            ..sort((a, b) => _naturalCompare(a.name, b.name));
      final pages = entries.map((e) => e.content).toList();
      if (!mounted) return;
      setState(() {
        _pages = pages;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ComicView] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  static bool _isImage(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif') ||
        n.endsWith('.bmp');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: AppLoader());
    }
    if (_pages.isEmpty) {
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
            child: Image.memory(
              _pages[i],
              fit: BoxFit.contain,
              gaplessPlayback: true,
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
