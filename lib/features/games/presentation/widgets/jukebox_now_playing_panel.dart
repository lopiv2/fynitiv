import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fynitiv/core/widgets/marquee_text.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/audio/app_volume_provider.dart';
import '../../../../core/constants/ui_constants.dart';
import '../../../../core/skin/skin_controller.dart';
import '../../../../core/widgets/volume_slider.dart';
import '../../../music/application/soloud_music_provider.dart';
import '../../../games/application/jukebox_ui_state.dart';
import '../../../games/application/romm_providers.dart';
import '../../../../l10n/app_localizations.dart';

String _fmt(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Panel lateral derecho del Jukebox (ver captura): cover + título/artista,
/// barra progreso fina, controles y tiempo. Solo visible cuando hay pista
/// ROMM sonando; si no, muestra placeholder sutil.
class JukeboxNowPlayingPanel extends ConsumerWidget {
  const JukeboxNowPlayingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    final accent = skin?.accent ?? const Color(0xFF2B7FFF);
    final soloudState = ref.watch(soloudMusicProvider);
    final s = ref.watch(jukeboxCardScaleProvider);
    final shuffleEnabled = ref.watch(
      jukeboxUiProvider.select((v) => v.shuffleEnabled),
    );
    final hasItem = soloudState.hasItem && !soloudState.completed;
    final isRomm = soloudState.isRomm;

    // Solo mostramos panel cuando hay música (ROMM o Jellyfin), pero con
    // énfasis en ROMM (Jukebox). Si no hay item, placeholder compacto.
    if (!hasItem) {
      return Container(
        padding: EdgeInsets.all(14 * s),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14 * s),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.queue_music_rounded,
              color: Colors.white24,
              size: 28 * s,
            ),
            SizedBox(width: 10 * s),
            Text(
              'Nada sonando',
              style: TextStyle(color: Colors.white38, fontSize: 13 * s),
            ),
          ],
        ),
      );
    }

    final duration = soloudState.duration;
    final position = soloudState.position;
    final playing = soloudState.playing;
    final buffering = soloudState.buffering;
    final coverUrl = soloudState.coverUrl;
    final title = soloudState.title.isNotEmpty ? soloudState.title : '—';
    final artist = soloudState.artist.isNotEmpty
        ? soloudState.artist
        : soloudState.session?.itemName ?? '';
    final rommToken = ref.watch(rommRepositoryProvider)?.token?.trim() ?? '';
    final rommHeaders = rommToken.isNotEmpty
        ? <String, String>{'Authorization': 'Bearer $rommToken'}
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(12 * s, 12 * s, 12 * s, 12 * s),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * s),
                child: coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        width: 150 * s,
                        height: 150 * s,
                        fit: BoxFit.fitHeight,
                        headers: isRomm ? rommHeaders : null,
                        errorBuilder: (_, _, _) => Container(
                          width: 72 * s,
                          height: 72 * s,
                          color: const Color(0xFF1A1A1A),
                          child: Icon(
                            Icons.music_note,
                            color: Colors.white24,
                            size: 28 * s,
                          ),
                        ),
                      )
                    : Container(
                        width: 72 * s,
                        height: 72 * s,
                        color: const Color(0xFF1A1A1A),
                        child: Icon(
                          Icons.music_note,
                          color: Colors.white24,
                          size: 28 * s,
                        ),
                      ),
              ),
              SizedBox(width: 10 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13 * s,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 4 * s),
                    _HoverArtistMarquee(
                      key: ValueKey(artist.isNotEmpty ? artist : '—'),
                      text: artist.isNotEmpty ? artist : '—',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11 * s,
                      ),
                    ),
                    SizedBox(height: 6 * s),
                    Text(
                      '${soloudState.isRomm ? 'Jukebox' : 'Música'} • ${soloudState.isRomm ? '' : ''}',
                      style: TextStyle(color: Colors.white38, fontSize: 10 * s),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * s),
          // Progreso
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3 * s,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6 * s),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white12,
              thumbColor: accent,
            ),
            child: Slider(
              min: 0,
              max: duration.inMilliseconds > 0
                  ? duration.inMilliseconds / 1000
                  : 1,
              value: position.inMilliseconds > 0
                  ? (position.inMilliseconds / 1000).clamp(
                      0,
                      duration.inMilliseconds / 1000,
                    )
                  : 0,
              onChanged: (v) => ref
                  .read(soloudMusicProvider.notifier)
                  .seek(Duration(milliseconds: (v * 1000).round())),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmt(position),
                style: TextStyle(color: Colors.white54, fontSize: 11 * s),
              ),
              if (buffering)
                SizedBox(
                  width: 14 * s,
                  height: 14 * s,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8 * s,
                    color: Colors.white54,
                  ),
                )
              else
                const SizedBox.shrink(),
              Text(
                _fmt(duration),
                style: TextStyle(color: Colors.white54, fontSize: 11 * s),
              ),
            ],
          ),
          SizedBox(height: 8 * s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Aleatorio',
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: shuffleEnabled ? accent : Colors.white54,
                  size: 18 * s,
                ),
                onPressed: () =>
                    ref.read(jukeboxUiProvider.notifier).toggleShuffle(),
              ),
              IconButton(
                tooltip: 'Anterior',
                icon: Icon(
                  Icons.skip_previous_rounded,
                  color: Colors.white,
                  size: 22 * s,
                ),
                onPressed: () =>
                    ref.read(soloudMusicProvider.notifier).previous(),
              ),
              Container(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  tooltip: playing ? 'Pausa' : 'Reproducir',
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: accent,
                    size: 22 * s,
                  ),
                  onPressed: () =>
                      ref.read(soloudMusicProvider.notifier).toggle(),
                ),
              ),
              IconButton(
                tooltip: 'Siguiente',
                icon: Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                  size: 22 * s,
                ),
                onPressed: () => ref.read(soloudMusicProvider.notifier).next(),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.volume,
                icon: Icon(
                  volumeIconFor(ref.watch(appVolumeProvider)),
                  color: Colors.white70,
                  size: 18 * s,
                ),
                onPressed: () => _showVolumeDialog(context, ref, accent),
              ),
              IconButton(
                tooltip: 'Repetir',
                icon: Icon(
                  Icons.repeat_rounded,
                  color: Colors.white54,
                  size: 18 * s,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showVolumeDialog(BuildContext context, WidgetRef ref, Color accent) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: Text(l10n.volume, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      content: Consumer(
        builder: (context, ref, _) {
          final v = ref.watch(appVolumeProvider);
          final muted = v <= 0.5;
          return VolumeSliderRow(
            volume: v,
            muted: muted,
            onChanged: (nv) => ref.read(appVolumeProvider.notifier).setVolume(nv),
            onToggleMute: () {
              final cur = ref.read(appVolumeProvider);
              if (cur <= 0.5) {
                ref.read(appVolumeProvider.notifier).setVolume(80);
              } else {
                ref.read(appVolumeProvider.notifier).setVolume(0);
              }
            },
            volumeTooltip: l10n.volume,
            muteTooltip: l10n.ostMute,
            unmuteTooltip: l10n.ostUnmute,
            accent: accent,
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel, style: const TextStyle(color: Colors.white70)),
        ),
      ],
    ),
  );
}

class _HoverArtistMarquee extends StatefulWidget {
  const _HoverArtistMarquee({
    super.key,
    required this.text,
    required this.style,
  });
  final String text;
  final TextStyle style;
  @override
  State<_HoverArtistMarquee> createState() => _HoverArtistMarqueeState();
}

class _HoverArtistMarqueeState extends State<_HoverArtistMarquee> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: MarqueeText(
        text: widget.text,
        style: widget.style,
        isHovered: _hovered,
        enabled: true,
        velocity: 28,
        gap: 36,
      ),
    );
  }
}
