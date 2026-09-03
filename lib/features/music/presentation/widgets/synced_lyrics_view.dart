import 'package:flutter/material.dart';

import '../../data/lrclib_repository.dart';

class SyncedLyricsView extends StatefulWidget {
  const SyncedLyricsView({
    super.key,
    required this.result,
    required this.position,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  final LrcResult result;
  final Duration position;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  final ScrollController _controller = ScrollController();
  int _current = -1;

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncScroll();
  }

  void _syncScroll() {
    final lines = widget.result.syncedLines;
    if (lines == null || lines.isEmpty) return;
    int idx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (widget.position >= lines[i].time) idx = i;
    }
    if (idx != _current) {
      setState(() => _current = idx);
      if (idx >= 0 && _controller.hasClients) {
        // Cada línea ~28px de alto, centramos
        final offset = (idx * 28.0 - 120).clamp(0.0, _controller.position.maxScrollExtent);
        _controller.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result.isInstrumental) {
      return Center(
        child: Text('Instrumental', style: TextStyle(color: widget.textSecondary, fontSize: 16, fontStyle: FontStyle.italic)),
      );
    }
    final synced = widget.result.syncedLines;
    if (synced == null || synced.isEmpty) {
      // Plain sin highlight
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SelectableText(
          widget.result.plainLyrics,
          style: TextStyle(color: widget.textPrimary, fontSize: 14, height: 1.6),
        ),
      );
    }

    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: synced.length,
      itemBuilder: (context, i) {
        final line = synced[i];
        final active = i == _current;
        final past = i < _current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            line.text,
            style: TextStyle(
              color: active ? widget.accent : (past ? widget.textSecondary.withValues(alpha: 0.6) : widget.textPrimary.withValues(alpha: 0.85)),
              fontSize: active ? 16 : 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w400,
              height: 1.3,
            ),
          ),
        );
      },
    );
  }
}
