import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/constants/game_videos.dart';
import '../../../../core/settings/game_video_controller.dart';
import '../../../../core/theme/dashboard_background.dart';
import '../../../../core/video/mpv_teardown.dart';

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
  bool _disposed = false;

  /// Puerta global mpv: serializa los teardowns nativos de TODOS los
  /// fondos. No se crea un Player nuevo hasta que el dispose anterior
  /// termina (evita dos superficies ANGLE en transición, que aborta el
  /// proceso con `unlock of unowned mutex`).
  static Future<void> _mpvGate = Future.value();

  bool _isOff() {
    // Solo llamar cuando mounted (initState síncrono o callbacks con guard).
    return ref.read(gameVideoDisabledProvider);
  }

  @override
  void initState() {
    super.initState();
    _maybeInit();
  }

  Future<void> _maybeInit() async {
    if (_disposed || !mounted) return;
    if (_isOff()) return;
    if (_player != null) return;
    // Esperar el teardown anterior: nunca dos nativos en transición.
    await _mpvGate;
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
      if (_disposed || !mounted || _player != player) return;
      await player.setVolume(0);
      await player.setPlaylistMode(PlaylistMode.loop);
      if (_disposed || !mounted || _player != player) {
        await _dispose();
        return;
      }
      await player.open(Media(uri));
      if (_disposed || !mounted || _player != player) {
        await _dispose();
        return;
      }
      await player.play();
      if (_disposed || !mounted || _player != player) {
        // El widget se desmontó durante los awaits: liberar huérfano.
        await _dispose();
        return;
      }
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
          if (_disposed || !mounted || _player != retryPlayer) return;
          await retryPlayer.setVolume(0);
          await retryPlayer.setPlaylistMode(PlaylistMode.loop);
          if (_disposed || !mounted || _player != retryPlayer) {
            await _dispose();
            return;
          }
          await retryPlayer.open(Media(retryUri));
          if (_disposed || !mounted || _player != retryPlayer) {
            await _dispose();
            return;
          }
          await retryPlayer.play();
          if (_disposed || !mounted || _player != retryPlayer) {
            await _dispose();
            return;
          }
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

  Future<void> _dispose() {
    // Se reclama en síncrono (idempotencia ante llamadas concurrentes).
    // El teardown nativo se encadena tras la puerta global: el siguiente
    // Player no se crea hasta que este dispose termina.
    _ready = false;
    final player = _player;
    _player = null;
    // El controller se mantiene vivo hasta el fin del teardown para que
    // el `Video` siga montado (toda creación espera a la puerta global,
    // así que nadie lo pisa en medio).
    _mpvGate = _mpvGate.then((_) async {
      // Drenaje con gracia: deja que mpv suelte su GL en su hilo antes
      // de destruir la salida (ver `disposeMpvPlayer`).
      await disposeMpvPlayer(player);
      _videoController = null;
      if (!_disposed && mounted) {
        setState(() {});
      }
    });
    return _mpvGate;
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
    final off = ref.watch(gameVideoDisabledProvider);
    if (off) {
      if (_player != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (_disposed || !mounted) return;
          await _dispose();
          if (!_disposed && mounted) setState(() {});
        });
      }
      // Mientras el teardown nativo corre, el `Video` sigue montado: si
      // se vuelve a `DashboardBackground` antes, mpv libera la textura
      // contra un contexto muerto (`releaseTexImage` FATAL).
      if (_videoController != null) return _videoStack();
      return DashboardBackground(child: widget.child);
    }

    if (_player == null || _videoController == null || !_ready) {
      return DashboardBackground(child: widget.child);
    }

    return _videoStack();
  }

  /// Pila de vídeo a pantalla completa + overlay + contenido.
  Widget _videoStack() {
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
