import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';

/// Ancho mínimo a partir del cual el lector muestra dos páginas enfrentadas.
const double kReaderTwoUpBreakpoint = 900;

/// Separación horizontal entre las dos páginas de un pliego.
const double kReaderSpreadGap = 16;

/// Margen interior de cada página del lector.
const EdgeInsets kReaderPagePadding = EdgeInsets.symmetric(
  horizontal: 28,
  vertical: 20,
);

/// Tamaño disponible para una sola página del lector dado el área total.
///
/// En modo a una página ocupa todo el ancho; en modo doble página se reparte el
/// ancho menos la separación entre ambas. Lo usan los visores que necesitan
/// paginar su contenido (EPUB) para calcular cuánto cabe por página.
Size readerPageSize(Size available, {required bool twoUp}) {
  final width = twoUp
      ? (available.width - kReaderSpreadGap) / 2
      : available.width;
  return Size(width, available.height);
}

/// Lector paginado genérico tipo libro.
///
/// Muestra las páginas de [pageBuilder] en un `PageView`. En pantallas anchas
/// (>= [kReaderTwoUpBreakpoint]) presenta dos páginas enfrentadas (izquierda y
/// derecha) y en estrechas una sola. Incluye flechas laterales para avanzar y
/// retroceder, contador de páginas y soporte de teclado/D-pad (flechas).
class SpreadReader extends StatefulWidget {
  const SpreadReader({
    super.key,
    required this.pageCount,
    required this.pageBuilder,
    this.initialIndex = 0,
    this.onIndexChanged,
  });

  /// Número total de páginas lógicas (no de pliegos).
  final int pageCount;

  /// Construye el contenido de una página lógica por índice.
  final Widget Function(BuildContext context, int index) pageBuilder;

  /// Índice inicial (paso del pliego, no página lógica).
  final int initialIndex;

  /// Notifica el primer índice de página visible tras cada cambio.
  final ValueChanged<int>? onIndexChanged;

  @override
  State<SpreadReader> createState() => _SpreadReaderState();
}

class _SpreadReaderState extends State<SpreadReader> {
  late final PageController _controller;
  int _step = 0;
  bool _twoUp = false;

  int _stepsFor(bool twoUp) =>
      twoUp ? (widget.pageCount / 2).ceil() : widget.pageCount;

  int get _firstPage => _twoUp ? _step * 2 : _step;

  @override
  void initState() {
    super.initState();
    _step = widget.initialIndex >= 0 ? widget.initialIndex : 0;
    _controller = PageController(initialPage: _step);
  }

  @override
  void didUpdateWidget(SpreadReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageCount != oldWidget.pageCount) {
      final steps = _stepsFor(_twoUp);
      if (_step >= steps) {
        _step = steps > 0 ? steps - 1 : 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.hasClients) {
            _controller.jumpToPage(_step);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int step, int steps) {
    final target = step < 0 ? 0 : (step >= steps ? steps - 1 : step);
    if (target == _step) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoUp = constraints.maxWidth >= kReaderTwoUpBreakpoint;
        final steps = _stepsFor(twoUp);
        if (_twoUp != twoUp) {
          final logical = _twoUp ? _step * 2 : _step;
          _twoUp = twoUp;
          final rawStep = twoUp ? logical ~/ 2 : logical;
          final newStep = rawStep >= steps ? steps - 1 : rawStep;
          if (newStep != _step) {
            _step = newStep;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _controller.hasClients) {
                _controller.jumpToPage(newStep);
              }
            });
          }
        }

        return ScrollConfiguration(
          behavior: const _ReaderScrollBehavior(),
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                  _goTo(_step - 1, steps),
              const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                  _goTo(_step + 1, steps),
            },
            child: Focus(
              autofocus: true,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: steps,
                    onPageChanged: (i) {
                      setState(() => _step = i);
                      widget.onIndexChanged?.call(_firstPage);
                    },
                    itemBuilder: (context, i) =>
                        _buildSpread(context, i, twoUp),
                  ),
                  _arrow(
                    alignment: Alignment.centerLeft,
                    icon: Icons.chevron_left,
                    tooltip: l10n.eReaderPreviousPage,
                    enabled: _step > 0,
                    onTap: () => _goTo(_step - 1, steps),
                  ),
                  _arrow(
                    alignment: Alignment.centerRight,
                    icon: Icons.chevron_right,
                    tooltip: l10n.eReaderNextPage,
                    enabled: _step < steps - 1,
                    onTap: () => _goTo(_step + 1, steps),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            _counter(l10n),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpread(BuildContext context, int i, bool twoUp) {
    if (!twoUp) {
      return widget.pageBuilder(context, i);
    }
    final left = i * 2;
    final right = left + 1;
    return Row(
      children: [
        Expanded(
          child: left < widget.pageCount
              ? widget.pageBuilder(context, left)
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: kReaderSpreadGap),
        Expanded(
          child: right < widget.pageCount
              ? widget.pageBuilder(context, right)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _arrow({
    required Alignment alignment,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Opacity(
          opacity: enabled ? 1 : 0,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: tooltip,
                onPressed: onTap,
                icon: Icon(icon, color: Colors.white, size: 30),
                focusColor: Colors.white24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _counter(AppLocalizations l10n) {
    if (!_twoUp) return l10n.pageOf(_step + 1, widget.pageCount);
    final left = _step * 2 + 1;
    final rawRight = _step * 2 + 2;
    final right = rawRight > widget.pageCount ? widget.pageCount : rawRight;
    final label = left == right ? '$left' : '$left-$right';
    return l10n.pageOf(label, widget.pageCount);
  }
}

/// Sin barras de scroll en el lector: el pliego se navega con flechas o swipe.
class _ReaderScrollBehavior extends ScrollBehavior {
  const _ReaderScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
