import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/radio_skin.dart';
import '../../../../core/widgets/app_hover.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../music/application/music_player_provider.dart';
import '../../application/radio_providers.dart';
import '../../data/radio_station.dart';

class StationCard extends ConsumerWidget {
  const StationCard({
    super.key,
    required this.station,
    required this.skin,
    this.isPlaying = false,
    this.isFav = false,
  });

  final RadioStation station;
  final RadioSkin skin;
  final bool isPlaying;
  final bool isFav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favicon = station.favicon;
    final accent = skin.accent;
    final cardBg = skin.cardBackground;
    final l10n = AppLocalizations.of(context)!;
    final player = ref.watch(musicPlayerProvider);
    final isThisStationPlaying = isPlaying && player.session?.streamUrl == station.streamUrl;

    Future<void> handlePlay() async {
      // Capturar notifiers de forma síncrona para evitar usar ref tras suspensión
      final musicNotifier = ref.read(musicPlayerProvider.notifier);
      final selectedNotifier = ref.read(radioSelectedStationProvider.notifier);
      final recentNotifier = ref.read(radioRecentProvider.notifier);
      final radioApi = ref.read(radioApiProvider);
      // Toggle si es la misma emisora ya en reproducción
      if (isThisStationPlaying && player.playing) {
        musicNotifier.pause();
        return;
      }
      if (isThisStationPlaying && !player.playing && player.session != null) {
        musicNotifier.toggle();
        return;
      }
      selectedNotifier.set(station);
      // push es síncrono en memoria, persistencia en background
      recentNotifier.push(station);
      try {
        await radioApi.click(station.stationUuid);
      } catch (_) {}
      if (!context.mounted) return;
      final url = station.streamUrl;
      if (url.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.playbackFailed)),
          );
        }
        return;
      }
      try {
        await musicNotifier.playRadioUrl(
              url: url,
              title: station.name,
              artist: station.country.isNotEmpty ? station.country : station.language,
              coverUrl: favicon,
            );
        // Verificar si quedó error en el player
        if (context.mounted) {
          final after = ref.read(musicPlayerProvider);
          if (after.error != null && after.error!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(after.error!)),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
    }

    return Semantics(
      button: true,
      label: station.name,
      child: AppHover(
        effect: AppHoverEffect.scaleHighlightOutline,
        config: AppHoverConfig.scaleHighlightOutline(
          scale: 1.03,
          radius: BorderRadius.circular(skin.cardRadius),
          highlightNormal: cardBg,
          highlightHovered: cardBg.withValues(alpha: 0.9),
          outlineColor: Colors.transparent,
          outlineHoveredColor: Colors.white,
          outlineHoveredWidth: 1.5,
        ),
        playSoundOnHover: false,
        onTap: handlePlay,
        child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(skin.cardRadius),
          border: isPlaying ? Border.all(color: accent, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Favicon + estado + fav
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: favicon.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: favicon,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(Icons.radio_rounded, color: Colors.black54, size: 28),
                          placeholder: (_, _) => const SizedBox.shrink(),
                        )
                      : const Icon(Icons.radio_rounded, color: Colors.black54, size: 28),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name.isNotEmpty ? station.name : '—',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: skin.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (station.country.isNotEmpty) station.country,
                          if (station.language.isNotEmpty) station.language,
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: skin.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isFav ? 'Quitar de favoritos' : AppLocalizations.of(context)!.radioFavorites,
                  icon: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? Colors.redAccent : Colors.white54,
                    size: 18,
                  ),
                  onPressed: () => ref.read(radioFavoritesProvider.notifier).toggle(station),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (station.tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: station.tags.take(3).map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(t, style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
            const Spacer(),
            Row(
              children: [
                if (station.codec.isNotEmpty)
                  Text(station.codec.toUpperCase(), style: TextStyle(color: skin.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
                if (station.bitrate > 0) ...[
                  const SizedBox(width: 6),
                  Text('${station.bitrate} kbps', style: TextStyle(color: skin.textSecondary, fontSize: 10)),
                ],
                const Spacer(),
                if (isPlaying)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
                        child: Text(l10n.radioLive, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 4),
                      // Pause / Resume
                      InkWell(
                        onTap: () {
                          final p = ref.read(musicPlayerProvider);
                          if (p.playing) {
                            ref.read(musicPlayerProvider.notifier).pause();
                          } else {
                            ref.read(musicPlayerProvider.notifier).toggle();
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: Icon(
                            player.playing && isThisStationPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Stop
                      InkWell(
                        onTap: () => ref.read(musicPlayerProvider.notifier).stop(),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                          child: const Icon(Icons.stop_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  )
                else
                  InkWell(
                    onTap: handlePlay,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}
