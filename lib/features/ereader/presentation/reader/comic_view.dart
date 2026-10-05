import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Visor básico de cómics CBZ: descomprime el zip, ordena las imágenes de
/// forma natural y las muestra en un `PageView` con zoom.
class ComicView extends StatefulWidget {
  const ComicView({super.key, required this.file});

  final File file;

  @override
  State<ComicView> createState() => _ComicViewState();
}

class _ComicViewState extends State<ComicView> {
  final PageController _controller = PageController();
  List<Uint8List> _pages = const [];
  bool _loading = true;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final entries = archive.files
          .where((f) => f.isFile && _isImage(f.name))
          .toList()
        ..sort((a, b) => _naturalCompare(a.name, b.name));
      final pages = entries
          .map((e) => e.content as List<int>)
          .map(Uint8List.fromList)
          .toList();
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_pages.isEmpty) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: _pages.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
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
        Positioned(
          right: 16,
          bottom: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                '${_index + 1}/${_pages.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
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
