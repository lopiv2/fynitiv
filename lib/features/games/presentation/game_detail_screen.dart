import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/audio/game_bg_player.dart';
import '../../../core/audio/khinsider_player.dart';
import '../../../core/settings/game_bg_music_controller.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/theme/dashboard_background.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/scale_button.dart';
import '../../../l10n/app_localizations.dart';
import '../application/khinsider_providers.dart';
import '../application/romm_providers.dart';
import '../data/khinsider/khinsider_models.dart';
import '../domain/romm_game.dart';

/// Detalle de un juego de ROMM con acciones Play (streaming) y Descargar.
class GameDetailScreen extends ConsumerStatefulWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final int gameId;

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with WidgetsBindingObserver {
  bool _launching = false;
  bool _downloading = false;
  StreamSubscription<KhinsiderTrack?>? _khinsiderSub;
  KhinsiderTrack? _currentTrack;
  bool _khinsiderStarted = false;
  List<KhinsiderTrack> _khinsiderQueue = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Marca como jugado para que aparezca en “Continuar jugando” (last_played)
    Future.microtask(() => ref.read(rommRepositoryProvider)?.markPlayed(widget.gameId).then((_) {
          ref.invalidate(rommContinuePlayingProvider);
        }));
    // Parar música de fondo de /games y suscribirse a Now Playing
    Future.microtask(() => GameBgPlayer.instance.leave());
    _khinsiderSub = KhinsiderPlayer.instance.currentTrackStream.listen((track) {
      if (mounted) setState(() => _currentTrack = track);
    });
    _currentTrack = KhinsiderPlayer.instance.currentTrack;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _khinsiderSub?.cancel();
    // Parar OST al salir del detalle (GameMusicScope retomará shuffle al volver a lista)
    KhinsiderPlayer.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      KhinsiderPlayer.instance.pauseForExternal();
    } else if (state == AppLifecycleState.resumed) {
      KhinsiderPlayer.instance.resumeIfNeeded();
    }
  }

  void _maybeStartKhinsider(List<KhinsiderTrack> tracks) {
    if (_khinsiderStarted || tracks.isEmpty) return;
    _khinsiderStarted = true;
    _khinsiderQueue = tracks;
    final muted = ref.read(gameBgMutedProvider);
    KhinsiderPlayer.instance.setMuted(muted);
    // streaming directo, queue completa en shuffle
    KhinsiderPlayer.instance.playQueue(tracks);
  }

  Future<void> _play(RommGame game) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return;
    // Actualiza last_played en RomM
    unawaited(repo.markPlayed(game.id).then((_) => ref.invalidate(rommContinuePlayingProvider)));
    setState(() => _launching = true);
    try {
      final host = await repo.claimStreamingSession(game.id);
      if (!mounted) return;
      if (host == null || host.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gamesNoStreaming)),
        );
        return;
      }
      final uri = Uri.tryParse(host);
      if (uri == null) return;
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gamesLaunchError)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Future<void> _download(RommGame game) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(rommRepositoryProvider);
    unawaited(repo?.markPlayed(game.id).then((_) => ref.invalidate(rommContinuePlayingProvider)));
    final fileName = game.firstFile;
    if (repo == null || fileName == null || fileName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.gamesNoFile)),
        );
      }
      return;
    }
    setState(() => _downloading = true);
    try {
      final savePath = await _downloadPath(fileName);
      if (savePath == null) return;
      await repo.downloadGameFile(
        romId: game.id,
        fileName: fileName,
        savePath: savePath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.gamesDownloaded}\n$savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// Devuelve la ruta de guardado: en la carpeta de descargas del sistema, o
  /// null si no está disponible.
  Future<String?> _downloadPath(String fileName) async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir == null) return null;
      return '${dir.path}\\$fileName';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Escuchar mute para Khinsider (respeta gameBgMutedProvider)
    ref.listen<bool>(gameBgMutedProvider, (prev, muted) {
      KhinsiderPlayer.instance.setMuted(muted);
    });
    // Cuando llegan las pistas de Khinsider, iniciar reproducción shuffle
    ref.listen<AsyncValue<List<KhinsiderTrack>>>(
      khinsiderTracksProvider(widget.gameId),
      (prev, next) {
        final tracks = next.value;
        if (tracks != null && tracks.isNotEmpty) {
          _maybeStartKhinsider(tracks);
        }
      },
    );
    final khinsiderAsync = ref.watch(khinsiderTracksProvider(widget.gameId));
    // Fallback inicial por si ya estaba en cache (listen no dispara en primera carga sync)
    khinsiderAsync.whenData((tracks) {
      if (tracks.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartKhinsider(tracks));
      }
    });

    final game = ref.watch(rommGameProvider(widget.gameId));
    final skin = ref.watch(skinControllerProvider).value;
    final textPrimary = skin?.textPrimary ?? Colors.white;
    final textSecondary = skin?.textSecondary ?? Colors.white70;
    final fallback = skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final token = ref.watch(rommRepositoryProvider)?.token;
    final headers = token != null && token.isNotEmpty ? <String, String>{'Authorization': 'Bearer $token'} : null;

    return Scaffold(
      body: DashboardBackground(
        child: game.when(
          loading: () => const Center(child: AppLoader()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          ),
          data: (g) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: l10n.back,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 200,
                      height: 280,
                      child:
                          g.coverLargeUrl != null && g.coverLargeUrl!.isNotEmpty
                              ? Image.network(
                                  g.coverLargeUrl!,
                                  fit: BoxFit.cover,
                                  headers: headers,
                                  errorBuilder: (_, _, _) => _DetailFallback(
                                    game: g,
                                    color: fallback,
                                  ),
                                )
                              : _DetailFallback(game: g, color: fallback),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.name,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          g.platformDisplayName,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ActionButton(
                              icon: Icons.play_circle_fill,
                              label: l10n.gamesPlay,
                              color: const Color(0xFF2B7FFF),
                              loading: _launching,
                              onTap: () => _play(g),
                            ),
                            _ActionButton(
                              icon: Icons.download_rounded,
                              label: l10n.gamesDownload,
                              color: const Color(0xFF1A2568),
                              loading: _downloading,
                              onTap: () => _download(g),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _NowPlayingBar(
                          khinsiderAsync: khinsiderAsync,
                          currentTrack: _currentTrack,
                          queueLength: _khinsiderQueue.length,
                        ),
                        const SizedBox(height: 20),
                        if (g.summary != null && g.summary!.isNotEmpty)
                          Text(
                            g.summary!,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                      ],
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: loading,
      child: ScaleButton(
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar({
    required this.khinsiderAsync,
    required this.currentTrack,
    required this.queueLength,
  });
  final AsyncValue<List<KhinsiderTrack>> khinsiderAsync;
  final KhinsiderTrack? currentTrack;
  final int queueLength;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return khinsiderAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
          const SizedBox(width: 10),
          Text('${l10n.nowPlaying}...', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (tracks) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        final trackName = currentTrack?.name ?? tracks.first.name;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF2B7FFF).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.music_note_rounded, color: Color(0xFF2B7FFF), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.nowPlaying, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.6, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(l10n.nowPlayingTrack(trackName), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                if (queueLength > 1)
                  Text('$queueLength tracks • shuffle', style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ]),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.equalizer_rounded, color: Colors.white38, size: 18),
          ]),
        );
      },
    );
  }
}

class _DetailFallback extends StatelessWidget {
  const _DetailFallback({required this.game, required this.color});

  final RommGame game;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        game.name.isEmpty ? '?' : game.name.substring(0, 1).toUpperCase(),
        style: const TextStyle(color: Colors.white70, fontSize: 32),
      ),
    );
  }
}