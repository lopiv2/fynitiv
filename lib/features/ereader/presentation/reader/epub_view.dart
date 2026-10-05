import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

/// Visor EPUB básico: descomprime el `.epub`, lee el OPF (spine) y renderiza
/// los capítulos como una lista de bloques (títulos, párrafos e imágenes).
class EpubView extends StatefulWidget {
  const EpubView({super.key, required this.file});

  final File file;

  @override
  State<EpubView> createState() => _EpubViewState();
}

class _EpubViewState extends State<EpubView> {
  List<Widget> _blocks = const [];
  bool _loading = true;
  bool _error = false;

  static const _blockTags = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'blockquote',
    'figcaption',
    'dt',
    'dd',
    'td',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory(
        p.join(tmp.path, 'fynitiv_epub_${widget.file.path.hashCode}'),
      );
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);

      final archive = ZipDecoder().decodeBytes(await widget.file.readAsBytes());
      for (final f in archive.files) {
        if (!f.isFile || f.name.isEmpty) continue;
        final out = File(p.join(dir.path, f.name));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(f.content as List<int>);
      }

      final opfRel = _opfPath(dir);
      if (opfRel == null) throw StateError('OPF no encontrado');
      final opf = XmlDocument.parse(
        await File(p.join(dir.path, opfRel)).readAsString(),
      );
      final opfDir = p.dirname(opfRel);

      final manifest = <String, String>{};
      for (final item in opf.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id != null && href != null) manifest[id] = href;
      }
      final spine = <String>[];
      for (final ref in opf.findAllElements('itemref')) {
        final idref = ref.getAttribute('idref');
        if (idref != null && manifest.containsKey(idref)) {
          spine.add(manifest[idref]!);
        }
      }

      final blocks = <Widget>[];
      for (final href in spine) {
        final rel = p.normalize(p.join(opfDir, href));
        final f = File(p.join(dir.path, rel));
        if (!await f.exists()) continue;
        final doc = html_parser.parse(await f.readAsString());
        final body = doc.body;
        if (body != null) _walk(body, rel, dir.path, blocks);
        blocks.add(const SizedBox(height: 24));
      }

      if (!mounted) return;
      setState(() {
        _blocks = blocks;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[EpubView] error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  String? _opfPath(Directory root) {
    final container = File(p.join(root.path, 'META-INF', 'container.xml'));
    if (!container.existsSync()) return null;
    final xml = XmlDocument.parse(container.readAsStringSync());
    final rootfiles = xml.findAllElements('rootfile');
    final rootfile = rootfiles.isEmpty ? null : rootfiles.first;
    return rootfile?.getAttribute('full-path');
  }

  void _walk(dom.Element el, String chapterRel, String root, List<Widget> out) {
    for (final node in el.children) {
      final tag = node.localName?.toLowerCase() ?? '';
      if (tag == 'script' || tag == 'style' || tag == 'head') continue;
      if (tag == 'img') {
        final w = _image(node, chapterRel, root);
        if (w != null) out.add(w);
        continue;
      }
      final hasImg = node.querySelector('img') != null;
      if (_blockTags.contains(tag)) {
        if (hasImg) {
          for (final img in node.querySelectorAll('img')) {
            final w = _image(img, chapterRel, root);
            if (w != null) out.add(w);
          }
        }
        final text = _norm(node.text);
        if (text.isNotEmpty) out.add(_textBlock(tag, text));
      } else if (node.children.isEmpty) {
        final text = _norm(node.text);
        if (text.isNotEmpty) out.add(_paragraph(text));
      } else {
        _walk(node, chapterRel, root, out);
      }
    }
  }

  Widget? _image(dom.Element img, String chapterRel, String root) {
    final src = img.attributes['src'];
    if (src == null || src.isEmpty || src.startsWith('data:')) return null;
    try {
      if (src.startsWith('http')) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Image.network(
            src,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        );
      }
      final rel = p.normalize(p.join(p.dirname(chapterRel), src));
      final file = File(p.join(root, rel));
      if (!file.existsSync()) return null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Widget _textBlock(String tag, String text) {
    if (tag == 'li') {
      return Padding(
        padding: const EdgeInsets.only(left: 12, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  ', style: TextStyle(color: Colors.white70)),
            Expanded(child: _paragraph(text)),
          ],
        ),
      );
    }
    final level = int.tryParse(tag.replaceFirst('h', '')) ?? 0;
    if (level > 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: switch (level) {
              1 => 26,
              2 => 22,
              3 => 19,
              4 => 17,
              5 => 15,
              _ => 14,
            },
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return _paragraph(text);
  }

  Widget _paragraph(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
    ),
  );

  String _norm(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error || _blocks.isEmpty) {
      return const Center(
        child: Icon(Icons.menu_book_outlined, color: Colors.white38, size: 48),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: _blocks,
    );
  }
}
