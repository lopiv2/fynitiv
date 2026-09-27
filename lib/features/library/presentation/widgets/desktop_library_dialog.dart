import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import 'library_grid_card.dart';

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

  void _open(String id) {
    Navigator.of(context).pop();
    if (id.isNotEmpty) context.go('/library/$id');
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
                            return LibraryGridCard(
                              view: v,
                              selected: selected,
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
