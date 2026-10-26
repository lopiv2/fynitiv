import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:real_page_flip/real_page_flip.dart';

import '../../../../core/settings/reader_page_flip_controller.dart';
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

/// Color de fondo del lector, usado también como reverso del papel en el
/// efecto de pasar hoja.
const Color kReaderPaperBackColor = Color(0xFF0B0B0F);

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
/// Muestra las páginas de [pageBuilder]. En pantallas anchas
/// (>= [kReaderTwoUpBreakpoint]) presenta dos páginas enfrentadas (izquierda y
/// derecha) y en estrechas una sola. Incluye flechas laterales para avanzar y
/// retroceder, contador de páginas y soporte de teclado/D-pad (flechas).
///
/// Cuando la preferencia `readerPageFlipEnabledProvider` está activa, el paso
/// de página usa una animación realista de hoja curvándose (`real_page_flip`);
/// desactivada, se comporta como un `PageView` deslizante.
class SpreadReader extends ConsumerStatefulWidget {
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
  ConsumerState<SpreadReader> createState() => _SpreadReaderState();
}

class _SpreadReaderState extends ConsumerState<SpreadReader> {
  PageController? _pager;
  final PageFlipController _flip = PageFlipController();
  int _step = 0;
  bool _twoUp = false;
  bool _flipEnabled = true;

  int _stepsFor(bool twoUp) =>
      twoUp ? (widget.pageCount / 2).ceil() : widget.pageCount;

  int get _firstPage => _twoUp ? _step * 2 : _step;

  PageController _ensurePager() =>
      _pager ??= PageController(initialPage: _step);

  @override
  void initState() {
    super.initState();
    _step = widget.initialIndex >= 0 ? widget.initialIndex : 0;
  }

  @override
  void didUpdateWidget(SpreadReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El motor de curl gestiona por sí solo los cambios de número de páginas;
    // el PageView hay que recolocarlo a mano.
    if (widget.pageCount != oldWidget.pageCount && !_flipEnabled) {
      final steps = _stepsFor(_twoUp);
      if (_step >= steps) {
        _step = steps > 0 ? steps - 1 : 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final pager = _pager;
          if (mounted && pager != null && pager.hasClients) {
            pager.jumpToPage(_step);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  void _goTo(int step, int steps, {required bool flip}) {
    if (flip) {
      if (step > _step) {
        _flip.nextPage();
      } else if (step < _step) {
        _flip.previousPage();
      }
      return;
    }
    final target = step < 0 ? 0 : (step >= steps ? steps - 1 : step);
    if (target == _step) return;
    _pager?.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _flipEnabled = ref.watch(readerPageFlipEnabledProvider).value ?? true;
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
            if (!_flipEnabled) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final pager = _pager;
                if (mounted && pager != null && pager.hasClients) {
                  pager.jumpToPage(newStep);
                }
              });
            }
          }
        }

        // Si pasamos al modo curl, el PageController deja de usarse.
        if (_flipEnabled && _pager != null) {
          final old = _pager!;
          _pager = null;
          WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
        }

        final pager = (_flipEnabled && steps > 0)
            ? _buildFlip(context, twoUp, steps, l10n)
            : _buildPlain(context, twoUp, steps);

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _goTo(_step - 1, steps, flip: _flipEnabled),
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _goTo(_step + 1, steps, flip: _flipEnabled),
          },
          child: Focus(
            autofocus: true,
            child: Stack(
              children: [
                pager,
                _arrow(
                  alignment: Alignment.centerLeft,
                  icon: Icons.chevron_left,
                  tooltip: l10n.eReaderPreviousPage,
                  enabled: _step > 0,
                  onTap: () => _goTo(_step - 1, steps, flip: _flipEnabled),
                ),
                _arrow(
                  alignment: Alignment.centerRight,
                  icon: Icons.chevron_right,
                  tooltip: l10n.eReaderNextPage,
                  enabled: _step < steps - 1,
                  onTap: () => _goTo(_step + 1, steps, flip: _flipEnabled),
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
        );
      },
    );
  }

  Widget _buildPlain(BuildContext context, bool twoUp, int steps) {
    return ScrollConfiguration(
      behavior: const _ReaderScrollBehavior(),
      child: PageView.builder(
        controller: _ensurePager(),
        itemCount: steps,
        onPageChanged: (i) {
          setState(() => _step = i);
          widget.onIndexChanged?.call(_firstPage);
        },
        itemBuilder: (context, i) => _buildSpread(context, i, twoUp),
      ),
    );
  }

  Widget _buildFlip(
    BuildContext context,
    bool twoUp,
    int steps,
    AppLocalizations l10n,
  ) {
    return PageFlipWidget(
      controller: _flip,
      itemCount: steps,
      initialIndex: _step,
      spreadMode: twoUp
          ? PageFlipSpreadMode.doubleSpread
          : PageFlipSpreadMode.single,
      config: PageFlipConfig(
        enableSound: false,
        enableHaptics: false,
        // Los giros programáticos (flechas/D-pad) deben animarse con el curl.
        skipTapAnimation: false,
        backgroundColor: kReaderPaperBackColor,
        semanticBuilder: (page, total) => l10n.pageOf(page, total),
        edgeTapPreviousLabel: l10n.eReaderPreviousPage,
        edgeTapNextLabel: l10n.eReaderNextPage,
      ),
      onPageChanged: (i) {
        setState(() => _step = i);
        widget.onIndexChanged?.call(_firstPage);
      },
      itemBuilder: (context, i) => _buildSpread(context, i, twoUp),
    );
  }

  Widget _buildSpread(BuildContext context, int i, bool twoUp) {
    if (!twoUp) {
      if (i < 0 || i >= widget.pageCount) return const SizedBox.shrink();
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
