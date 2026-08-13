import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../skin/skin_controller.dart';

/// Fondo con el esquema de color del skin activo.
class DashboardBackground extends ConsumerWidget {
  const DashboardBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    final top = skin?.backgroundTop ?? const Color(0xFF0B1030);
    final bottom = skin?.backgroundBottom ?? const Color(0xFF1A2568);

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
