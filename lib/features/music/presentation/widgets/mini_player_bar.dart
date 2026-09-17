import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../application/music_player_provider.dart';
import '../../application/soloud_music_provider.dart';

String _fmt(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Barra inferior tipo Jellyfin oficial para música en segundo plano.
/// Muestra carátula (Hero), título/artista, controles playback, tiempo,
/// volumen y acciones. Se sitúa en la parte inferior de la app y recibe
/// la animación Hero desde el centro del [PlayerScreen] audio.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SoLoud primario para música, fallback a MediaKit legacy.
    // Al terminar la canción (completed) la barra desaparece: no debe
    // quedarse presente ni en mini ni al volver del fullscreen.
    final soloudState = ref.watch(soloudMusicProvider);
    final legacyState = ref.watch(musicPlayerProvider);
    final useSoloud = soloudState.hasItem && !soloudState.completed;
    final legacy = legacyState.hasItem && !legacyState.completed ? legacyState : null;
    final effectiveHasItem = useSoloud || legacy != null;
    if (!effectiveHasItem) return const SizedBox.shrink();

    // Mapear a valores comunes
    final duration = useSoloud ? soloudState.duration : legacy!.duration;
    final position = useSoloud ? soloudState.position : legacy!.position;
    final playing = useSoloud ? soloudState.playing : legacy!.playing;
    final buffering = useSoloud ? soloudState.buffering : legacy!.buffering;
    final volume = useSoloud ? soloudState.volume : legacy!.volume;
    final coverUrl = useSoloud ? soloudState.coverUrl : legacy!.coverUrl;
    final title = useSoloud ? soloudState.title : legacy!.title;
    final artist = useSoloud ? soloudState.artist : legacy!.artist;
    final itemId = useSoloud ? (soloudState.item?.id ?? soloudState.session?.itemId) : (legacy!.item?.id ?? legacy.session?.itemId);
    final item = useSoloud ? soloudState.item : legacy!.item;

    return Material(
      color: const Color(0xFF0F0F0F),
      elevation: 8,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F0F),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: Column(
          children: [
            // Progreso superior fino (como la foto oficial)
            SizedBox(
              height: 3,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: const Color(0xFF00A8E1),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF00A8E1),
                ),
                child: Slider(
                  min: 0,
                  max: duration.inMilliseconds > 0 ? duration.inMilliseconds / 1000 : 1,
                  value: position.inMilliseconds > 0
                      ? (position.inMilliseconds / 1000).clamp(0, duration.inMilliseconds / 1000)
                      : 0,
                  onChanged: (v) => useSoloud
                      ? ref.read(soloudMusicProvider.notifier).seek(Duration(milliseconds: (v * 1000).round()))
                      : ref.read(musicPlayerProvider.notifier).seek(Duration(milliseconds: (v * 1000).round())),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Carátula - también abre fullscreen (maximizar).
                    InkWell(
                      onTap: () {
                        if (itemId == null || itemId.isEmpty) return;
                        if (!context.mounted) return;
                        context.push('/player/$itemId', extra: item);
                      },
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: coverUrl.isNotEmpty
                              ? Image.network(
                                  coverUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(width: 48, height: 48, color: const Color(0xFF1A1A1A), child: const Icon(Icons.music_note, color: Colors.white54, size: 20)),
                                )
                              : Container(width: 48, height: 48, color: const Color(0xFF1A1A1A), child: const Icon(Icons.music_note, color: Colors.white54, size: 20)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Título / artista
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (itemId == null || itemId.isEmpty) return;
                          if (!context.mounted) return;
                          context.push('/player/$itemId', extra: item);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Controles centrales
                    IconButton(
                      tooltip: 'Anterior',
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 22),
                      onPressed: () => useSoloud ? ref.read(soloudMusicProvider.notifier).seekBy(const Duration(seconds: -10)) : ref.read(musicPlayerProvider.notifier).seekBy(const Duration(seconds: -10)),
                    ),
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFF00A8E1).withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: IconButton(
                        tooltip: playing ? 'Pausa' : 'Reproducir',
                        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: const Color(0xFF00A8E1), size: 22),
                        onPressed: () => useSoloud ? ref.read(soloudMusicProvider.notifier).toggle() : ref.read(musicPlayerProvider.notifier).toggle(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Parar',
                      icon: const Icon(Icons.stop_rounded, color: Colors.white70, size: 20),
                      onPressed: () => useSoloud ? ref.read(soloudMusicProvider.notifier).stop() : ref.read(musicPlayerProvider.notifier).stop(),
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 22),
                      onPressed: () => useSoloud ? ref.read(soloudMusicProvider.notifier).seekBy(const Duration(seconds: 10)) : ref.read(musicPlayerProvider.notifier).seekBy(const Duration(seconds: 10)),
                    ),
                    const SizedBox(width: 6),
                    Text('${_fmt(position)} / ${_fmt(duration)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 12),
                    // Volumen
                    const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 18),
                    SizedBox(
                      width: 90,
                      child: SliderTheme(
                        data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5), overlayShape: SliderComponentShape.noOverlay, activeTrackColor: const Color(0xFF00A8E1), inactiveTrackColor: Colors.white24, thumbColor: const Color(0xFF00A8E1)),
                        child: Slider(
                          min: 0,
                          max: 100,
                          value: volume.clamp(0, 100),
                          onChanged: (v) => useSoloud ? ref.read(soloudMusicProvider.notifier).setVolume(v) : ref.read(musicPlayerProvider.notifier).setVolume(v),
                        ),
                      ),
                    ),
                    IconButton(tooltip: 'Repetir', icon: const Icon(Icons.repeat_rounded, color: Colors.white54, size: 18), onPressed: () {}),
                    IconButton(tooltip: 'Aleatorio', icon: const Icon(Icons.shuffle_rounded, color: Colors.white54, size: 18), onPressed: () {}),
                    IconButton(tooltip: 'Favorito', icon: const Icon(Icons.favorite_border_rounded, color: Colors.white54, size: 18), onPressed: () {}),
                    IconButton(
                      tooltip: 'Cerrar mini',
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                      onPressed: () => useSoloud ? ref.read(soloudMusicProvider.notifier).stop() : ref.read(musicPlayerProvider.notifier).stop(),
                    ),
                    if (buffering) const Padding(padding: EdgeInsets.only(left: 4), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white54))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
