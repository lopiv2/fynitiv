import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/skin/radio_skin_controller.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../l10n/app_localizations.dart';
import '../../music/application/soloud_music_provider.dart';
import '../application/radio_geo_provider.dart';
import '../application/radio_providers.dart';
import 'widgets/radio_effects_panel.dart';
import 'widgets/radio_genre_chips.dart';
import 'widgets/radio_hero.dart';
import 'widgets/station_card.dart';

class RadioView extends ConsumerWidget {
  const RadioView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final skinAsync = ref.watch(radioSkinControllerProvider);
    final skin = skinAsync.value;
    if (skin == null) return const Center(child: AppLoader());

    final featuredAsync = ref.watch(radioFeaturedByCountryProvider);
    final favs = ref.watch(radioFavoritesProvider);
    final favStationsAsync = ref.watch(radioFavoriteStationsProvider);
    final player = ref.watch(soloudMusicProvider);
    final selected = ref.watch(radioSelectedStationProvider);
    final isRadioPlaying = player.session?.itemId == 'radio' && player.playing;
    final playingName = player.session?.itemName;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skin.backgroundTop, skin.backgroundBottom],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          // Hero
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: RadioHero(skin: skin, station: selected),
            ),
          ),
          // Panel efectos — selector de onda + visualización con señal falsa.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            sliver: SliverToBoxAdapter(
              child: RadioEffectsPanel(radioSkin: skin),
            ),
          ),
          // Géneros
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
            sliver: SliverToBoxAdapter(
              child: Text(
                l10n.radioGenres,
                style: TextStyle(
                  color: skin.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
            sliver: SliverToBoxAdapter(child: RadioGenreChips()),
          ),
          // Favoritas entre géneros y destacadas (oculta si no hay).
          ...favStationsAsync.when(
            data: (stations) => stations.isEmpty
                ? const <Widget>[SliverToBoxAdapter(child: SizedBox.shrink())]
                : <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 58, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          l10n.radioFavorites,
                          style: TextStyle(
                            color: skin.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 300,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 1.85,
                            ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final s = stations[i];
                          final isPlaying =
                              isRadioPlaying && playingName == s.name;
                          return StationCard(
                            station: s,
                            skin: skin,
                            isPlaying: isPlaying,
                            isFav: true,
                          );
                        }, childCount: stations.length),
                      ),
                    ),
                  ],
            loading: () => const <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: AppLoader()),
                ),
              ),
            ],
            error: (e, _) => const <Widget>[
              SliverToBoxAdapter(child: SizedBox.shrink()),
            ],
          ),
          // Emisoras destacadas header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 58, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    l10n.radioFeatured,
                    style: TextStyle(
                      color: skin.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/radio/all'),
                    child: Text(
                      l10n.radioSeeAll,
                      style: TextStyle(
                        color: skin.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Grid destacadas 8 según país
          featuredAsync.when(
            data: (stations) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.85,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final s = stations[i];
                  final isPlaying = isRadioPlaying && playingName == s.name;
                  final isFav = favs.isFavorite(s.stationUuid);
                  return StationCard(
                    station: s,
                    skin: skin,
                    isPlaying: isPlaying,
                    isFav: isFav,
                  );
                }, childCount: stations.length),
              ),
            ),
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: AppLoader()),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('$e', style: TextStyle(color: skin.textSecondary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
