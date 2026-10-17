import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../library/presentation/widgets/poster_card.dart';

/// Entrada de una tarjeta del grid de Seerr: el `BaseItemDto` ya mapeado más
/// los extras que [PosterCard] resuelve aparte para contenido externo
/// (imagen de TMDB, logos de plataforma, badge de esquina…).
class SeerrPosterGridEntry {
  const SeerrPosterGridEntry({
    required this.item,
    required this.onTap,
    this.imageUrl,
    this.cardLogo,
    this.cornerLogos,
    this.cornerBadge,
    this.hoverActionLabel,
  });

  final BaseItemDto item;
  final VoidCallback onTap;

  /// URL de imagen explícita (contenido externo, p. ej. TMDB).
  final String? imageUrl;

  /// Logo superpuesto abajo a la derecha de la portada.
  final String? cardLogo;

  /// Logos de plataformas (esquina inferior derecha), si hay.
  final List<String>? cornerLogos;

  /// Badge no interactivo en la esquina superior izquierda de la portada.
  final Widget? cornerBadge;

  /// Texto del botón principal del hover (p. ej. "Solicitar" o "Detalles").
  final String? hoverActionLabel;
}

/// Grid de pósters de Seerr (pestañas Buscar y Peticiones) reutilizando el
/// [PosterCard] del resto de la app: mismo look, hover, foco y tamaños del skin.
class SeerrPosterGrid extends StatelessWidget {
  const SeerrPosterGrid({
    super.key,
    required this.entries,
    this.padding = const EdgeInsets.all(24),
  });

  final List<SeerrPosterGridEntry> entries;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.5,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        return PosterCard(
          item: e.item,
          serverUrl: null,
          imageUrl: e.imageUrl,
          showPlayIcon: false,
          showHoverIncludedBadge: false,
          hoverActionLabel: e.hoverActionLabel,
          cardLogo: e.cardLogo,
          cornerLogos: e.cornerLogos,
          cornerBadge: e.cornerBadge,
          onTap: e.onTap,
        );
      },
    );
  }
}
