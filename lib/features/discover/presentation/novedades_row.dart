import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../core/settings/tmdb_key_controller.dart';
import '../../../core/skin/layout_section.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/scroll_title.dart';
import '../../../l10n/app_localizations.dart';
import '../application/tmdb_providers.dart';
import 'tmdb_poster_card.dart';

/// Fila "Novedades" (contenido externo de TMDB).
///
/// Solo se muestra si el usuario ha configurado su API key de TMDB. La fuente
/// ([source]) es configurable desde el layout (trending o estrenos).
class NovedadesRow extends ConsumerWidget {
  const NovedadesRow({super.key, this.source = TmdbNoveltySource.trending});

  final TmdbNoveltySource source;

  static const double _cardWidth = 150;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(tmdbHasKeyProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final items = ref.watch(tmdbNovedadesProvider(source));
    final title = l10n.newReleases;

    return items.when(
      data: (values) {
        if (values.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: kBetweenSectionsGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ScrollTitle(title: title),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: TmdbPosterCard.heightFor(_cardWidth),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, i) {
                    final t = values[i];
                    return TmdbPosterCard(
                      title: t,
                      width: _cardWidth,
                      onTap: () => context.push(
                        '/discover/${t.mediaType.value}/${t.id}',
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.tmdbPoweredBy,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(top: kBetweenSectionsGap, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ScrollTitle(title: title),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 120, child: Center(child: AppLoader())),
          ],
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
