import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/presentation/item_detail_screen.dart';
import '../application/seerr_providers.dart';
import '../domain/seerr_models.dart';

/// Ficha de un título de Seerr. Reutiliza la pantalla de detalle de la app
/// (`ItemDetailScreen`) para que sea idéntica a la de cada skin, pasando el
/// título de TMDB mapeado a `BaseItemDto` y su backdrop.
class SeerrDetailScreen extends ConsumerWidget {
  const SeerrDetailScreen({
    super.key,
    required this.mediaType,
    required this.tmdbId,
  });

  final SeerrMediaType mediaType;
  final int tmdbId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(
      seerrDetailProvider((mediaType: mediaType, tmdbId: tmdbId)),
    );
    return detail.when(
      data: (media) => ItemDetailScreen(
        item: seerrMediaToBaseItem(media),
        backdropUrl: media.backdropUrl(),
        seerrMedia: media,
      ),
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF02070D),
        body: Center(child: AppLoader()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: const Color(0xFF02070D),
        body: Center(
          child: Text(
            l10n.noResults,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
