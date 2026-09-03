import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/library_providers.dart';

Future<void> showDesktopLibraryDialog(
  BuildContext context,
  List<BaseItemDto> views,
  String? activeViewId,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    barrierDismissible: true,
    builder: (_) =>
        DesktopLibraryDialog(views: views, activeViewId: activeViewId),
  );
}

class DesktopLibraryDialog extends ConsumerStatefulWidget {
  const DesktopLibraryDialog({
    super.key,
    required this.views,
    this.activeViewId,
  });
  final List<BaseItemDto> views;
  final String? activeViewId;
  @override
  ConsumerState<DesktopLibraryDialog> createState() =>
      _DesktopLibraryDialogState();
}

class _DesktopLibraryDialogState extends ConsumerState<DesktopLibraryDialog> {
  late final FocusScopeNode _scope = FocusScopeNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scope.requestFocus();
    });
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  IconData _viewIcon(BaseItemDto view) {
    switch (view.collectionType) {
      case CollectionType.movies:
        return Icons.movie_outlined;
      case CollectionType.tvshows:
        return Icons.tv_outlined;
      case CollectionType.music:
        return Icons.music_note_outlined;
      case CollectionType.books:
        return Icons.menu_book_outlined;
      case CollectionType.livetv:
        return Icons.live_tv_outlined;
      default:
        return Icons.video_library_outlined;
    }
  }

  void _open(String id) {
    Navigator.of(context).pop();
    if (id.isNotEmpty) context.go('/library/$id');
  }

  String _subtitleForCount(BaseItemDto v) {
    final l10n = AppLocalizations.of(context)!;
    final count = ref.watch(libraryItemCountProvider(v.id ?? '')).value ?? 0;
    final isGrab = (v.name ?? '').toLowerCase().contains('grabac');
    final hours = isGrab
        ? ref.watch(libraryDvrHoursProvider(v.id ?? '')).value
        : null;
    if (isGrab && hours != null && hours > 0)
      return l10n.libraryCountHours(hours);
    switch (v.collectionType) {
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
        final name = (v.name ?? '').toLowerCase();
        if (name.contains('grabac') && hours != null)
          return l10n.libraryCountHours(hours);
        if (name.contains('colecc')) return l10n.libraryCountCollections(count);
        return l10n.libraryCountItems(count);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Grid 3 columnas como [Image 1] para desktop también

    return FocusScope(
      node: _scope,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 620),
            decoration: BoxDecoration(
              color: const Color(0xFF232730).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    Row(
                      children: [
                        const Icon(
                          Icons.folder_outlined,
                          color: Color(0xFF7A8AA0),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'BIBLIOTECAS DE MEDIOS',
                          style: TextStyle(
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
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE2E5EA),
                              ),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 1.75,
                              ),
                          itemCount: widget.views.length,
                          itemBuilder: (context, i) {
                            final v = widget.views[i];
                            final selected = widget.activeViewId == v.id;
                            return _LibraryGridCard(
                              view: v,
                              icon: _viewIcon(v),
                              selected: selected,
                              subtitle: _subtitleForCount(v),
                              onTap: () => _open(v.id ?? ''),
                            );
                          },
                        ),
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

class _LibraryRow extends StatefulWidget {
  const _LibraryRow({
    required this.view,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final BaseItemDto view;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_LibraryRow> createState() => _LibraryRowState();
}

class _LibraryRowState extends State<_LibraryRow> {
  bool _hovered = false;
  bool _focused = false;
  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.select ||
        e.logicalKey == LogicalKeyboardKey.gameButtonA) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Focus(
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: _onKey,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFE8EAED) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active ? const Color(0xFF3B82F6) : Colors.transparent,
                  width: active ? 1 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: active
                        ? const Color(0xFF1A1E2A)
                        : const Color(0xFF6B7280),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.view.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFF1A1E2A)
                            : const Color(0xFF4B5563),
                        fontSize: 14,
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (widget.selected)
                    const Icon(Icons.check, color: Color(0xFF3B82F6), size: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryGridCard extends StatefulWidget {
  const _LibraryGridCard({
    required this.view,
    required this.icon,
    required this.selected,
    required this.subtitle,
    required this.onTap,
  });
  final BaseItemDto view;
  final IconData icon;
  final bool selected;
  final String subtitle;
  final VoidCallback onTap;
  @override
  State<_LibraryGridCard> createState() => _LibraryGridCardState();
}

class _LibraryGridCardState extends State<_LibraryGridCard> {
  bool _hovered = false;
  bool _focused = false;
  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.select ||
        e.logicalKey == LogicalKeyboardKey.gameButtonA) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _focused;
    const ledColor = Color(0xFF3B82F6);
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: _onKey,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
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
                  color: active
                      ? ledColor
                      : Colors.white.withValues(alpha: 0.06),
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
                      if (active)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'ENFOCADO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        )
                      else
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF9CA3AF),
                          size: 16,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    widget.view.name ?? '',
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
