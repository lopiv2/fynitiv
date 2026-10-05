import 'package:material_ui/material_ui.dart';

import 'skin.dart';

/// Fija un [Skin] para un subárbol, ignorando el skin global.
///
/// Los widgets compartidos (tarjetas, filas, fondo, títulos) consultan primero
/// este scope con [maybeOf]; si no hay ninguno usan el skin global. Permite que
/// una pantalla (p. ej. el E-Reader) tenga un skin fijo propio sin afectar al
/// resto de la app.
class SkinScope extends InheritedWidget {
  const SkinScope({super.key, required this.skin, required super.child});

  final Skin skin;

  static Skin? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinScope>()?.skin;

  @override
  bool updateShouldNotify(SkinScope oldWidget) => oldWidget.skin != skin;
}
