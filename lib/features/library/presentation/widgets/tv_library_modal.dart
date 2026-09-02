import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';

/// Config visual para cada tipo de biblioteca (color + icono) – coincide con [Image 1].
class _TvLibraryVisual {
  const _TvLibraryVisual(this.color, this.icon);
  final Color color;
  final IconData icon;
}

_TvLibraryVisual _visualFor(BaseItemDto view) {
  switch (view.collectionType) {
    case CollectionType.movies:
      return const _TvLibraryVisual(Color(0xFF3B82F6), Icons.movie_outlined);
    case CollectionType.tvshows:
      return const _TvLibraryVisual(Color(0xFF8B5CF6), Icons.live_tv_outlined);
    case CollectionType.music:
      return const _TvLibraryVisual(Color(0xFFEC4899), Icons.music_note_outlined);
    case CollectionType.livetv:
      return const _TvLibraryVisual(Color(0xFF22C55E), Icons.live_tv_outlined);
    case CollectionType.books:
      return const _TvLibraryVisual(Color(0xFFD97706), Icons.menu_book_outlined);
    case CollectionType.boxsets:
      return const _TvLibraryVisual(Color(0xFF06B6D4), Icons.collections_bookmark_outlined);
    case CollectionType.playlists:
      return const _TvLibraryVisual(Color(0xFFEF4444), Icons.queue_music_outlined);
    default:
      final name = (view.name ?? '').toLowerCase();
      if (name.contains('pel')) return const _TvLibraryVisual(Color(0xFF3B82F6), Icons.movie_outlined);
      if (name.contains('serie')) return const _TvLibraryVisual(Color(0xFF8B5CF6), Icons.tv_outlined);
      if (name.contains('music') || name.contains('música') || name.contains('álbum')) {
        return const _TvLibraryVisual(Color(0xFFEC4899), Icons.music_note_outlined);
      }
      if (name.contains('direct') || name.contains('live') || name.contains('canal')) {
        return const _TvLibraryVisual(Color(0xFF22C55E), Icons.live_tv_outlined);
      }
      return const _TvLibraryVisual(Color(0xFF6366F1), Icons.video_library_outlined);
  }
}

String _subtitleFor(BuildContext context, BaseItemDto view) {
  final l10n = AppLocalizations.of(context);
  switch (view.collectionType) {
    case CollectionType.movies:
      return '1,420 títulos';
    case CollectionType.tvshows:
      return '380 series';
    case CollectionType.music:
      return '12,450 canciones';
    case CollectionType.livetv:
      return '64 canales';
    default:
      // Fallback genérico; si l10n no existe, usar vacío.
      return l10n != null ? '' : '';
  }
}

/// Abre el modal fullscreen de selección de bibliotecas para mando D-pad.
Future<void> showTvLibraryModal(
  BuildContext context,
  List<BaseItemDto> views,
  String? activeViewId,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    barrierDismissible: true,
    useRootNavigator: true,
    builder: (ctx) => TvLibraryModal(views: views, activeViewId: activeViewId),
  );
}

class TvLibraryModal extends ConsumerStatefulWidget {
  const TvLibraryModal({super.key, required this.views, required this.activeViewId});

  final List<BaseItemDto> views;
  final String? activeViewId;

  @override
  ConsumerState<TvLibraryModal> createState() => _TvLibraryModalState();
}

class _TvLibraryModalState extends ConsumerState<TvLibraryModal> {
  late final FocusScopeNode _scopeNode;
  late final FocusNode _closeNode;
  late final List<FocusNode> _cardNodes;
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _scopeNode = FocusScopeNode(debugLabel: 'tvLibraryScope');
    _closeNode = FocusNode(debugLabel: 'tvLibraryClose');
    // Índice inicial: la biblioteca activa si existe.
    final idx = widget.views.indexWhere((v) => v.id == widget.activeViewId);
    _focusedIndex = idx >= 0 ? idx : 0;
    _cardNodes = List.generate(
      widget.views.length,
      (i) => FocusNode(debugLabel: 'tvLibraryCard_$i'),
    );
    // Foco inicial al primer elemento (no al diálogo) para que las flechas
    // funcionen inmediatamente en escritorio/TV con teclado/mando.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_cardNodes.isNotEmpty) {
        final target = _cardNodes[_focusedIndex.clamp(0, _cardNodes.length - 1)];
        // Asegura que el scope tenga foco y luego el card.
        _scopeNode.requestFocus();
        target.requestFocus();
      } else {
        _closeNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final n in _cardNodes) {
      n.dispose();
    }
    _closeNode.dispose();
    _scopeNode.dispose();
    super.dispose();
  }

  KeyEventResult _onDialogKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.browserBack) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openLibrary(String id) {
    Navigator.of(context).pop();
    if (id.isNotEmpty) context.go('/library/$id');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final views = widget.views;

    return FocusScope(
      node: _scopeNode,
      autofocus: true,
      onKeyEvent: _onDialogKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1020),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF121A36), Color(0xFF0B1020)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2568),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: const Icon(Icons.library_books_outlined, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.mediaLibraries,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.selectCollectionWithDPad,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _CloseButton(
                          focusNode: _closeNode,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // Grid
                    Expanded(
                      child: views.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noResults,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                // 4 columnas en ancho TV, 2 en estrecho.
                                final w = constraints.maxWidth;
                                int crossAxisCount = 4;
                                if (w < 700) {
                                  crossAxisCount = 2;
                                } else if (w < 900) {
                                  crossAxisCount = 3;
                                }
                                return GridView.builder(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.55,
                                  ),
                                  itemCount: views.length,
                                  itemBuilder: (context, index) {
                                    final v = views[index];
                                    final isFocused = _focusedIndex == index;
                                    final visual = _visualFor(v);
                                    final subtitle = _subtitleFor(context, v);
                                    // Si hay subtítulo genérico vacío, usar tipo colección.
                                    final displaySubtitle = subtitle.isNotEmpty
                                        ? subtitle
                                        : (v.collectionType?.name ?? '');
                                    return _TvLibraryCard(
                                      focusNode: _cardNodes[index],
                                      title: v.name ?? '',
                                      subtitle: displaySubtitle,
                                      icon: visual.icon,
                                      color: visual.color,
                                      isFocused: isFocused,
                                      autofocus: index == _focusedIndex,
                                      onFocusChange: (focused) {
                                        if (focused && _focusedIndex != index) {
                                          setState(() => _focusedIndex = index);
                                        }
                                      },
                                      onTap: () => _openLibrary(v.id ?? ''),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onPressed, this.focusNode});
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _focused ? Colors.white : const Color(0xFF1E2748),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused ? Colors.white : Colors.white.withValues(alpha: 0.14),
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.18),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, size: 14, color: _focused ? Colors.black : Colors.white70),
              const SizedBox(width: 6),
              Text(
                l10n.closeEsc,
                style: TextStyle(
                  color: _focused ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvLibraryCard extends StatefulWidget {
  const _TvLibraryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isFocused,
    required this.autofocus,
    required this.onFocusChange,
    required this.onTap,
    this.focusNode,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isFocused;
  final bool autofocus;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  @override
  State<_TvLibraryCard> createState() => _TvLibraryCardState();
}

class _TvLibraryCardState extends State<_TvLibraryCard> {
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // El foco visual combina _focused (foco real del FocusNode) y isFocused (selección lógica).
    // Para que izquierda/derecha/arriba/abajo nunca pierda el borde, ambos pintan igual.
    final active = _focused || widget.isFocused;

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (v) {
        setState(() => _focused = v);
        widget.onFocusChange(v);
      },
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1A2340) : const Color(0xFF12182B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? const Color(0xFF7C86FF) : Colors.white.withValues(alpha: 0.08),
              width: active ? 2.2 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C86FF).withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: widget.color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(widget.icon, color: Colors.white, size: 22),
                        ),
                        const Spacer(),
                        if (active)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              l10n.focusedLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Escala sutil cuando está enfocado (hover TV)
              if (active)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
