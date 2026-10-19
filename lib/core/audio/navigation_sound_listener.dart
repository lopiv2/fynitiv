import 'package:flutter/gestures.dart' show HitTestResult, PointerHoverEvent;
import 'package:flutter/rendering.dart'
    show RenderSemanticsGestureHandler, RendererBinding, SemanticsConfiguration;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/button_sounds.dart';
import '../settings/button_sound_controller.dart';
import 'hover_sound_player.dart';

/// Hace sonar el tono configurado en Ajustes > Sonidos cada vez que cambia el
/// foco (teclado/D-pad) o el ratón entra en un elemento interactivo, en
/// cualquier pantalla de la app.
///
/// Se monta una sola vez en `MaterialApp.builder` (por encima del Navigator),
/// por lo que cubre rutas, diálogos y menús. El foco se observa con
/// [FocusManager]; el hover se resuelve con un hit test y se considera cambio
/// de elemento cuando cambia el gesto de pulsación bajo el puntero, no en cada
/// píxel.
class NavigationSoundListener extends ConsumerStatefulWidget {
  const NavigationSoundListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NavigationSoundListener> createState() =>
      _NavigationSoundListenerState();
}

class _NavigationSoundListenerState
    extends ConsumerState<NavigationSoundListener> {
  FocusNode? _lastFocus;
  Object? _lastHoverTarget;

  /// Evita que el autofoco inicial de una pantalla suene al arrancar.
  late final DateTime _muteUntil;

  @override
  void initState() {
    super.initState();
    _muteUntil = DateTime.now().add(const Duration(milliseconds: 800));
    _lastFocus = FocusManager.instance.primaryFocus;
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    final focus = FocusManager.instance.primaryFocus;
    if (identical(focus, _lastFocus)) return;
    _lastFocus = focus;
    if (focus == null || focus == FocusManager.instance.rootScope) return;
    _playConfiguredSound();
  }

  void _onPointerHover(PointerHoverEvent event) {
    final target = _tapTargetAt(event.position, event.viewId);
    if (target == null) {
      _lastHoverTarget = null;
      return;
    }
    if (identical(target, _lastHoverTarget)) return;
    _lastHoverTarget = target;
    _playConfiguredSound();
  }

  /// Primer gesto de pulsación (botón, tarjeta, chip, switch, fila…) bajo el
  /// puntero. Si el elemento no es pulsable (scroll, texto suelto) devuelve
  /// `null` y no suena.
  Object? _tapTargetAt(Offset position, int viewId) {
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(result, position, viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderSemanticsGestureHandler) continue;
      final configuration = SemanticsConfiguration();
      target.describeSemanticsConfiguration(configuration);
      if (configuration.onTap != null || configuration.onLongPress != null) {
        return target;
      }
    }
    return null;
  }

  void _playConfiguredSound() {
    if (DateTime.now().isBefore(_muteUntil)) return;
    final asset = assetForButtonSoundKey(ref.read(buttonSoundKeyProvider));
    if (asset.isEmpty) return;
    HoverSoundPlayer.instance.play(asset);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: _onPointerHover,
      child: widget.child,
    );
  }
}
