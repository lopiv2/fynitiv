import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'debug_device.dart';

/// Overlay D-pad draggable para simular mando TV (Android TV / webOS).
/// Se activa desde la barra "Simular dispositivo" y puede arrastrarse
/// por toda la pantalla para probar el movimiento con D-pad.
class DpadOverlay extends ConsumerStatefulWidget {
  const DpadOverlay({super.key});

  @override
  ConsumerState<DpadOverlay> createState() => _DpadOverlayState();
}

class _DpadOverlayState extends ConsumerState<DpadOverlay> {
  Offset _pos = const Offset(16, 120);
  bool _initialized = false;

  void _ensureInBounds(Size screen) {
    const w = 196.0;
    const h = 348.0;
    final dx = _pos.dx.clamp(
      0.0,
      (screen.width - w).clamp(0.0, double.infinity),
    );
    final dy = _pos.dy.clamp(
      0.0,
      (screen.height - h).clamp(0.0, double.infinity),
    );
    if (dx != _pos.dx || dy != _pos.dy) {
      _pos = Offset(dx, dy);
    }
  }

  int _keySeq = 0;

  bool _sendKey(LogicalKeyboardKey logical, PhysicalKeyboardKey physical) {
    // Timestamp monotónico pequeño (no epoch) para que FocusManager
    // distinga down/up y no lo descarte por tiempo futuro.
    final base = Duration(milliseconds: _keySeq++ * 100);
    final down = KeyDownEvent(
      logicalKey: logical,
      physicalKey: physical,
      timeStamp: base,
    );
    final up = KeyUpEvent(
      logicalKey: logical,
      physicalKey: physical,
      timeStamp: base + const Duration(milliseconds: 80),
    );
    final handledDown = HardwareKeyboard.instance.handleKeyEvent(down);
    Future.delayed(const Duration(milliseconds: 80), () {
      HardwareKeyboard.instance.handleKeyEvent(up);
    });
    return handledDown;
  }

  void _sendArrow(TraversalDirection dir) {
    final before = FocusManager.instance.primaryFocus;
    switch (dir) {
      case TraversalDirection.up:
        _sendKey(LogicalKeyboardKey.arrowUp, PhysicalKeyboardKey.arrowUp);
        break;
      case TraversalDirection.down:
        _sendKey(LogicalKeyboardKey.arrowDown, PhysicalKeyboardKey.arrowDown);
        break;
      case TraversalDirection.left:
        _sendKey(LogicalKeyboardKey.arrowLeft, PhysicalKeyboardKey.arrowLeft);
        break;
      case TraversalDirection.right:
        _sendKey(LogicalKeyboardKey.arrowRight, PhysicalKeyboardKey.arrowRight);
        break;
    }
    // Fallback si HardwareKeyboard no movió el foco (ej. primaryFocus null
    // o Shortcuts no encontró vecino). Si ya se movió, no hacer doble paso.
    Future.microtask(() {
      final after = FocusManager.instance.primaryFocus;
      if (after == before) {
        if (after == null) {
          // Sin foco previo (TV recién iniciado) → tomar el primer focable
          FocusManager.instance.rootScope.nextFocus();
        } else {
          final focus = after;
          final scope = focus.nearestScope ?? FocusManager.instance.rootScope;
          final moved = scope.focusInDirection(dir);
          if (!moved && focus.context != null) {
            Actions.maybeInvoke(focus.context!, DirectionalFocusIntent(dir));
          }
        }
      }
    });
  }

  void _sendEnter() {
    _sendKey(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
    // También probar con select / gameButtonA por compatibilidad AppHover
    Future.delayed(const Duration(milliseconds: 40), () {
      if (!mounted) return;
      _sendKey(LogicalKeyboardKey.select, PhysicalKeyboardKey.select);
    });
    Future.microtask(() {
      if (!mounted) return;
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (ctx != null) {
        // ignore: use_build_context_synchronously
        Actions.maybeInvoke(ctx, const ActivateIntent());
      }
    });
  }

  void _sendBack() {
    _sendKey(LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape);
    Future.delayed(const Duration(milliseconds: 40), () {
      if (!mounted) return;
      _sendKey(LogicalKeyboardKey.goBack, PhysicalKeyboardKey.browserBack);
    });
    Future.microtask(() {
      if (!mounted) return;
      final ctx = FocusManager.instance.primaryFocus?.context;
      if (ctx != null) {
        // ignore: use_build_context_synchronously
        if (Actions.maybeInvoke(ctx, const DismissIntent()) == false) {
          // ignore: use_build_context_synchronously
          if (Navigator.canPop(ctx)) Navigator.maybePop(ctx);
        }
      } else {
        // Sin contexto focal, intentar pop global
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        final nav = Navigator.of(context, rootNavigator: true);
        // ignore: use_build_context_synchronously
        if (nav.canPop()) nav.maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    if (!_initialized) {
      // Posición inicial: abajo-derecha por defecto, pero arrastrable.
      _pos = Offset(screen.width - 212, screen.height - 320);
      _ensureInBounds(screen);
      _initialized = true;
    }
    _ensureInBounds(screen);

    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: ExcludeFocus(
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 196,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1020).withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header arrastrable
                      GestureDetector(
                        onPanStart: (_) {},
                        onPanUpdate: (d) {
                          setState(() {
                            _pos += d.delta;
                            _ensureInBounds(screen);
                          });
                        },
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(18),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.open_with,
                                color: Colors.white54,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Mando D-pad',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => ref
                                    .read(debugDpadVisibleProvider.notifier)
                                    .setVisible(false),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // D-pad cross
                      _DpadCross(
                        onUp: () => _sendArrow(TraversalDirection.up),
                        onDown: () => _sendArrow(TraversalDirection.down),
                        onLeft: () => _sendArrow(TraversalDirection.left),
                        onRight: () => _sendArrow(TraversalDirection.right),
                        onOk: _sendEnter,
                      ),
                      const SizedBox(height: 30),
                      // Fila inferior Back / OK
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _PillButton(
                                icon: Icons.arrow_back,
                                label: 'Back',
                                onTap: _sendBack,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PillButton(
                                icon: Icons.keyboard_return,
                                label: 'OK',
                                onTap: _sendEnter,
                                primary: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DpadCross extends StatelessWidget {
  const _DpadCross({
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    required this.onOk,
  });

  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base cruz
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          // Up
          Positioned(
            top: 6,
            child: _ArrowBtn(icon: Icons.keyboard_arrow_up, onTap: onUp),
          ),
          // Left
          Positioned(
            left: 6,
            child: _ArrowBtn(icon: Icons.keyboard_arrow_left, onTap: onLeft),
          ),
          // Center OK
          _CenterOk(onTap: onOk),
          // Right
          Positioned(
            right: 6,
            child: _ArrowBtn(icon: Icons.keyboard_arrow_right, onTap: onRight),
          ),
          // Down
          Positioned(
            bottom: 6,
            child: _ArrowBtn(icon: Icons.keyboard_arrow_down, onTap: onDown),
          ),
        ],
      ),
    );
  }
}

class _ArrowBtn extends StatefulWidget {
  const _ArrowBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  State<_ArrowBtn> createState() => _ArrowBtnState();
}

class _ArrowBtnState extends State<_ArrowBtn> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _pressed ? Colors.white : const Color(0xFF1E2748),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _pressed
                ? Colors.white
                : Colors.white.withValues(alpha: 0.14),
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.18),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Icon(
          widget.icon,
          color: _pressed ? Colors.black : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _CenterOk extends StatefulWidget {
  const _CenterOk({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_CenterOk> createState() => _CenterOkState();
}

class _CenterOkState extends State<_CenterOk> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _pressed ? Colors.white : const Color(0xFF2B7FFF),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2B7FFF).withValues(alpha: 0.35),
              blurRadius: 14,
            ),
          ],
        ),
        child: Center(
          child: Text(
            'OK',
            style: TextStyle(
              color: _pressed ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: widget.primary
              ? (_pressed ? Colors.white : const Color(0xFF2B7FFF))
              : (_pressed
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 12,
              color: widget.primary && !_pressed
                  ? Colors.white
                  : (_pressed ? Colors.black : Colors.white70),
            ),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: TextStyle(
                color: widget.primary && !_pressed
                    ? Colors.white
                    : (_pressed ? Colors.black : Colors.white),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
