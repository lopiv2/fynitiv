import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

/// Retrato genérico para fichas (personas, artistas...): foto con respaldo
/// de iniciales si no hay imagen o falla la carga. Compartido por la
/// pantalla de persona y la de artista.
class EntityPortrait extends StatelessWidget {
  const EntityPortrait({
    super.key,
    required this.name,
    this.url,
    this.width = 180,
    this.aspectRatio = 2 / 3,
    this.circular = false,
    this.borderRadius = 12,
    this.memCacheWidth = 600,
    this.fallbackColor = const Color(0xFF1A2568),
  });

  /// Nombre para las iniciales del respaldo.
  final String name;

  /// URL de la foto. Vacía o nula = respaldo directo.
  final String? url;

  /// Ancho fijo; el alto sale de [aspectRatio] (1 si [circular]).
  final double width;

  final double aspectRatio;
  final bool circular;
  final double borderRadius;
  final int memCacheWidth;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final clean = url?.trim() ?? '';
    final Widget image = clean.isEmpty
        ? _Initials(name: name, fallbackColor: fallbackColor)
        : CachedNetworkImage(
            imageUrl: clean,
            fit: BoxFit.cover,
            memCacheWidth: memCacheWidth,
            maxWidthDiskCache: memCacheWidth,
            fadeInDuration: const Duration(milliseconds: 150),
            useOldImageOnUrlChange: true,
            errorBuilder: (_, _, _) =>
                _Initials(name: name, fallbackColor: fallbackColor),
            placeholder: (_, _) => ColoredBox(color: fallbackColor),
          );
    final clipped = circular
        ? ClipOval(child: image)
        : ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: image,
          );
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: circular ? 1 : aspectRatio,
        child: clipped,
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.fallbackColor});

  final String name;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return ColoredBox(
      color: fallbackColor,
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
