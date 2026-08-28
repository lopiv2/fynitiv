import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/constants/game_videos.dart';
import '../../../../core/settings/game_video_controller.dart';
import '../../../../core/theme/dashboard_background.dart';

/// Fondo de video aleatorio en loop para la rama de juego online.
/// Uno aleatorio por entrada; si está deshabilitado hace fallback a DashboardBackground.
/// Usa media_kit (mpv) para compatibilidad Windows.
class GameVideoBackground extends ConsumerStatefulWidget {
  const GameVideoBackground({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GameVideoBackground> createState() => _GameVideoBackgroundState();
}

class _GameVideoBackgroundState extends ConsumerState<GameVideoBackground> {
  Player? _player;
  VideoController? _videoController;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _maybeInit();
  }

  Future<void> _maybeInit() async {
    final disabled = ref.read(gameVideoDisabledProvider);
    if (disabled) return;
    if (_player != null) return;
    final pick = kGameVideos[Random().nextInt(kGameVideos.length)];
    // asset:/// + ruta con espacios codificados como %20
    final encoded = pick.split('/').map(Uri.encodeComponent).join('/');
    final uri = 'asset:///$encoded';
    final player = Player(configuration: const PlayerConfiguration());
    final controller = VideoController(player);
    _player = player;
    _videoController = controller;
    try {
      await player.setVolume(0);
      await player.setPlaylistMode(PlaylistMode.loop);
      await player.open(Media(uri));
      await player.play();
      if (mounted) setState(() => _ready = true);
      debugPrint('[GameVideoBackground] playing $pick -> $uri');
    } catch (e) {
      debugPrint('[GameVideoBackground] failed $pick ($uri): $e');
      await _dispose();
      if (mounted) setState(() => _ready = false);
      // reintenta con otro pick una vez
      if (mounted) {
        // evita loop infinito: prueba otro aleatorio
        final retryPick = kGameVideos[Random().nextInt(kGameVideos.length)];
        if (retryPick != pick) {
          final retryEncoded = retryPick.split('/').map(Uri.encodeComponent).join('/');
          final retryUri = 'asset:///$retryEncoded';
          final retryPlayer = Player(configuration: const PlayerConfiguration());
          final retryCtrl = VideoController(retryPlayer);
          _player = retryPlayer;
          _videoController = retryCtrl;
          try {
            await retryPlayer.setVolume(0);
            await retryPlayer.setPlaylistMode(PlaylistMode.loop);
            await retryPlayer.open(Media(retryUri));
            await retryPlayer.play();
            if (mounted) setState(() => _ready = true);
            debugPrint('[GameVideoBackground] retry playing $retryPick');
            return;
          } catch (e2) {
            debugPrint('[GameVideoBackground] retry failed $retryPick: $e2');
            await _dispose();
          }
        }
      }
    }
  }

  Future<void> _dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    _videoController = null;
    _ready = false;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(gameVideoDisabledProvider, (prev, next) async {
      if (next == true) {
        await _dispose();
        if (mounted) setState(() {});
      } else if (next == false && _player == null) {
        await _maybeInit();
        if (mounted) setState(() {});
      }
    });
    final disabled = ref.watch(gameVideoDisabledProvider);
    if (disabled) {
      if (_player != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _dispose();
          if (mounted) setState(() {});
        });
      }
      return DashboardBackground(child: widget.child);
    }

    if (_player == null || _videoController == null || !_ready) {
      return DashboardBackground(child: widget.child);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video a pantalla completa (media_kit)
        SizedBox.expand(
          child: Video(
            controller: _videoController!,
            fit: BoxFit.cover,
          ),
        ),
        // Overlay oscuro para legibilidad
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.black.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
