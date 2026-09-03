import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/library_providers.dart';

/// Config visual para cada tipo de biblioteca – estilo claro como [Image 1].
/// Color de icono se ignora en tema claro (usa gris neutro), se mantiene por compat.
class _TvLibraryVisual {
  const _TvLibraryVisual(this.color, this.icon);
  final Color color;
  final IconData icon;
}

_TvLibraryVisual _visualFor(BaseItemDto view) {
  switch (view.collectionType) {
    case CollectionType.movies:
      return const _TvLibraryVisual(Color(0xFFE8EAED), Icons.movie_outlined);
    case CollectionType.tvshows:
      return const _TvLibraryVisual(Color(0xFFE8EAED), Icons.tv_outlined);
    case CollectionType.music:
      return const _TvLibraryVisual(
        Color(0xFFE8EAED),
        Icons.music_note_outlined,
      );
    case CollectionType.livetv:
      return const _TvLibraryVisual(Color(0xFFE8EAED), Icons.live_tv_outlined);
    case CollectionType.books:
      return const _TvLibraryVisual(
        Color(0xFFE8EAED),
        Icons.menu_book_outlined,
      );
    case CollectionType.boxsets:
      return const _TvLibraryVisual(Color(0xFFE8EAED), Icons.folder_outlined);
    case CollectionType.playlists:
      return const _TvLibraryVisual(
        Color(0xFFE8EAED),
        Icons.queue_music_outlined,
      );
    default:
      final name = (view.name ?? '').toLowerCase();
      if (name.contains('pel'))
        return const _TvLibraryVisual(Color(0xFFE8EAED), Icons.movie_outlined);
      if (name.contains('serie'))
        return const _TvLibraryVisual(Color(0xFFE8EAED), Icons.tv_outlined);
      if (name.contains('music') ||
          name.contains('música') ||
          name.contains('álbum')) {
        return const _TvLibraryVisual(
          Color(0xFFE8EAED),
          Icons.music_note_outlined,
        );
      }
      if (name.contains('direct') ||
          name.contains('live') ||
          name.contains('canal')) {
        return const _TvLibraryVisual(
          Color(0xFFE8EAED),
          Icons.live_tv_outlined,
        );
      }
      if (name.contains('grabac'))
        return const _TvLibraryVisual(Color(0xFFE8EAED), Icons.circle_outlined);
      if (name.contains('colecc'))
        return const _TvLibraryVisual(Color(0xFFE8EAED), Icons.folder_outlined);
      return const _TvLibraryVisual(
        Color(0xFFE8EAED),
        Icons.video_library_outlined,
      );
  }
}

String _realSubtitleFor(
  BaseItemDto view,
  int count,
  int? hours,
  AppLocalizations l10n,
) {
  // Horas para DVR
  final name = (view.name ?? '').toLowerCase();
  if (name.contains('grabac') && hours != null && hours > 0) {
    return l10n.libraryCountHours(hours);
  }
  switch (view.collectionType) {
    case CollectionType.movies:
      return l10n.libraryCountTitles(count);
    case CollectionType.tvshows:
      return l10n.libraryCountSeries(count);
    case CollectionType.music:
      return l10n.libraryCountSongs(count);
    case CollectionType.livetv:
      return l10n.libraryCountChannels(count);
    case CollectionType.books:
      return l10n.libraryCountFiles(count);
    case CollectionType.playlists:
      return l10n.libraryCountLists(count);
    case CollectionType.boxsets:
      return l10n.libraryCountCollections(count);
    default:
      if (name.contains('grabac') && hours != null)
        return l10n.libraryCountHours(hours);
      if (name.contains('colecc')) return l10n.libraryCountCollections(count);
      if (name.contains('direct')) return l10n.libraryCountChannels(count);
      if (name.contains('lista')) return l10n.libraryCountLists(count);
      if (name.contains('libro')) return l10n.libraryCountFiles(count);
      return l10n.libraryCountItems(count);
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
    barrierColor: Colors.black.withValues(alpha: 0.45),
    barrierDismissible: true,
    useRootNavigator: true,
    builder: (ctx) => TvLibraryModal(views: views, activeViewId: activeViewId),
  );
}

class TvLibraryModal extends ConsumerStatefulWidget {
  const TvLibraryModal({
    super.key,
    required this.views,
    required this.activeViewId,
  });

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
        final target =
            _cardNodes[_focusedIndex.clamp(0, _cardNodes.length - 1)];
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
              color: const Color(0xFF1E222E).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: const Color(0xFF232730),
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header como [Image 1]: izquierda BIBLIOTECAS DE MEDIOS, derecha Jellyfin Server
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.folder_outlined,
                          color: Color(0xFF7A8AA0),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.mediaLibraries.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF7A8AA0),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Jellyfin Server',
                          style: TextStyle(
                            color: Color(0xFF7A8AA0),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _CloseButton(
                          focusNode: _closeNode,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Grid
                    Expanded(
                      child: views.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noResults,
                                style: const TextStyle(
                                  color: Color(0xFF7A8AA0),
                                ),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                // 3 columnas como [Image 1], 2 en estrecho.
                                final w = constraints.maxWidth;
                                int crossAxisCount = 3;
                                if (w < 700) {
                                  crossAxisCount = 2;
                                }
                                return GridView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 14,
                                        childAspectRatio: 1.95,
                                      ),
                                  itemCount: views.length,
                                  itemBuilder: (context, index) {
                                    final v = views[index];
                                    final isFocused = _focusedIndex == index;
                                    final visual = _visualFor(v);
                                    final countAsync = ref.watch(
                                      libraryItemCountProvider(v.id ?? ''),
                                    );
                                    final isGrab = (v.name ?? '')
                                        .toLowerCase()
                                        .contains('grabac');
                                    final hoursAsync = isGrab
                                        ? ref.watch(
                                            libraryDvrHoursProvider(v.id ?? ''),
                                          )
                                        : null;
                                    final count = countAsync.value ?? 0;
                                    final subtitle =
                                        countAsync.isLoading && count == 0
                                        ? '…'
                                        : _realSubtitleFor(
                                            v,
                                            count,
                                            hoursAsync?.value,
                                            l10n,
                                          );
                                    final displaySubtitle = subtitle;
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFF1A1E2A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focused
                  ? const Color(0xFF1A1E2A)
                  : const Color(0xFFE2E5EA),
              width: 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.close,
            size: 14,
            color: _focused ? Colors.white : const Color(0xFF6B7280),
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
    // Estilo con LED único (como Juego online pero un solo color) para TV y escritorio.
    final active = _focused || widget.isFocused;
    const ledColor = Color(0xFF3B82F6);

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
        child: AnimatedScale(
          scale: active ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF1E2633)
                  : const Color(0xFF2A2E3A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active ? ledColor : Colors.white.withValues(alpha: 0.06),
                width: active ? 1.8 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: ledColor.withValues(alpha: 0.58),
                        blurRadius: 22,
                        spreadRadius: 2,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: ledColor.withValues(alpha: 0.20),
                        blurRadius: 44,
                        spreadRadius: 5,
                        offset: const Offset(0, 18),
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
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E4352),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                      const Spacer(),
                      if (!active)
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF9CA3AF),
                          size: 16,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
