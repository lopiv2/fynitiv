import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/radio_skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../music/application/soloud_music_provider.dart';
import '../application/radio_providers.dart';
import 'widgets/radio_filters.dart';
import 'widgets/station_card.dart';

class RadioAllScreen extends ConsumerStatefulWidget {
  const RadioAllScreen({super.key});

  @override
  ConsumerState<RadioAllScreen> createState() => _RadioAllScreenState();
}

class _RadioAllScreenState extends ConsumerState<RadioAllScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(radioSkinControllerProvider).value;
    if (skin == null) return const Scaffold(body: Center(child: AppLoader()));

    final query = ref.watch(radioSearchQueryProvider);
    // Reset página al cambiar filtros/búsqueda
    ref.listen<RadioSearchQuery>(radioSearchQueryProvider, (prev, next) {
      if (prev != next && _page != 0) {
        setState(() => _page = 0);
      }
    });

    final args = RadioPagedArgs(query: query, page: _page);
    final pageAsync = ref.watch(radioSearchPageProvider(args));
    final favs = ref.watch(radioFavoritesProvider);
    final player = ref.watch(soloudMusicProvider);
    final selected = ref.watch(radioSelectedStationProvider);
    final isRadioPlaying = player.session?.itemId == 'radio' && player.playing;
    final playingName = player.session?.itemName;

    final stations = pageAsync.value ?? const [];
    final isPageLoading = pageAsync.isLoading;
    final hasPrev = _page > 0;
    final hasNext = stations.length >= kRadioPageSize;

    return Scaffold(
      body: DashboardBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.radioAllStations, style: TextStyle(color: skin.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('${stations.length} ${l10n.radioStations}', style: TextStyle(color: skin.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RadioFilters(skin: skin),
            ),
            const SizedBox(height: 8),
            // Barra de paginación como en Todas las películas / series / música (100 por página)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Anterior',
                    onPressed: hasPrev && !isPageLoading ? () => setState(() => _page--) : null,
                    icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.pageOf(_page + 1, hasNext ? _page + 2 : _page + 1),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Siguiente',
                    onPressed: hasNext && !isPageLoading ? () => setState(() => _page++) : null,
                    icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.04),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                  const Spacer(),
                  if (isPageLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: pageAsync.when(
                data: (data) {
                  if (data.isEmpty) {
                    return Center(child: Text(_page == 0 ? l10n.radioNoResults : 'Sin más resultados', style: TextStyle(color: skin.textSecondary)));
                  }
                  return GridView.builder(
                    key: ValueKey('radio_page_$_page'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35),
                    itemCount: data.length,
                    itemBuilder: (context, i) {
                      final s = data[i];
                      final isPlaying = isRadioPlaying && playingName == s.name && selected?.stationUuid == s.stationUuid || (isRadioPlaying && playingName == s.name);
                      final isFav = favs.isFavorite(s.stationUuid);
                      return StationCard(station: s, skin: skin, isPlaying: isPlaying, isFav: isFav);
                    },
                  );
                },
                loading: () => const Center(child: AppLoader()),
                error: (e, _) => Center(child: Text('$e', style: TextStyle(color: skin.textSecondary))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
