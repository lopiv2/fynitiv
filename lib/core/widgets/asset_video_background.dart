import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../video/mpv_teardown.dart';

/// Fondo de vídeo en loop para un asset local.
///
/// Genérico y reutilizable: reproduce [assetPath] en silencio y en bucle con
/// `media_kit` (mpv, compatible con Windows), con overlay oscuro para
/// legibilidad y [child] encima. Mientras carga o si falla, muestra
/// [posterAssetPath] (si se da) o [fallback].
class AssetVideoBackground extends StatefulWidget {
  const AssetVideoBackground({
    super.key,
    required this.assetPath,
    required this.child,
    this.posterAssetPath,
    this.fallback,
    this.overlayTopOpacity = 0.45,
    this.overlayBottomOpacity = 0.65,
  });

  final String assetPath;
  final Widget child;

  /// Imagen fija bajo el vídeo (póster) mientras carga o si el vídeo falla.
  final String? posterAssetPath;

  /// Fondo alternativo si no hay póster. Por defecto, negro.
  final Widget? fallback;

  final double overlayTopOpacity;
  final double overlayBottomOpacity;

  @override
  State<AssetVideoBackground> createState() => _AssetVideoBackgroundState();
}

class _AssetVideoBackgroundState extends State<AssetVideoBackground> {
  Player? _player;
  VideoController? _videoController;
  bool _ready = false;
  bool _disposed = false;

  /// Puerta global mpv: serializa los teardowns nativos para no tener dos
  /// superficies ANGLE en transición (aborta con `unlock of unowned mutex`).
  static Future<void> _mpvGate = Future.value();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(AssetVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambia la época (p. ej. override Halloween → Navidad desde el debug)
    // sin salir de la pantalla, el reproductor viejo seguiría con el vídeo
    // anterior: liberarlo y arrancar con el nuevo asset.
    if (oldWidget.assetPath != widget.assetPath) {
      _restart();
    }
  }

  Future<void> _restart() async {
    await _disposePlayer();
    if (_disposed || !mounted) return;
    await _init();
  }

  Future<void> _init() async {
    await _mpvGate;
    if (_disposed || !mounted || _player != null) return;
    final player = Player(configuration: const PlayerConfiguration());
    final controller = VideoController(player);
    _player = player;
    _videoController = controller;
    try {
      await player.setVolume(0);
      await player.setPlaylistMode(PlaylistMode.loop);
      if (_disposed || !mounted || _player != player) {
        await _disposePlayer();
        return;
      }
      final encoded = widget.assetPath
          .split('/')
          .map(Uri.encodeComponent)
          .join('/');
      await player.open(Media('asset:///$encoded'));
      if (_disposed || !mounted || _player != player) {
        await _disposePlayer();
        return;
      }
      await player.play();
      if (_disposed || !mounted || _player != player) {
        await _disposePlayer();
        return;
      }
      setState(() => _ready = true);
      debugPrint('[AssetVideoBackground] playing ${widget.assetPath}');
    } catch (e) {
      debugPrint('[AssetVideoBackground] failed ${widget.assetPath}: $e');
      await _disposePlayer();
      if (!_disposed && mounted) setState(() => _ready = false);
    }
  }

  Future<void> _disposePlayer() {
    _ready = false;
    final player = _player;
    _player = null;
    _mpvGate = _mpvGate.then((_) async {
      await disposeMpvPlayer(player);
      _videoController = null;
      if (!_disposed && mounted) setState(() {});
    });
    return _mpvGate;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_disposePlayer());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_ready && _videoController != null)
          SizedBox.expand(
            child: Video(controller: _videoController!, fit: BoxFit.cover),
          )
        else if (widget.posterAssetPath != null)
          SizedBox.expand(
            child: Image.asset(widget.posterAssetPath!, fit: BoxFit.cover),
          )
        else
          widget.fallback ?? const SizedBox.expand(child: ColoredBox(color: Colors.black)),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: widget.overlayTopOpacity),
                Colors.black.withValues(alpha: widget.overlayBottomOpacity),
              ],
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
