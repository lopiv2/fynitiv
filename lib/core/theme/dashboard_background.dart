import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../skin/effective_skin_provider.dart';
import '../skin/skin.dart';
import '../skin/skin_scope.dart';

/// Fondo con el esquema de color del skin activo.
class DashboardBackground extends ConsumerWidget {
  const DashboardBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Pantallas con skin fijo (SkinScope, p. ej. E-Reader) no se tiñen.
    final Skin skin =
        SkinScope.maybeOf(context) ?? ref.watch(effectiveSkinProvider);
    final top = skin.backgroundTop;
    final bottom = skin.backgroundBottom;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
      ),
      child: child,
    );
  }
}
