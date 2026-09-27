import 'dart:async';
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
  bool _counted = false;
  bool _disposed = false;
  GameVideoActiveCountController? _counter;

  bool _isOff() {
    // Solo llamar cuando mounted (initState síncrono o callbacks con guard).
    return ref.read(gameVideoDisabledProvider) ||
        ref.read(gameVideoSuspendedProvider);
  }

  void _incActive() {
    if (_counted) return;
    _counted = true;
    try {
      _counter?.increment();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    // Guardar el notifier aquí: en dispose()/gaps async usar ref es inseguro.
    _counter = ref.read(gameVideoActiveCountProvider.notifier);
    _maybeInit();
  }

  Future<void> _maybeInit() async {
    if (_disposed || !mounted) return;
    if (_isOff()) return;
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
      if (_disposed || !mounted) {
        // El widget se desmontó durante los awaits: liberar huérfano sin ref.
        try {
          await player.stop();
        } catch (_) {}
        try {
          await player.dispose();
        } catch (_) {}
        return;
      }
      _incActive();
      setState(() => _ready = true);
      debugPrint('[GameVideoBackground] playing $pick -> $uri');
    } catch (e) {
      debugPrint('[GameVideoBackground] failed $pick ($uri): $e');
      await _dispose();
      if (_disposed || !mounted) return;
      setState(() => _ready = false);
      // reintenta con otro pick una vez
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
          if (_disposed || !mounted) {
            try {
              await retryPlayer.stop();
            } catch (_) {}
            try {
              await retryPlayer.dispose();
            } catch (_) {}
            return;
          }
          _incActive();
          setState(() => _ready = true);
          debugPrint('[GameVideoBackground] retry playing $retryPick');
          return;
        } catch (e2) {
          debugPrint('[GameVideoBackground] retry failed $retryPick: $e2');
          await _dispose();
        }
      }
    }
  }

  Future<void> _dispose() async {
    // Se reclama en síncrono (idempotencia ante llamadas concurrentes) pero
    // el decremento real va DESPUÉS de stop()+dispose(): el visor 3D crea su
    // superficie GL cuando el contador llega a 0, y si el 0 llega con el
    // vídeo aún liberándose, las dos superficies ANGLE conviven y las
    // texturas three.js salen negras. El notifier guardado (_counter, sin
    // ref) es seguro de tocar tras los awaits y tras el unmount.
    final shouldDec = _counted;
    _counted = false;
    _ready = false;
    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) {
      // stop() antes de dispose(): deja de soltar texturas ANGLE en Windows
      // y reduce el FATAL releaseTexImage al convivir con otras superficies.
      try {
        await player.stop();
      } catch (_) {}
      try {
        await player.dispose();
      } catch (_) {}
    }
    if (shouldDec) {
      try {
        _counter?.decrement();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Future<void> handleOffChange() async {
      if (_disposed || !mounted) return;
      if (_isOff()) {
        await _dispose();
        if (!_disposed && mounted) setState(() {});
      } else if (_player == null) {
        await _maybeInit();
        if (!_disposed && mounted) setState(() {});
      }
    }

    ref.listen<bool>(gameVideoDisabledProvider, (_, _) => handleOffChange());
    ref.listen<bool>(gameVideoSuspendedProvider, (_, _) => handleOffChange());
    final off =
        ref.watch(gameVideoDisabledProvider) ||
        ref.watch(gameVideoSuspendedProvider);
    if (off) {
      if (_player != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (_disposed || !mounted) return;
          await _dispose();
          if (!_disposed && mounted) setState(() {});
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
