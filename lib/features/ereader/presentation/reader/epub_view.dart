import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../../../../core/widgets/app_loader.dart';
import 'spread_reader.dart';

/// Visor EPUB: descomprime el `.epub`, lee el OPF (spine) y convierte cada
/// capítulo en bloques. Los bloques se reparten en páginas que caben en la
/// pantalla y se muestran en el [SpreadReader] a doble página con flechas.
class EpubView extends StatefulWidget {
  const EpubView({super.key, required this.file});

  final File file;

  @override
  State<EpubView> createState() => _EpubViewState();
}

class _EpubViewState extends State<EpubView> {
  List<_Block> _blocks = const [];
  bool _loading = true;
  bool _error = false;

  Size? _cacheSize;
  double _cacheScale = -1;
  List<List<_Block>>? _cachePages;

  static const _bodyStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    height: 1.5,
  );

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
        await out.writeAsBytes(f.content);
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

      final blocks = <_Block>[];
      for (final href in spine) {
        final rel = p.normalize(p.join(opfDir, href));
        final f = File(p.join(dir.path, rel));
        if (!await f.exists()) continue;
        final doc = html_parser.parse(await f.readAsString());
        final body = doc.body;
        if (body != null) await _walk(body, rel, dir.path, blocks);
        blocks.add(const _SpacerBlock(24));
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

  Future<void> _walk(
    dom.Element el,
    String chapterRel,
    String root,
    List<_Block> out,
  ) async {
    for (final node in el.children) {
      final tag = node.localName?.toLowerCase() ?? '';
      if (tag == 'script' || tag == 'style' || tag == 'head') continue;
      if (tag == 'img') {
        final w = await _imageBlock(node, chapterRel, root);
        if (w != null) out.add(w);
        continue;
      }
      if (_blockTags.contains(tag)) {
        for (final img in node.querySelectorAll('img')) {
          final w = await _imageBlock(img, chapterRel, root);
          if (w != null) out.add(w);
        }
        final text = _norm(node.text);
        if (text.isNotEmpty) out.add(_textBlockFor(tag, text));
      } else if (node.children.isEmpty) {
        final text = _norm(node.text);
        if (text.isNotEmpty) out.add(_paragraphBlock(text));
      } else {
        await _walk(node, chapterRel, root, out);
      }
    }
  }

  Future<_Block?> _imageBlock(
    dom.Element img,
    String chapterRel,
    String root,
  ) async {
    final src = img.attributes['src'];
    if (src == null || src.isEmpty || src.startsWith('data:')) return null;
    try {
      if (src.startsWith('http')) {
        return _ImageBlock(image: NetworkImage(src), aspectRatio: 3 / 4);
      }
      final rel = p.normalize(p.join(p.dirname(chapterRel), src));
      final file = File(p.join(root, rel));
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      final ratio = await _aspectRatio(bytes) ?? 3 / 4;
      return _ImageBlock(image: MemoryImage(bytes), aspectRatio: ratio);
    } catch (_) {
      return null;
    }
  }

  Future<double?> _aspectRatio(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final ratio = frame.image.width / frame.image.height;
      frame.image.dispose();
      codec.dispose();
      return ratio;
    } catch (_) {
      return null;
    }
  }

  _Block _textBlockFor(String tag, String text) {
    if (tag == 'li') {
      return _TextBlock(
        text: '•  $text',
        style: _bodyStyle,
        topGap: 2,
        bottomGap: 6,
        indent: 14,
      );
    }
    final level = int.tryParse(tag.replaceFirst('h', '')) ?? 0;
    if (level > 0) {
      return _TextBlock(
        text: text,
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
          height: 1.25,
        ),
        topGap: 16,
        bottomGap: 8,
      );
    }
    return _paragraphBlock(text);
  }

  _TextBlock _paragraphBlock(String text) =>
      _TextBlock(text: text, style: _bodyStyle, bottomGap: 10);

  String _norm(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

  List<List<_Block>> _pagesFor(Size size, TextScaler scaler, TextStyle base) {
    final scale = scaler.scale(1);
    final cached = _cachePages;
    if (cached != null && _cacheSize == size && _cacheScale == scale) {
      return cached;
    }
    final pages = _paginate(_blocks, size, scaler, base);
    _cacheSize = size;
    _cacheScale = scale;
    _cachePages = pages;
    return pages;
  }

  List<List<_Block>> _paginate(
    List<_Block> blocks,
    Size size,
    TextScaler scaler,
    TextStyle base,
  ) {
    final pages = <List<_Block>>[];
    var current = <_Block>[];
    var used = 0.0;

    void flush() {
      if (current.isEmpty) return;
      pages.add(current);
      current = <_Block>[];
      used = 0;
    }

    for (final block in blocks) {
      if (block is _SpacerBlock) {
        if (current.isNotEmpty && used + block.height > size.height) flush();
        current.add(block);
        used += block.height;
        if (used >= size.height - 0.5) flush();
        continue;
      }
      if (block is _ImageBlock) {
        var h = size.width / block.aspectRatio;
        if (h > size.height) h = size.height;
        if (current.isNotEmpty && used + h > size.height) flush();
        current.add(block);
        used += h + 16;
        if (used >= size.height - 0.5) flush();
        continue;
      }
      if (block is _TextBlock) {
        var remaining = block.text;
        var first = true;
        while (remaining.isNotEmpty) {
          final topGap = first ? block.topGap : 0.0;
          var avail = size.height - used - topGap;
          if (avail < 1) {
            if (current.isNotEmpty) {
              flush();
              continue;
            }
            avail = size.height;
          }
          final textWidth = size.width - block.indent;
          final painter = _measure(
            remaining,
            base.merge(block.style),
            textWidth < 1 ? 1 : textWidth,
            scaler,
          );
          if (painter.height <= avail) {
            current.add(
              first
                  ? block
                  : _TextBlock(
                      text: remaining,
                      style: block.style,
                      bottomGap: block.bottomGap,
                      indent: block.indent,
                    ),
            );
            used += topGap + painter.height + block.bottomGap;
            remaining = '';
            continue;
          }
          var cut = _lineBreak(painter, avail, remaining.length);
          if (cut <= 0) {
            if (current.isNotEmpty) {
              flush();
              continue;
            }
            // Página vacía y ni una línea cabe: usar toda la altura.
            cut = _lineBreak(painter, size.height, remaining.length);
          }
          if (cut <= 0) {
            // Caso degenerado (página más pequeña que una línea): no bloquear.
            cut = remaining.length;
          }
          final head = remaining.substring(0, cut).trimRight();
          final tail = remaining.substring(cut).trimLeft();
          if (head.isEmpty) {
            flush();
            continue;
          }
          current.add(
            _TextBlock(
              text: head,
              style: block.style,
              topGap: topGap,
              bottomGap: 0,
              indent: block.indent,
            ),
          );
          remaining = tail;
          first = false;
          flush();
        }
      }
    }
    flush();
    return pages;
  }

  TextPainter _measure(
    String text,
    TextStyle style,
    double maxWidth,
    TextScaler scaler,
  ) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
  }

  int _lineBreak(TextPainter painter, double avail, int maxChars) {
    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) return maxChars;
    var bottom = 0.0;
    var lastHeight = 0.0;
    for (final m in metrics) {
      if (bottom + m.height > avail) break;
      bottom += m.height;
      lastHeight = m.height;
    }
    if (lastHeight == 0) return 0;
    final y = bottom - lastHeight / 2;
    final cut = painter.getPositionForOffset(Offset(painter.width, y)).offset;
    if (cut <= 0) return 0;
    if (cut >= maxChars) return maxChars;
    return cut;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: AppLoader());
    if (_error || _blocks.isEmpty) {
      return const Center(
        child: Icon(Icons.menu_book_outlined, color: Colors.white38, size: 48),
      );
    }
    final scaler = MediaQuery.textScalerOf(context);
    final base = DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = Size(constraints.maxWidth, constraints.maxHeight);
        final twoUp = constraints.maxWidth >= kReaderTwoUpBreakpoint;
        final page = readerPageSize(available, twoUp: twoUp);
        final contentW = page.width - kReaderPagePadding.horizontal;
        final contentH = page.height - kReaderPagePadding.vertical;
        final content = Size(
          contentW < 1 ? 1 : contentW,
          contentH < 1 ? 1 : contentH,
        );
        final pages = _pagesFor(content, scaler, base);
        return SpreadReader(
          pageCount: pages.length,
          pageBuilder: (context, i) => Padding(
            padding: kReaderPagePadding,
            child: _PageColumn(blocks: pages[i], maxHeight: content.height),
          ),
        );
      },
    );
  }
}

sealed class _Block {
  const _Block();
}

class _TextBlock extends _Block {
  const _TextBlock({
    required this.text,
    required this.style,
    this.topGap = 0,
    this.bottomGap = 10,
    this.indent = 0,
  });

  final String text;
  final TextStyle style;
  final double topGap;
  final double bottomGap;
  final double indent;
}

class _ImageBlock extends _Block {
  const _ImageBlock({required this.image, required this.aspectRatio});

  final ImageProvider image;
  final double aspectRatio;
}

class _SpacerBlock extends _Block {
  const _SpacerBlock(this.height);

  final double height;
}

class _PageColumn extends StatelessWidget {
  const _PageColumn({required this.blocks, required this.maxHeight});

  final List<_Block> blocks;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final b in blocks) _blockWidget(context, b)],
        ),
      ),
    );
  }

  Widget _blockWidget(BuildContext context, _Block block) {
    if (block is _TextBlock) {
      return Padding(
        padding: EdgeInsets.only(
          top: block.topGap,
          bottom: block.bottomGap,
          left: block.indent,
        ),
        child: Text(
          block.text,
          style: DefaultTextStyle.of(context).style.merge(block.style),
        ),
      );
    }
    if (block is _ImageBlock) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Image(
            image: block.image,
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
          ),
        ),
      );
    }
    if (block is _SpacerBlock) {
      return SizedBox(height: block.height);
    }
    return const SizedBox.shrink();
  }
}
