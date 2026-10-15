import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../application/tmdb_providers.dart';
import '../data/tmdb_api.dart';
import '../domain/tmdb_models.dart';
import 'where_to_watch.dart';

/// Ficha externa de un título TMDB (no presente en la biblioteca Jellyfin).
///
/// Muestra backdrop, título, sinopsis, géneros, nota, "Dónde ver" y un enlace a
/// TMDB. Deliberadamente **sin** acciones de Jellyfin (reproducir/descargar/
/// favorito), porque el título no está en la biblioteca.
class TmdbDetailScreen extends ConsumerWidget {
  const TmdbDetailScreen({
    super.key,
    required this.mediaType,
    required this.id,
  });

  final TmdbMediaType mediaType;
  final int id;

  TmdbRef get _ref => (mediaType: mediaType, id: id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Ruta a pantalla completa (fuera del shell): el SafeArea ya cubre el inset
    // del sistema; no se reserva alto de barra superior.
    final detail = ref.watch(tmdbDetailProvider(_ref));

    return Scaffold(
      backgroundColor: const Color(0xFF02070D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          detail.maybeWhen(
            data: (d) {
              final bg = TmdbImages.backdrop(d.backdropPath);
              if (bg == null) return const SizedBox.shrink();
              return Image.network(
                bg,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x9902070D), Color(0xFF02070D)],
                stops: [0.1, 0.75],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  child: IconButton(
                    tooltip: l10n.back,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                ),
                Expanded(
                  child: detail.when(
                    data: (d) => _Content(detail: d, tmdb: _ref),
                    loading: () => const Center(child: AppLoader()),
                    error: (_, _) => Center(
                      child: Text(
                        l10n.noResults,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.detail, required this.tmdb});

  final TmdbDetail detail;
  final TmdbRef tmdb;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final meta = <String>[
      if (detail.year != null) '${detail.year}',
      ...detail.genres,
      if (detail.voteAverage != null && detail.voteAverage! > 0)
        '★ ${detail.voteAverage!.toStringAsFixed(1)}',
    ];
    final tmdbUrl = 'https://www.themoviedb.org/${detail.mediaType.value}/${detail.id}';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  meta.join('  •  '),
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
              if ((detail.overview ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  detail.overview!.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                l10n.whereToWatch,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              WhereToWatchSection(tmdb: tmdb),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(tmdbUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.viewOnTmdb),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
