import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';

/// Categorías estilo Image1 - 4 columnas.
const kMovieCategories = [
  'Action',
  'Action & Adventure',
  'Adventure',
  'Animation',
  'Anime',
  'Children',
  'Comedy',
  'Crime',
  'Documentary',
  'Drama',
  'Family',
  'Fantasy',
  'Food',
  'Game Show',
  'History',
  'Home and Garden',
];

Future<String?> showCategoryDialog(
  BuildContext context, {
  String? selected,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.78),
    builder: (_) => CategoryDialog(selected: selected),
  );
}

class CategoryDialog extends StatefulWidget {
  const CategoryDialog({super.key, this.selected});
  final String? selected;
  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  late final FocusScopeNode _scope = FocusScopeNode();
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FocusScope(
      node: _scope,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1020),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Row(
                      children: [
                        const Icon(Icons.category_outlined, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(l10n.categories,
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                        _CloseButton(onPressed: () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        ActionChip(
                          label: Text(l10n.clearFilter),
                          onPressed: () => Navigator.of(context).pop(''),
                          backgroundColor: Colors.white10,
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        if (_selected != null && _selected!.isNotEmpty)
                          Chip(
                            label: Text(_selected!),
                            backgroundColor: const Color(0xFF2B7FFF),
                            labelStyle: const TextStyle(color: Colors.white),
                            deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                            onDeleted: () => setState(() => _selected = null),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.6,
                        ),
                        itemCount: kMovieCategories.length,
                        itemBuilder: (context, i) {
                          final cat = kMovieCategories[i];
                          final selected = _selected == cat;
                          return _CategoryTile(
                            label: cat,
                            selected: selected,
                            index: i,
                            onTap: () => Navigator.of(context).pop(cat),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('1 / 34', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
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

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({required this.label, required this.selected, required this.index, required this.onTap});
  final String label;
  final bool selected;
  final int index;
  final VoidCallback onTap;
  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _focused = false;
  static const _colors = [
    Color(0xFF6B4B6A),
    Color(0xFF3A5A40),
    Color(0xFFB07A3A),
    Color(0xFF5B6ABF),
    Color(0xFF4A2A3A),
    Color(0xFF2A4A3A),
    Color(0xFF8A3A5A),
    Color(0xFF3A3A5A),
    Color(0xFF5A3A2A),
    Color(0xFF3A5A6B),
    Color(0xFF4A5A8A),
    Color(0xFF2A5A6A),
    Color(0xFF5A4A3A),
    Color(0xFF3A6A5A),
    Color(0xFF6A3A4A),
    Color(0xFF4A6A6A),
  ];

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
    final baseColor = _colors[widget.index % _colors.length];
    final active = _focused || widget.selected;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.08),
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [BoxShadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 12)]
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagen de fondo sutil (placeholder con gradiente como Image1)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [baseColor.withValues(alpha: 0.9), Colors.black.withValues(alpha: 0.25)],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: active ? 15 : 14,
                      fontWeight: FontWeight.w700,
                      shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
                    ),
                  ),
                ),
              ),
              if (widget.selected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 12, color: Colors.black),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
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
            border: Border.all(color: _focused ? Colors.white : Colors.white24, width: _focused ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, size: 14, color: _focused ? Colors.black : Colors.white70),
              const SizedBox(width: 6),
              Text(l10n.closeEsc, style: TextStyle(color: _focused ? Colors.black : Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
