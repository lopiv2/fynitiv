import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

/// Relleno de una tarjeta sin imagen: muestra la inicial del nombre sobre un
/// color de fondo. Compartido por [PosterCard] y [BackdropCard].
class PosterFallback extends StatelessWidget {
  const PosterFallback({super.key, required this.item, required this.color});

  final BaseItemDto item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initial = (item.name ?? '?').substring(0, 1).toUpperCase();
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontSize: 40),
      ),
    );
  }
}
