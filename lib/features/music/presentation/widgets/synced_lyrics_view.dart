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
    // Diferir para no hacer setState durante el build del parent (causaba !_dirty)
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScroll());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScroll());
  }

  void _syncScroll() {
    if (!mounted) return;
    final lines = widget.result.syncedLines;
    if (lines == null || lines.isEmpty) return;
    int idx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (widget.position >= lines[i].time) idx = i;
    }
    if (idx != _current) {
      setState(() => _current = idx);
      if (idx >= 0 && _controller.hasClients) {
        // Cada línea ~32px de alto, centramos suave (550ms para seguir beat sin tirón)
        final offset = (idx * 32.0 - 120).clamp(0.0, _controller.position.maxScrollExtent);
        _controller.animateTo(offset, duration: const Duration(milliseconds: 550), curve: Curves.easeInOutCubic);
      } else if (idx >= 0) {
        // Si aún no hay clientes, reintentar en el próximo frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_controller.hasClients) return;
          final off = (idx * 32.0 - 120).clamp(0.0, _controller.position.maxScrollExtent);
          _controller.animateTo(off, duration: const Duration(milliseconds: 550), curve: Curves.easeInOutCubic);
        });
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
      // Plain sin highlight — con scrollbar
      return Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        thickness: 4,
        radius: const Radius.circular(8),
        child: SingleChildScrollView(
          controller: _controller,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SelectableText(
            widget.result.plainLyrics,
            style: TextStyle(color: widget.textPrimary, fontSize: 14, height: 1.6),
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      thickness: 4,
      radius: const Radius.circular(8),
      child: ListView.builder(
        controller: _controller,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        itemCount: synced.length,
        itemBuilder: (context, i) {
          final line = synced[i];
          final active = i == _current;
          final past = i < _current;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _LyricLine(
              text: line.text,
              active: active,
              past: past,
              textPrimary: widget.textPrimary,
              textSecondary: widget.textSecondary,
              accent: widget.accent,
            ),
          );
        },
      ),
    );
  }
}

/// Línea con transición degradada suave entre color base y resaltado.
/// Usa [TweenAnimationBuilder] + [ShaderMask] para barrido gradient left→right.
class _LyricLine extends StatelessWidget {
  const _LyricLine({
    required this.text,
    required this.active,
    required this.past,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  final String text;
  final bool active;
  final bool past;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Past / future sin animación: colores estáticos.
    if (!active) {
      final color = past
          ? textSecondary.withValues(alpha: 0.52)
          : textPrimary.withValues(alpha: 0.85);
      return AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeInOutCubic,
        style: TextStyle(
          color: color,
          fontSize: past ? 13 : 13.5,
          fontWeight: past ? FontWeight.w400 : FontWeight.w500,
          height: 1.35,
        ),
        child: Text(text),
      );
    }

    // Activa: barrido degradado 650ms textPrimary → accent con gradiente 40% ancho.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      builder: (context, progress, _) {
        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
          child: ShaderMask(
            shaderCallback: (bounds) {
              // Degradado que barre de izquierda a derecha.
              // progress 0 = todo base, 1 = todo accent.
              final p = progress.clamp(0.0, 1.0);
              // Suavizado: zona de mezcla 0.40 del ancho.
              const blend = 0.40;
              final start = (p - blend / 2).clamp(0.0, 1.0);
              final end = (p + blend / 2).clamp(0.0, 1.0);
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [accent, accent, textPrimary.withValues(alpha: 0.85)],
                stops: [0.0, start, end],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcIn,
            child: Text(text),
          ),
        );
      },
    );
  }
}
