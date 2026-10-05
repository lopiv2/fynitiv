import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../core/widgets/app_loader.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../library/application/library_providers.dart';
import 'comic_view.dart';
import 'epub_view.dart';

/// Lector básico de libros/cómics: descarga el fichero de Jellyfin y lo muestra
/// según su formato (PDF, EPUB, CBZ). CBR pendiente.
class BookReaderScreen extends ConsumerStatefulWidget {
  const BookReaderScreen({super.key, required this.item});

  final BaseItemDto item;

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  File? _file;
  String _format = '';
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _format = _formatOf(widget.item);
    _load();
  }

  static String _formatOf(BaseItemDto item) {
    final container = (item.container ?? '').trim().toLowerCase();
    if (container.isNotEmpty) return container;
    final path = item.path ?? '';
    return p.extension(path).replaceFirst('.', '').toLowerCase();
  }

  Future<void> _load() async {
    final client = ref.read(jellyfinClientProvider);
    final id = widget.item.id;
    if (client == null || id == null || id.isEmpty) {
      setState(() => _error = true);
      return;
    }
    try {
      final res = await client.getLibraryApi().getFile(itemId: id);
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) setState(() => _error = true);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'fynitiv_reader_$id.$_format'));
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() => _file = file);
    } catch (e) {
      debugPrint('[BookReader] load failed: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context)!;
    if (_error) {
      return Center(
        child: Text(l10n.eReaderUnsupported, style: const TextStyle(color: Colors.white70)),
      );
    }
    final file = _file;
    if (file == null) return const Center(child: AppLoader());
    switch (_format) {
      case 'pdf':
        return PdfViewer.file(file.path);
      case 'epub':
        return EpubView(file: file);
      case 'cbz':
        return ComicView(file: file);
      default:
        return Center(
          child: Text(
            l10n.eReaderUnsupported,
            style: const TextStyle(color: Colors.white70),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: l10n.back,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Text(
                    widget.item.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }
}
