import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/radio_skin.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../music/application/soloud_music_provider.dart';
import '../../application/radio_now_playing_provider.dart';
import '../../application/radio_providers.dart';
import '../../data/radio_station.dart';

class RadioHero extends ConsumerWidget {
  const RadioHero({super.key, required this.skin, this.station});

  final RadioSkin skin;
  final RadioStation? station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final soloudState = ref.watch(soloudMusicProvider);
    final isPlaying = soloudState.session?.itemId == 'radio' && soloudState.playing;
    final isBuffering = soloudState.buffering;
    final hasStation = station != null;

    final bgTop = skin.backgroundTop;
    final bgBottom = skin.backgroundBottom;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgTop.withValues(alpha: 0.95), bgBottom.withValues(alpha: 0.95)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Image.asset('assets/images/radio.png', fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.radio_rounded, color: Colors.white24, size: 80)),
            ),
          ),
          Expanded(
            flex: 7,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 14, 12),
              child: hasStation ? _StationInfo(station: station!, skin: skin, isPlaying: isPlaying, isBuffering: isBuffering) : _EmptyHero(l10n: l10n, skin: skin),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationInfo extends ConsumerWidget {
  const _StationInfo({required this.station, required this.skin, required this.isPlaying, required this.isBuffering});
  final RadioStation station;
  final RadioSkin skin;
  final bool isPlaying;
  final bool isBuffering;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soloudState = ref.watch(soloudMusicProvider);
    final player = soloudState;
    final nowPlaying = ref.watch(radioNowPlayingProvider).value;
    final nowText = nowPlaying?.hasData == true ? nowPlaying!.display : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              clipBehavior: Clip.antiAlias,
              child: station.favicon.isNotEmpty
                  ? CachedNetworkImage(imageUrl: station.favicon, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.radio_rounded, color: Colors.black54))
                  : const Icon(Icons.radio_rounded, color: Colors.black54),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  if (nowText != null) ...[
                    const SizedBox(height: 2),
                    Text('Ahora suena', style: TextStyle(color: skin.accent, fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                  Text(nowText ?? [station.country, station.tags.isNotEmpty ? station.tags.first : ''].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: skin.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
          children: [
            Row(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(tooltip: 'Anterior', icon: const Icon(Icons.skip_previous_rounded, color: Colors.white70, size: 40), onPressed: () {}),
                    const SizedBox(width: 4),
                    Container(
                      decoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle, border: Border.all(color: skin.accent, width: 2)),
                      child: isBuffering
                          ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)))
                          : IconButton(
                              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white70, size: 40),
                              onPressed: () async {
                                if (isPlaying) {
                                  ref.read(soloudMusicProvider.notifier).pause();
                                } else {
                                  String url = station.streamUrl;
                                  try {
                                    final fresh = await ref.read(radioApiProvider).resolveStreamUrl(station.stationUuid);
                                    if (fresh != null && fresh.isNotEmpty) url = fresh;
                                  } catch (_) {}
                                  ref.read(soloudMusicProvider.notifier).playRadioUrl(url: url, title: station.name, artist: station.country, coverUrl: station.favicon);
                                }
                              },
                            ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(tooltip: 'Siguiente', icon: const Icon(Icons.skip_next_rounded, color: Colors.white70, size: 40), onPressed: () {}),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Favorito',
                  icon: Icon(ref.watch(radioFavoritesProvider).isFavorite(station.stationUuid) ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: ref.watch(radioFavoritesProvider).isFavorite(station.stationUuid) ? Colors.white : Colors.white70, size: 40),
                  onPressed: () => ref.read(radioFavoritesProvider.notifier).toggle(station),
                ),
                IconButton(tooltip: 'Más', icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 40), onPressed: () {}),
              ],
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.46,
                child: Row(
                  children: [
                    const Icon(Icons.volume_down_rounded, color: Colors.white70, size: 36),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5), overlayShape: SliderComponentShape.noOverlay, activeTrackColor: skin.accent, inactiveTrackColor: Colors.white24, thumbColor: Colors.white),
                        child: Slider(min: 0, max: 100, value: player.volume.clamp(0, 100), onChanged: (v) => ref.read(soloudMusicProvider.notifier).setVolume(v)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.volume_up_rounded, color: Colors.white54, size: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.l10n, required this.skin});
  final dynamic l10n;
  final RadioSkin skin;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Radio', style: TextStyle(color: skin.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Selecciona una emisora destacada', style: TextStyle(color: skin.textSecondary, fontSize: 12)),
      ],
    );
  }
}
