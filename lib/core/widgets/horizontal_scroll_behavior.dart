import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// Comportamiento de scroll para listas horizontales de escritorio: permite
/// arrastrarlas con el ratón (además de con la rueda, que se gestiona a parte
/// para desplazar la fila en horizontal).
class HorizontalScrollBehavior extends MaterialScrollBehavior {
  const HorizontalScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
