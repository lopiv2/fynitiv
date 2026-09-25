import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../games/application/romm_providers.dart';
import '../../../../core/constants/ui_constants.dart';
import '../../application/music_player_provider.dart';
import '../../application/soloud_music_provider.dart';

String _fmt(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Corazón de la barra para pistas ROMM (`romm-<romFileId>`): optimistic
/// update contra `POST`/`DELETE /api/music/favorites`, reversión silenciosa.
Future<void> _toggleRommFav(WidgetRef ref, SoloudMusicState state) async {
  final session = state.session;
  if (session == null) return;
  final id = int.tryParse(session.itemId.replaceFirst('romm-', ''));
  if (id == null || id <= 0) return;
  final repo = ref.read(rommRepositoryProvider);
  if (repo == null) return;
  final target = !state.isFavorite;
  ref.read(soloudMusicProvider.notifier).updateFavorite(target);
  try {
    if (target) {
      await repo.addMusicFavorites([id]);
    } else {
      await repo.removeMusicFavorites([id]);
    }
  } catch (_) {
    ref.read(soloudMusicProvider.notifier).updateFavorite(!target);
  }
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
    final legacy = legacyState.hasItem && !legacyState.completed
        ? legacyState
        : null;
    final effectiveHasItem = useSoloud || legacy != null;
    if (!effectiveHasItem) return const SizedBox.shrink();
    // En /games/jukebox el player vive en el lateral derecho (ver captura);
    // ocultamos el mini global cuando hay barra y estamos en jukebox (fallback robusto).
    String jukeboxLoc = '';
    try {
      jukeboxLoc = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      try {
        jukeboxLoc = GoRouter.of(context).routeInformationProvider.value.uri.toString();
      } catch (_) {}
    }
    if (jukeboxLoc.contains('jukebox') && effectiveHasItem) {
      return const SizedBox.shrink();
    }

    // Mapear a valores comunes
    final duration = useSoloud ? soloudState.duration : legacy!.duration;
    final position = useSoloud ? soloudState.position : legacy!.position;
    final playing = useSoloud ? soloudState.playing : legacy!.playing;
    final buffering = useSoloud ? soloudState.buffering : legacy!.buffering;
    final volume = useSoloud ? soloudState.volume : legacy!.volume;
    final coverUrl = useSoloud ? soloudState.coverUrl : legacy!.coverUrl;
    final title = useSoloud ? soloudState.title : legacy!.title;
    final artist = useSoloud ? soloudState.artist : legacy!.artist;
    final itemId = useSoloud
        ? (soloudState.item?.id ?? soloudState.session?.itemId)
        : (legacy!.item?.id ?? legacy.session?.itemId);
    final item = useSoloud ? soloudState.item : legacy!.item;
    // Solo las pantallas Jellyfin con id navegan al fullscreen: las pistas
    // ROMM (`romm-<id>`, sintéticas sin id) y la radio no salen de la barra.
    final canOpenFullscreen =
        (item?.id?.isNotEmpty == true) && !(useSoloud && soloudState.isRomm);
    // Las OST no traen cover propio: se usa la portada del juego dueño
    // (`ostCoverUrl`); las covers de ROMM exigen Bearer.
    final rommToken = ref.watch(rommRepositoryProvider)?.token?.trim() ?? '';
    final rommHeaders = rommToken.isNotEmpty
        ? <String, String>{'Authorization': 'Bearer $rommToken'}
        : null;
    // Factor por plataforma: mobile 1.0 / desktop 1.0 / tv 1.4 (ver ui_constants).
    final s = ref.watch(miniPlayerScaleProvider);
    final barHeight = (64 * s).clamp(64, 120).toDouble();
    final coverSize = 48 * s;
    final iconMain = 32 * s;
    final iconSmall = 22 * s;
    final iconStop = 32 * s;
    final padH = 8 * s;
    final gapSmall = 6 * s;
    final gapMed = 10 * s;
    final gapLarge = 12 * s;
    final volWidth = (90 * s).clamp(90, 160).toDouble();
    final progressH = (3 * s).clamp(3, 6).toDouble();
    final titleFs = 13 * s;
    final artistFs = 11 * s;
    final timeFs = 11 * s;

    return Material(
      color: const Color(0xFF0F0F0F),
      elevation: 8,
      child: Container(
        height: barHeight,
        decoration: const BoxDecoration(
          color: Color(0xFF0F0F0F),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        child: Column(
          children: [
            // Progreso superior fino (como la foto oficial)
            SizedBox(
              height: progressH,
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: progressH.clamp(3, 6).toDouble(),
                  thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: 6 * s.clamp(1, 1.4),
                  ),
                  overlayShape: SliderComponentShape.noOverlay,
                  activeTrackColor: const Color(0xFF00A8E1),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF00A8E1),
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
                  onChanged: (v) => useSoloud
                      ? ref
                            .read(soloudMusicProvider.notifier)
                            .seek(Duration(milliseconds: (v * 1000).round()))
                      : ref
                            .read(musicPlayerProvider.notifier)
                            .seek(Duration(milliseconds: (v * 1000).round())),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padH),
                child: Row(
                  children: [
                    // Carátula - también abre fullscreen (maximizar).
                    InkWell(
                      onTap: () {
                        if (!canOpenFullscreen) return;
                        if (!context.mounted) return;
                        context.push('/player/$itemId', extra: item);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          4 * s.clamp(1, 1.4),
                        ),
                        child: coverUrl.isNotEmpty
                            ? Image.network(
                                coverUrl,
                                width: coverSize,
                                height: coverSize,
                                fit: BoxFit.cover,
                                headers: useSoloud && soloudState.isRomm
                                    ? rommHeaders
                                    : null,
                                errorBuilder: (_, _, _) => Container(
                                  width: coverSize,
                                  height: coverSize,
                                  color: const Color(0xFF1A1A1A),
                                  child: Icon(
                                    Icons.music_note,
                                    color: Colors.white54,
                                    size: 20 * s.clamp(1, 1.4),
                                  ),
                                ),
                              )
                            : Container(
                                width: coverSize,
                                height: coverSize,
                                color: const Color(0xFF1A1A1A),
                                child: Icon(
                                  Icons.music_note,
                                  color: Colors.white54,
                                  size: 20 * s.clamp(1, 1.4),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: gapMed),
                    // Título / artista
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (!canOpenFullscreen) return;
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleFs.clamp(13, 18),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: artistFs.clamp(11, 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Controles centrales
                    IconButton(
                      tooltip: 'Anterior',
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                        size: iconMain,
                      ),
                      onPressed: () => useSoloud
                          ? ref.read(soloudMusicProvider.notifier).previous()
                          : ref
                                .read(musicPlayerProvider.notifier)
                                .seekBy(const Duration(seconds: -10)),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A8E1).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        tooltip: playing ? 'Pausa' : 'Reproducir',
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: const Color(0xFF00A8E1),
                          size: iconMain,
                        ),
                        onPressed: () => useSoloud
                            ? ref.read(soloudMusicProvider.notifier).toggle()
                            : ref.read(musicPlayerProvider.notifier).toggle(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Parar',
                      icon: Icon(
                        Icons.stop_rounded,
                        color: Colors.white70,
                        size: iconStop,
                      ),
                      onPressed: () => useSoloud
                          ? ref.read(soloudMusicProvider.notifier).stop()
                          : ref.read(musicPlayerProvider.notifier).stop(),
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      icon: Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                        size: iconMain,
                      ),
                      onPressed: () => useSoloud
                          ? ref.read(soloudMusicProvider.notifier).next()
                          : ref
                                .read(musicPlayerProvider.notifier)
                                .seekBy(const Duration(seconds: 10)),
                    ),
                    SizedBox(width: gapSmall),
                    Text(
                      '${_fmt(position)} / ${_fmt(duration)}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: timeFs.clamp(11, 15),
                      ),
                    ),
                    SizedBox(width: gapLarge),
                    // Volumen
                    Icon(
                      Icons.volume_up_rounded,
                      color: Colors.white70,
                      size: iconSmall,
                    ),
                    SizedBox(
                      width: volWidth,
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: (3 * s).clamp(3, 5).toDouble(),
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: (5 * s).clamp(5, 7),
                          ),
                          overlayShape: SliderComponentShape.noOverlay,
                          activeTrackColor: const Color(0xFF00A8E1),
                          inactiveTrackColor: Colors.white24,
                          thumbColor: const Color(0xFF00A8E1),
                        ),
                        child: Slider(
                          min: 0,
                          max: 100,
                          value: volume.clamp(0, 100),
                          onChanged: (v) => useSoloud
                              ? ref
                                    .read(soloudMusicProvider.notifier)
                                    .setVolume(v)
                              : ref
                                    .read(musicPlayerProvider.notifier)
                                    .setVolume(v),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Repetir',
                      icon: Icon(
                        Icons.repeat_rounded,
                        color: Colors.white54,
                        size: iconSmall,
                      ),
                      onPressed: () {},
                    ),
                    IconButton(
                      tooltip: 'Aleatorio',
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: Colors.white54,
                        size: iconSmall,
                      ),
                      onPressed: () {},
                    ),
                    IconButton(
                      tooltip: 'Favorito',
                      icon: Icon(
                        useSoloud &&
                                soloudState.isRomm &&
                                soloudState.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color:
                            useSoloud &&
                                soloudState.isRomm &&
                                soloudState.isFavorite
                            ? Colors.white
                            : Colors.white54,
                        size: iconSmall,
                      ),
                      onPressed: useSoloud && soloudState.isRomm
                          ? () => _toggleRommFav(ref, soloudState)
                          : () {},
                    ),
                    IconButton(
                      tooltip: 'Cerrar mini',
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white54,
                        size: iconSmall,
                      ),
                      onPressed: () => useSoloud
                          ? ref.read(soloudMusicProvider.notifier).stop()
                          : ref.read(musicPlayerProvider.notifier).stop(),
                    ),
                    if (buffering)
                      Padding(
                        padding: EdgeInsets.only(left: 4 * s),
                        child: SizedBox(
                          width: 14 * s,
                          height: 14 * s,
                          child: CircularProgressIndicator(
                            strokeWidth: (1.8 * s).clamp(1.8, 2.4),
                            color: Colors.white54,
                          ),
                        ),
                      ),
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
