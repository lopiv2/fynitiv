import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/skin/skin_controller.dart';
import '../../../music/application/soloud_music_provider.dart';
import '../../../games/application/romm_providers.dart';

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
    final hasItem = soloudState.hasItem && !soloudState.completed;
    final isRomm = soloudState.isRomm;

    // Solo mostramos panel cuando hay música (ROMM o Jellyfin), pero con
    // énfasis en ROMM (Jukebox). Si no hay item, placeholder compacto.
    if (!hasItem) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: [
            Icon(Icons.queue_music_rounded, color: Colors.white24, size: 28),
            SizedBox(width: 10),
            Text('Nada sonando', style: TextStyle(color: Colors.white38, fontSize: 13)),
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
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
                borderRadius: BorderRadius.circular(8),
                child: coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        headers: isRomm ? rommHeaders : null,
                        errorBuilder: (_, _, _) => Container(
                          width: 72,
                          height: 72,
                          color: const Color(0xFF1A1A1A),
                          child: const Icon(Icons.music_note, color: Colors.white24, size: 28),
                        ),
                      )
                    : Container(
                        width: 72,
                        height: 72,
                        color: const Color(0xFF1A1A1A),
                        child: const Icon(Icons.music_note, color: Colors.white24, size: 28),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artist.isNotEmpty ? artist : '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${soloudState.isRomm ? 'Jukebox' : 'Música'} • ${soloudState.isRomm ? '' : ''}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progreso
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white12,
              thumbColor: accent,
            ),
            child: Slider(
              min: 0,
              max: duration.inMilliseconds > 0 ? duration.inMilliseconds / 1000 : 1,
              value: position.inMilliseconds > 0
                  ? (position.inMilliseconds / 1000).clamp(0, duration.inMilliseconds / 1000)
                  : 0,
              onChanged: (v) => ref
                  .read(soloudMusicProvider.notifier)
                  .seek(Duration(milliseconds: (v * 1000).round())),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position), style: const TextStyle(color: Colors.white54, fontSize: 11)),
              if (buffering)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white54))
              else
                const SizedBox.shrink(),
              Text(_fmt(duration), style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Aleatorio',
                icon: const Icon(Icons.shuffle_rounded, color: Colors.white54, size: 18),
                onPressed: () {},
              ),
              IconButton(
                tooltip: 'Anterior',
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 22),
                onPressed: () => ref.read(soloudMusicProvider.notifier).previous(),
              ),
              Container(
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: IconButton(
                  tooltip: playing ? 'Pausa' : 'Reproducir',
                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: accent, size: 22),
                  onPressed: () => ref.read(soloudMusicProvider.notifier).toggle(),
                ),
              ),
              IconButton(
                tooltip: 'Siguiente',
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 22),
                onPressed: () => ref.read(soloudMusicProvider.notifier).next(),
              ),
              IconButton(
                tooltip: 'Repetir',
                icon: const Icon(Icons.repeat_rounded, color: Colors.white54, size: 18),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}
