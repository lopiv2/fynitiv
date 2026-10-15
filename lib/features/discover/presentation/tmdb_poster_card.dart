import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_hover.dart';
import '../data/tmdb_api.dart';
import '../domain/tmdb_models.dart';

/// Tarjeta de póster para contenido externo de TMDB.
///
/// Usa el widget universal de hover ([AppHover]) para el efecto de foco/hover.
class TmdbPosterCard extends StatelessWidget {
  const TmdbPosterCard({
    super.key,
    required this.title,
    required this.onTap,
    this.width = 150,
  });

  final TmdbTitle title;
  final VoidCallback onTap;
  final double width;

  /// Relación de aspecto de un póster (2:3).
  static const double posterAspect = 2 / 3;
  static const double titleBlockHeight = 62;

  /// Alto total de la tarjeta para una [width] dada.
  static double heightFor(double width) =>
      width / posterAspect + titleBlockHeight;

  @override
  Widget build(BuildContext context) {
    final poster = TmdbImages.poster(title.posterPath);
    final year = title.year;
    return AppHover(
      onTap: onTap,
      effect: AppHoverEffect.scale,
      config: AppHoverConfig.scaleOnly(
        scale: 1.05,
        radius: BorderRadius.circular(10),
      ),
      playSoundOnHover: true,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: posterAspect,
                child: poster == null
                    ? const _PosterFallback()
                    : Image.network(
                        poster,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _PosterFallback(),
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : const _PosterFallback(),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (year != null)
              Text(
                '$year',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 32),
      ),
    );
  }
}
