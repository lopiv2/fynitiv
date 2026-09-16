import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/radio_skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../music/application/music_player_provider.dart';
import '../application/radio_providers.dart';
import 'widgets/radio_filters.dart';
import 'widgets/station_card.dart';

class RadioAllScreen extends ConsumerWidget {
  const RadioAllScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skin = ref.watch(radioSkinControllerProvider).value;
    if (skin == null) return const Scaffold(body: Center(child: AppLoader()));
    final searchAsync = ref.watch(radioSearchProvider);
    final favs = ref.watch(radioFavoritesProvider);
    final player = ref.watch(musicPlayerProvider);
    final selected = ref.watch(radioSelectedStationProvider);
    final isRadioPlaying = player.session?.itemId == 'radio' && player.playing;
    final playingName = player.session?.itemName;

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
                  Text('${searchAsync.value?.length ?? 0} ${l10n.radioStations}', style: TextStyle(color: skin.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RadioFilters(skin: skin),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: searchAsync.when(
                data: (stations) {
                  if (stations.isEmpty) {
                    return Center(child: Text(l10n.radioNoResults, style: TextStyle(color: skin.textSecondary)));
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35),
                    itemCount: stations.length,
                    itemBuilder: (context, i) {
                      final s = stations[i];
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
