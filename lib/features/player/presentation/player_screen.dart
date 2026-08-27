import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/skin/music_player_skin_controller.dart';
import '../../../core/skin/skin.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/logo_image.dart';
import '../../../core/window/app_window.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/image_url.dart';
import '../application/playback_provider.dart';

/// Pantalla de reproducción a pantalla completa (estilo streaming).
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key, required this.itemId, this.item});

  final String itemId;

  /// Item del que viene la navegación (para el título mientras carga).
  final BaseItemDto? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(playbackSessionProvider(itemId));
    return Scaffold(
      backgroundColor: Colors.black,
      body: session.when(
        loading: () => _PlayerLoading(title: item?.name ?? ''),
        error: (_, _) => _PlayerError(
          title: item?.name ?? '',
          onRetry: () => ref.invalidate(playbackSessionProvider(itemId)),
        ),
        data: (data) {
          if (data == null) {
            return _PlayerError(
              title: item?.name ?? '',
              onRetry: () => ref.invalidate(playbackSessionProvider(itemId)),
            );
          }
          return _PlayerView(session: data, item: item);
        },
      ),
    );
  }
}

/// Vista con el reproductor activo (media_kit) y los controles personalizados.
class _PlayerView extends ConsumerStatefulWidget {
  const _PlayerView({required this.session, this.item});

  final PlaybackSession session;
  final BaseItemDto? item;

  @override
  ConsumerState<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<_PlayerView>
    with WidgetsBindingObserver {
  final Player _player = Player();
  late final VideoController? _videoController;
  final List<StreamSubscription<dynamic>> _subs = [];
  final FocusNode _focus = FocusNode();
  bool _playerDisposed = false;

  bool _playing = false;
  bool _buffering = true;
  bool _completed = false;
  bool _error = false;
  String? _errorMessage;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  Tracks _tracks = const Tracks();
  AudioTrack? _selectedAudio;
  SubtitleTrack? _selectedSubtitle;
  bool _dragging = false;
  bool _fullscreen = false;

  PlaybackSession get _session => widget.session;

  /// True si el contenido es solo audio (sin pista de vídeo).
  bool get _isAudio {
    final streams = _session.mediaSource.mediaStreams;
    if (streams == null || streams.isEmpty) return false;
    return !streams.any((s) => s.type == MediaStreamType.video);
  }

  /// URL de la carátula (imagen primaria) del contenido para el modo audio.
  String get _coverUrl {
    final item = widget.item;
    if (item != null && item.id == _session.itemId) {
      return itemImageUrl(_session.serverUrl, item, maxWidth: 800);
    }
    return '${_session.serverUrl}/Items/${_session.itemId}/Images/Primary'
        '?maxWidth=800';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // `auto-copy` evita el desfase A/V que algunos GPUs/drivers producen con
    // la decodificación directa por hardware (`auto`) junto a `vo=libmpv`.
    // En audio solo no se crea textura de vídeo (menos recursos y menos
    // superficie de error al reiniciar la app).
    _videoController = _isAudio
        ? null
        : VideoController(
            _player,
            configuration: const VideoControllerConfiguration(
              hwdec: 'auto-copy',
            ),
          );
    _subscribe();
    _open();
  }

  void _subscribe() {
    _subs.add(
      _player.stream.playing.listen((v) {
        if (mounted) setState(() => _playing = v);
      }),
    );
    _subs.add(
      _player.stream.position.listen((p) {
        if (mounted && !_dragging) setState(() => _position = p);
      }),
    );
    _subs.add(
      _player.stream.duration.listen((d) {
        if (mounted) setState(() => _duration = d);
      }),
    );
    _subs.add(
      _player.stream.buffering.listen((b) {
        if (mounted) setState(() => _buffering = b);
      }),
    );
    _subs.add(
      _player.stream.volume.listen((v) {
        if (mounted) setState(() => _volume = v);
      }),
    );
    _subs.add(
      _player.stream.tracks.listen((t) {
        if (mounted) setState(() => _tracks = t);
      }),
    );
    _subs.add(
      _player.stream.track.listen((t) {
        if (mounted) {
          setState(() {
            _selectedAudio = t.audio;
            _selectedSubtitle = t.subtitle;
          });
        }
      }),
    );
    _subs.add(
      _player.stream.completed.listen((c) {
        if (!mounted) return;
        setState(() {
          _completed = c;
          if (c) {
            _error = false;
            _errorMessage = null;
            _buffering = false;
          }
        });
      }),
    );
    _subs.add(
      _player.stream.error.listen((e) {
        if (!mounted) return;
        final lower = e.toLowerCase();
        final nearEnd =
            _duration.inMilliseconds > 0 &&
            (_duration - _position).inMilliseconds.abs() < 1500;
        // Errores de EOF / decoding al cerrar la pista son benignos: trátalos como fin.
        if (_completed ||
            nearEnd ||
            lower.contains('eof') ||
            lower.contains('end of file')) {
          setState(() {
            _completed = true;
            _error = false;
            _errorMessage = null;
            _buffering = false;
          });
          return;
        }
        // "error decoding audio" suelto al final también se convierte en completado
        // si ya estamos al 98% del progreso.
        final progress = _duration.inMilliseconds > 0
            ? _position.inMilliseconds / _duration.inMilliseconds
            : 0.0;
        if (lower.contains('decoding') && progress > 0.98) {
          setState(() {
            _completed = true;
            _error = false;
            _errorMessage = null;
            _buffering = false;
          });
          return;
        }
        // Error de decodificación al reanudar (seek a mitad): en algunos
        // contenedores el direct play falla al saltar. Si estamos cerca del
        // punto de reanudación, reintentar en lugar de mostrar error.
        if (lower.contains('decoding') && _session.start != null) {
          final startMs = _session.start!.inMilliseconds;
          final posMs = _position.inMilliseconds;
          final nearStart = (posMs - startMs).abs() < 8000;
          final isResuming = nearStart || progress < 0.05;
          if (isResuming) {
            setState(() {
              _error = false;
              _errorMessage = null;
              _buffering = true;
            });
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && !_playerDisposed) {
                _player.seek(_session.start!);
                _player.play();
              }
            });
            return;
          }
        }
        setState(() {
          _error = true;
          _errorMessage = e;
        });
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _stopPlayer();
    _focus.dispose();
    super.dispose();
  }

  /// Control de ciclo de vida: el vídeo se pausa al perder el foco para
  /// no reproducir en segundo plano con la ventana oculta; el audio (música)
  /// continúa en segundo plano para permitir escucha con la app minimizada.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        // La ventana se está cerrando / la app se va a terminar: se para.
        _stopPlayer();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Solo pausar si es vídeo; el audio debe seguir sonando en background.
        if (_playing && !_isAudio) _player.pause();
      case AppLifecycleState.resumed:
        break;
    }
  }

  /// Libera el reproductor de forma segura (idempotente y sin excepciones).
  Future<void> _stopPlayer() async {
    if (_playerDisposed) return;
    _playerDisposed = true;
    try {
      await _player.dispose();
    } catch (_) {
      // El dispose nativo puede fallar si el engine se está cerrando.
    }
  }

  Duration? _durationFromTicks(int? ticks) {
    if (ticks == null || ticks <= 0) return null;
    return Duration(microseconds: ticks ~/ 10);
  }

  Future<void> _open() async {
    if (mounted) setState(() => _error = false);
    try {
      await _player.open(
        Media(
          _session.streamUrl,
          httpHeaders: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
          },
        ),
      );
      await _player.play();
      // Continuar viendo: reanuda desde la posición guardada en Jellyfin
      // en todos los skins. Se usa la posición de la sesión y como fallback
      // la del item original (por si getItem no retornó userData).
      Duration? start = _session.start ?? _durationFromTicks(widget.item?.userData?.playbackPositionTicks);
      if (start != null && start > Duration.zero) {
        // Esperar a que el player conozca la duración; si no, el seek se ignora y empieza desde 0.
        if (_duration == Duration.zero) {
          try {
            await _player.stream.duration
                .firstWhere((d) => d > Duration.zero)
                .timeout(const Duration(seconds: 5));
          } catch (_) {}
        }
        await _player.seek(start);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = '$e';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Controles
  // ---------------------------------------------------------------------------

  void _togglePlay() {
    if (_error) return;
    if (_completed) {
      _player.seek(Duration.zero);
      _player.play();
      if (mounted) setState(() => _completed = false);
      return;
    }
    if (_playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _seekBy(Duration delta) {
    var ms = (_position + delta).inMilliseconds;
    if (ms < 0) ms = 0;
    if (_duration.inMilliseconds > 0 && ms > _duration.inMilliseconds) {
      ms = _duration.inMilliseconds;
    }
    _player.seek(Duration(milliseconds: ms));
  }

  void _onSliderChanged(double seconds) {
    setState(() {
      _dragging = true;
      _position = Duration(milliseconds: (seconds * 1000).round());
    });
  }

  void _onSliderEnd(double seconds) {
    final target = Duration(milliseconds: (seconds * 1000).round());
    _player.seek(target);
    if (mounted) setState(() => _dragging = false);
  }

  void _showControls() {
    if (!_controlsVisible && mounted) {
      setState(() => _controlsVisible = true);
    }
    _scheduleHide();
  }

  /// Click sobre el video: muestra los controles y alterna play/pausa.
  void _handleTap() {
    _showControls();
    _togglePlay();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _playing && !_dragging) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _toggleFullscreen() async {
    final fs = await AppWindow.isFullscreen();
    await AppWindow.setFullscreen(!fs);
    if (mounted) setState(() => _fullscreen = !fs);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _togglePlay();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _seekBy(const Duration(seconds: 10));
        _showControls();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _seekBy(const Duration(seconds: -10));
        _showControls();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (_fullscreen) {
          _toggleFullscreen();
        } else {
          _close();
        }
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _close() {
    if (_fullscreen) {
      AppWindow.setFullscreen(false);
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: _isAudio
                  ? _AudioCover(
                      url: _coverUrl,
                      title: widget.item?.name ?? _session.itemName,
                      artist: widget.item?.artists?.join(', ') ?? '',
                      album: widget.item?.album ?? '',
                      playing: _playing,
                      progress: _duration.inMilliseconds > 0
                          ? (_position.inMilliseconds /
                                    _duration.inMilliseconds)
                                .clamp(0.0, 1.0)
                          : 0,
                    )
                  : Video(
                      controller: _videoController!,
                      controls: NoVideoControls,
                      fit: BoxFit.contain,
                      fill: const Color(0xFF000000),
                    ),
            ),
            if (_buffering && !_error && !_completed)
              const Center(child: AppLoader()),
            if (_completed)
              _ReplayOverlay(onReplay: () => _togglePlay(), onClose: _close),
            if (_error && !_completed)
              _PlayerError(
                title: _session.itemName,
                message: _errorMessage,
                onRetry: () {
                  setState(() {});
                  _open();
                },
              ),
            _buildLogoOverlay(),
            Positioned.fill(
              child: MouseRegion(
                onHover: (_) => _showControls(),
                onExit: (_) {
                  _hideTimer?.cancel();
                  if (_playing && mounted) {
                    setState(() => _controlsVisible = false);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleTap,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_controlsVisible,
                      child: _buildOverlay(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Logotipo (el de las tarjetas o el específico del reproductor) superpuesto
  /// durante la reproducción, en la esquina elegida del skin (o ninguna).
  Widget _buildLogoOverlay() {
    final skin = ref.watch(skinControllerProvider).value;
    final position = skin?.playerLogoPosition ?? LogoOverlayPosition.none;
    final logo = skin?.playerLogo ?? skin?.cardLogo;
    if (position == LogoOverlayPosition.none || logo == null || logo.isEmpty) {
      return const SizedBox.shrink();
    }
    final size = (skin?.cardLogoSize ?? 18) * 2;
    final alignment = switch (position) {
      LogoOverlayPosition.none => Alignment.bottomRight,
      LogoOverlayPosition.topLeft => Alignment.topLeft,
      LogoOverlayPosition.topRight => Alignment.topRight,
      LogoOverlayPosition.bottomLeft => Alignment.bottomLeft,
      LogoOverlayPosition.bottomRight => Alignment.bottomRight,
    };
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LogoImage(logo: logo, height: size),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    final l10n = AppLocalizations.of(context)!;
    final title = _session.itemName.isNotEmpty
        ? _session.itemName
        : (widget.item?.name ?? '');

    final audioTracks = _tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no' && t.title != null)
        .toList();
    final hasSubtitles =
        _tracks.subtitle.any((t) => t.id != 'auto' && t.id != 'no') ||
        _session.externalSubtitles.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Barra superior.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: l10n.back,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _close,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Botón central play/pausa.
        if (!_playing && !_completed)
          Center(
            child: _BigButton(
              icon: Icons.play_arrow_rounded,
              onTap: _togglePlay,
            ),
          ),
        // Barra inferior con el seek y los controles.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: _duration.inMilliseconds > 0
                                ? _duration.inMilliseconds / 1000
                                : 1,
                            value: _position.inMilliseconds > 0
                                ? (_position.inMilliseconds / 1000).clamp(
                                    0,
                                    _duration.inMilliseconds / 1000,
                                  )
                                : 0,
                            onChanged: _duration.inMilliseconds > 0
                                ? _onSliderChanged
                                : null,
                            onChangeEnd: _duration.inMilliseconds > 0
                                ? _onSliderEnd
                                : null,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: _playing ? l10n.pause : l10n.play,
                          icon: Icon(
                            _playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: _togglePlay,
                        ),
                        _VolumeButton(
                          volume: _volume,
                          onChanged: (v) {
                            setState(() => _volume = v);
                            _player.setVolume(v);
                          },
                        ),
                        const Spacer(),
                        if (hasSubtitles) ...[
                          _SubtitleButton(
                            tracks: _tracks,
                            external: _session.externalSubtitles,
                            selected: _selectedSubtitle,
                            onSelected: _selectSubtitle,
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (audioTracks.length > 1) ...[
                          _AudioButton(
                            tracks: audioTracks,
                            selected: _selectedAudio,
                            onSelected: _selectAudio,
                          ),
                          const SizedBox(width: 4),
                        ],
                        IconButton(
                          tooltip: _fullscreen
                              ? l10n.exitFullscreen
                              : l10n.fullscreen,
                          icon: Icon(
                            _fullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _toggleFullscreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectSubtitle(String id) async {
    if (id == 'no') {
      await _player.setSubtitleTrack(SubtitleTrack.no());
      return;
    }
    for (final t in _session.externalSubtitles) {
      if (id == t.id) {
        await _player.setSubtitleTrack(t);
        return;
      }
    }
    for (final t in _tracks.subtitle) {
      if (t.id == id) {
        await _player.setSubtitleTrack(t);
        return;
      }
    }
  }

  Future<void> _selectAudio(String id) async {
    for (final t in _tracks.audio) {
      if (t.id == id) {
        await _player.setAudioTrack(t);
        return;
      }
    }
  }

  static String _formatDuration(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

/// Estado de carga del player.
class _PlayerLoading extends StatelessWidget {
  const _PlayerLoading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLoader(),
              const SizedBox(height: 24),
              if (title.isNotEmpty)
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Error de reproducción o sesión no disponible.
class _PlayerError extends StatelessWidget {
  const _PlayerError({required this.title, this.message, this.onRetry});

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white54,
                    size: 56,
                  ),
                  const SizedBox(height: 16),
                  if (title.isNotEmpty)
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    message ?? l10n.playbackFailed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onRetry != null) ...[
                        OutlinedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(l10n.retry),
                        ),
                        const SizedBox(width: 12),
                      ],
                      FilledButton.icon(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          }
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(l10n.back),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay al finalizar la reproducción.
class _ReplayOverlay extends StatelessWidget {
  const _ReplayOverlay({required this.onReplay, required this.onClose});

  final VoidCallback onReplay;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BigButton(icon: Icons.replay_rounded, onTap: onReplay),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onClose,
            child: Text(
              l10n.back,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carátula del contenido cuando se reproduce solo audio (sin pista de vídeo),
/// con la onda animada entre la portada y la barra de progreso.
/// Bajo la carátula: artista → canción → álbum (resto igual).
class _AudioCover extends ConsumerWidget {
  const _AudioCover({
    required this.url,
    required this.title,
    required this.artist,
    required this.album,
    required this.playing,
    required this.progress,
  });

  final String url;
  final String title;
  final String artist;
  final String album;
  final bool playing;
  final double progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    final musicSkin = ref.watch(musicPlayerSkinControllerProvider).value;
    final bgTop = musicSkin?.backgroundTop ?? skin?.backgroundTop ?? const Color(0xFF0B1030);
    final bgBottom = musicSkin?.backgroundBottom ?? skin?.backgroundBottom ?? const Color(0xFF1A2568);
    final accent = musicSkin?.accent ?? skin?.accent ?? const Color(0xFF2B7FFF);
    final waveform = musicSkin?.waveformEffect ?? skin?.audioWaveformEffect ?? AudioWaveformEffect.equalizer;
    final textPrimary = musicSkin?.textPrimary ?? skin?.textPrimary ?? Colors.white;
    final textSecondary = musicSkin?.textSecondary ?? skin?.textSecondary ?? Colors.white70;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgTop, bgBottom],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Botón atrás persistente en modo audio (lista de reproducción)
          // arriba y a la izquierda, encima de la canción.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: AppLocalizations.of(context)!.back,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/music');
                    }
                  },
                ),
              ),
            ),
          ),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size =
                    (constraints.maxWidth * 0.4)
                        .clamp(180.0, 340.0)
                        .toDouble() *
                    1.5;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : _CoverFallback(),
                        errorBuilder: (_, _, _) => _CoverFallback(),
                      ),
                    ),
                    if (artist.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    if (title.isNotEmpty) ...[
                      SizedBox(height: artist.isNotEmpty ? 6 : 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (album.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Text(
                          album,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          // Onda animada tematizable por music skin.
          Positioned(
            bottom: 110,
            left: 40,
            right: 40,
            child: _AudioWaveform(
              playing: playing,
              progress: progress,
              effect: waveform,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Onda animada del reproductor de audio: dibuja [AudioWaveformEffect] con un
/// [CustomPainter] propio. Se mueve mientras suena y se congela al pausar.
class _AudioWaveform extends StatefulWidget {
  const _AudioWaveform({
    required this.playing,
    required this.progress,
    required this.effect,
    required this.color,
  });

  final bool playing;
  final double progress;
  final AudioWaveformEffect effect;
  final Color color;

  @override
  State<_AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<_AudioWaveform>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Explosión al llegar la bolita al final: animación de un solo disparo.
  late final AnimationController _explosionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _AudioWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al llegar al final, la bolita explota y salen bolitas en todas
    // direcciones.
    if (oldWidget.progress < 1.0 && widget.progress >= 1.0) {
      _explosionController.forward(from: 0);
    }
    _sync();
  }

  void _sync() {
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _explosionController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Efecto surfista: oceano con el icono surfer.svg deslizandose sobre la ola.
    if (widget.effect == AudioWaveformEffect.surfer) {
      return AnimatedBuilder(
        animation: Listenable.merge([_controller, _explosionController]),
        builder: (context, _) => SizedBox(
          height: 72,
          width: double.infinity,
          child: _SurferWave(
            phase: _controller.value,
            progress: widget.progress,
            color: widget.color,
            trackColor: widget.color.withValues(alpha: 0.18),
            explosion: _explosionController.value,
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _explosionController]),
      builder: (context, _) => SizedBox(
        height: 52,
        width: double.infinity,
        child: CustomPaint(
          painter: _WaveformPainter(
            effect: widget.effect,
            phase: _controller.value,
            progress: widget.progress,
            color: widget.color,
            trackColor: widget.color.withValues(alpha: 0.18),
            explosion: _explosionController.value,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Ola surfera: el [surfer.svg] se desliza sobre la cresta siguiendo el progreso.
/// La ola es una senoide animada con [phase]; el surfista se inclina según la
/// pendiente y deja estela/rocío por detrás.
class _SurferWave extends StatelessWidget {
  const _SurferWave({
    required this.phase,
    required this.progress,
    required this.color,
    required this.trackColor,
    this.explosion = 0,
  });

  final double phase;
  final double progress;
  final Color color;
  final Color trackColor;
  final double explosion;

  // Función de altura de la ola. Debe coincidir con la usada en el painter.
  // Coeficientes temporales enteros (1, -2, 1) para bucle perfecto 0→1 sin tirón.
  static double waveY(double x, Size size, double phase) {
    final center = size.height * 0.58;
    final amp = size.height * 0.22;
    final t = phase * 2 * math.pi;
    final u = (x / size.width).clamp(0.0, 1.0);
    return center +
        amp *
            (math.sin(u * math.pi * 2.6 + t) * 0.55 +
                math.sin(u * math.pi * 5.2 - 2 * t) * 0.28 +
                math.sin(u * math.pi * 8 + t) * 0.17);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 72);
        final w = size.width;
        final h = size.height;
        final p = progress.clamp(0.0, 1.0);
        final bx = (p * w).clamp(0.0, w);
        final by = waveY(bx, size, phase);
        // Pendiente para inclinación del surfista.
        const dx = 8.0;
        final y1 = waveY((bx - dx).clamp(0.0, w), size, phase);
        final y2 = waveY((bx + dx).clamp(0.0, w), size, phase);
        final slope = (y2 - y1) / (dx * 2);
        final angle = math.atan(slope) * 0.85;
        // Bote vertical sutil. Coeficiente 2 entero → bucle sin salto.
        final bob = math.sin(phase * 2 * math.pi * 2 + p * math.pi * 4) * 2.5;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SurferWavePainter(
                  phase: phase,
                  progress: p,
                  color: color,
                  trackColor: trackColor,
                  explosion: explosion,
                ),
              ),
            ),
            // Estela/rocío detrás del surfista (pintada aquí como widgets no, sino en painter)
            // Surfista SVG.
            Positioned(
              left: (bx - 22).clamp(-6.0, w - 38),
              top: (by - 28 + bob).clamp(-2.0, h - 40),
              child: Transform.rotate(
                angle: angle,
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/images/icons/surfer.svg',
                  width: 38,
                  height: 38,
                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
            // Tabla de surf bajo el surfista (elipse).
            Positioned(
              left: (bx - 16).clamp(0.0, w - 28),
              top: (by + 6 + bob * 0.3).clamp(0.0, h - 8),
              child: Transform.rotate(
                angle: angle,
                child: Container(
                  width: 28,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SurferWavePainter extends CustomPainter {
  _SurferWavePainter({
    required this.phase,
    required this.progress,
    required this.color,
    required this.trackColor,
    this.explosion = 0,
  });

  final double phase;
  final double progress;
  final Color color;
  final Color trackColor;
  final double explosion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height * 0.58;
    final amp = size.height * 0.22;
    final t = phase * 2 * math.pi;
    const points = 120;

    double yAt(double x) {
      final u = (x / size.width).clamp(0.0, 1.0);
      return center +
          amp *
              (math.sin(u * math.pi * 2.6 + t) * 0.55 +
                  math.sin(u * math.pi * 5.2 - 2 * t) * 0.28 +
                  math.sin(u * math.pi * 8 + t) * 0.17);
    }

    // --- Mar: relleno degradado bajo la ola ---
    final fill = Path()..moveTo(0, yAt(0));
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      fill.lineTo(x, yAt(x));
    }
    fill
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.12),
          ],
        ).createShader(Offset.zero & size),
    );

    // Línea de la ola.
    final wave = Path();
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      final y = yAt(x);
      if (i == 0) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    // Tramo surfeado vs por surfear (colores distintos).
    final progressX = (progress * size.width).clamp(0.0, size.width);
    // Trazo de fondo (por surfear).
    canvas.drawPath(
      wave,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Trazo surfeado (clip).
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, progressX, size.height));
    canvas.drawPath(
      wave,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    // Espuma en la cresta surfeada.
    final foam = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final foamPath = Path();
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      if (x > progressX) break;
      if (i % 3 == 0) {
        final y = yAt(x) - 1.2;
        if (i == 0) {
          foamPath.moveTo(x, y);
        } else {
          foamPath.lineTo(x, y);
        }
      }
    }
    canvas.drawPath(foamPath, foam);

    // Estela detrás del surfista: pequeñas gotas que se van disipando.
    final bx = progressX;
    final tailLen = (size.width * 0.18).clamp(40.0, 120.0);
    const sprayCount = 14;
    for (var i = 0; i < sprayCount; i++) {
      final em = ((i / sprayCount) + phase) % 1.0;
      final x = bx - em * tailLen;
      if (x < 0) continue;
      final scatterY =
          (math.sin(em * math.pi * 6 + i * 1.7) * 3.5 +
              math.sin(phase * 2 * math.pi * 2 + i) * 2) *
          (0.5 + em * 0.7);
      final y = yAt(x.clamp(0.0, size.width)) + scatterY - 2;
      final fade = 1 - em;
      final alpha = fade * fade * 0.65;
      final r = 1.2 + fade * 2.2;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    // Explosión al final.
    if (explosion > 0 && explosion < 1) {
      final by = yAt(bx);
      const n = 20;
      for (var i = 0; i < n; i++) {
        final a = (i / n) * 2 * math.pi + math.sin(i * 5.3) * 0.3;
        final dist = (22 + (i % 4) * 10) * explosion;
        final px = bx + math.cos(a) * dist;
        final py = by + math.sin(a) * dist;
        final fade = 1 - explosion;
        final r = (1.8 + (i % 3) * 1.2) * (0.7 + 0.3 * explosion);
        canvas.drawCircle(
          Offset(px, py),
          r,
          Paint()
            ..color = Colors.white.withValues(
              alpha: fade.clamp(0.0, 1.0) * 0.9,
            ),
        );
      }
      canvas.drawCircle(
        Offset(bx, by),
        5 + explosion * 26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1 - explosion) * 2.5 + 0.6
          ..color = Colors.white.withValues(alpha: (1 - explosion) * 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SurferWavePainter oldDelegate) => true;
}

/// Painter de la onda. Dibuja barras u ondas según el efecto, usando la fase
/// (tiempo 0..1) como animación y el progreso para resaltar lo reproducido.
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.effect,
    required this.phase,
    required this.progress,
    required this.color,
    required this.trackColor,
    this.explosion = 0,
  });

  final AudioWaveformEffect effect;
  final double phase;
  final double progress;
  final Color color;
  final Color trackColor;

  /// Progreso de la explosión (0..1) al llegar la bolita al final. 0 = sin
  /// explosión activa.
  final double explosion;

  static const int _bars = 30;

  @override
  void paint(Canvas canvas, Size size) {
    switch (effect) {
      case AudioWaveformEffect.equalizer:
        _paintBars(canvas, size, mirrored: false, animated: true);
      case AudioWaveformEffect.mirror:
        _paintBars(canvas, size, mirrored: true, animated: true);
      case AudioWaveformEffect.bars:
        _paintBars(canvas, size, mirrored: false, animated: false);
      case AudioWaveformEffect.wave:
        _paintWave(canvas, size);
      case AudioWaveformEffect.surfer:
        _paintWave(canvas, size);
    }
  }

  /// Altura normalizada (0..1) de una barra en un instante dado.
  double _barHeight(int index, bool animated) {
    if (!animated) {
      final x = index / _bars;
      return 0.4 +
          0.6 *
              (0.5 +
                  0.5 *
                      math.sin(
                        x * math.pi * 5 + math.sin(x * math.pi * 9) * 1.2,
                      ));
    }
    final t = phase * 2 * math.pi;
    final noise =
        math.sin(t + index * 0.9) * 0.5 +
        math.sin(2 * t + index * 0.5) * 0.3 +
        math.sin(3 * t + index * 1.3) * 0.2;
    return (0.5 + noise * 0.5).clamp(0.0, 1.0);
  }

  void _paintBars(
    Canvas canvas,
    Size size, {
    required bool mirrored,
    required bool animated,
  }) {
    const gap = 3.0;
    final bw = (size.width - gap * (_bars - 1)) / _bars;
    final center = size.height / 2;
    final amplitude = size.height * (mirrored ? 0.42 : 0.48);

    for (var i = 0; i < _bars; i++) {
      final h = _barHeight(i, animated);
      final barH = amplitude * (0.10 + h * 0.90);
      final isActive = progress >= (i + 0.5) / _bars;
      final paint = Paint()..color = isActive ? color : trackColor;

      final double top;
      final double bottom;
      if (mirrored) {
        // Barras espejadas desde el centro (salen arriba y abajo).
        top = center - barH / 2;
        bottom = center + barH / 2;
      } else {
        // Barras ancladas abajo (estilo ecualizador).
        top = center + amplitude * 0.10 - barH;
        bottom = center + amplitude * 0.10;
      }

      final rect = Rect.fromLTRB(
        i * (bw + gap),
        top,
        i * (bw + gap) + bw,
        bottom,
      );
      final radius = Radius.circular(bw / 2);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: radius,
          topRight: radius,
          bottomLeft: mirrored ? radius : Radius.zero,
          bottomRight: mirrored ? radius : Radius.zero,
        ),
        paint,
      );
    }
  }

  void _paintWave(Canvas canvas, Size size) {
    final center = size.height * 0.5;
    final amp = size.height * 0.36;
    final t = phase * 2 * math.pi;
    const points = 100;

    double yAt(double x) {
      final u = x / size.width;
      return center +
          amp *
              (math.sin(u * math.pi * 3 + t) * 0.6 +
                  math.sin(u * math.pi * 5 - 2 * t) * 0.25 +
                  math.sin(u * math.pi * 7 + t) * 0.15);
    }

    // Relleno degradado bajo la línea.
    final fill = Path()..moveTo(0, center);
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      fill.lineTo(x, yAt(x));
    }
    fill
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    // Línea de la onda.
    final stroke = Path();
    for (var i = 0; i <= points; i++) {
      final x = size.width * i / points;
      final y = yAt(x);
      if (i == 0) {
        stroke.moveTo(x, y);
      } else {
        stroke.lineTo(x, y);
      }
    }
    canvas.drawPath(
      stroke,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Cometa: la bolita recorre la onda siguiendo el progreso y va soltando
    // partículas hacia atrás que se desplazan y se disipan con el tiempo.
    final bx = (progress * size.width).clamp(0.0, size.width);

    // Oscilación sinusoidal vertical (función de la posición y del tiempo):
    // la bolita se eleva por encima de la onda y baja en vaivén bien marcado.
    double bobAt(double x) =>
        math.sin(x / size.width * math.pi * 4 + phase * 2 * math.pi * 2) * 8 +
        2;

    final by = yAt(bx) + bobAt(bx);
    final tailLen = (size.width * 0.5).clamp(70.0, 240.0);

    const trailCount = 30;
    for (var i = 0; i < trailCount; i++) {
      // Tiempo transcurrido desde su "emisión": cada partícula nace en la
      // bolita (em=0) y viaja hacia atrás hasta disiparse (em→1).
      final em = ((i / trailCount) + phase) % 1.0;
      final x = bx - em * tailLen;
      if (x < -6) continue;
      // Sigue la misma oscilación que la bolita (trazada irregular de cometa),
      // más una pequeña dispersión propia para que se aprecie mejor.
      final scatter =
          (math.sin(em * math.pi * 5 + i * 1.9) * 2.5 +
              math.sin(phase * 2 * math.pi * 2 + i * 2.7) * 2.0) *
          (0.4 + em * 0.9);
      final y = yAt(x.clamp(0.0, size.width)) + bobAt(x) + scatter;
      final fade = 1 - em;
      final alpha = fade * fade * 0.7;
      final radius = 1.4 + fade * 2.6;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );
    }

    // Halo de la bolita.
    canvas.drawCircle(
      Offset(bx, by),
      7,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Núcleo de la bolita.
    canvas.drawCircle(Offset(bx, by), 4.5, Paint()..color = Colors.white);

    // Explosión final: bolitas disparadas en todas direcciones que se alejan
    // y se disipan.
    if (explosion > 0 && explosion < 1) {
      const n = 24;
      for (var i = 0; i < n; i++) {
        final angle = (i / n) * 2 * math.pi + math.sin(i * 7.3) * 0.25;
        final dist = (28 + (i % 5) * 8) * explosion;
        final px = bx + math.cos(angle) * dist;
        final py = by + math.sin(angle) * dist;
        final fade = 1 - explosion;
        final radius = (2.2 + (i % 3) * 1.3) * (0.6 + 0.4 * explosion);
        canvas.drawCircle(
          Offset(px, py),
          radius,
          Paint()..color = color.withValues(alpha: fade.clamp(0.0, 1.0) * 0.95),
        );
      }
      // Anillo expansivo de la explosión.
      canvas.drawCircle(
        Offset(bx, by),
        6 + explosion * 30,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1 - explosion) * 3 + 0.5
          ..color = Colors.white.withValues(alpha: (1 - explosion) * 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}

/// Fondo mientras carga la carátula o si no existe imagen.
class _CoverFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white10,
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white38,
        size: 72,
      ),
    );
  }
}

/// Botón circular grande (play/replay).
class _BigButton extends StatelessWidget {
  const _BigButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      iconSize: 72,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon),
    );
  }
}

/// Botón de volumen con deslizador desplegable.
/// Usa [StatefulBuilder] dentro del [PopupMenuItem] para que el arrastre del
/// [Slider] se refleje en el propio overlay (el menú es una ruta aparte y no
/// se reconstruye con el padre). Sin esto el thumb parece "no reaccionar".
class _VolumeButton extends StatefulWidget {
  const _VolumeButton({required this.volume, required this.onChanged});

  final double volume;
  final ValueChanged<double> onChanged;

  @override
  State<_VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<_VolumeButton> {
  IconData _iconFor(double v) {
    if (v <= 0) return Icons.volume_off_rounded;
    if (v < 50) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<double>(
      tooltip: l10n.volume,
      offset: const Offset(0, -140),
      color: const Color(0xEE1A1A1A),
      onSelected: (_) {},
      // Evita que el menú se cierre al interactuar con el Slider.
      onCanceled: () {},
      itemBuilder: (context) {
        // Valor local mutable para el overlay; se sincroniza con widget.volume.
        double current = widget.volume.clamp(0, 100);
        return [
          PopupMenuItem<double>(
            enabled: false,
            // Evita que el InkWell del item intercepte el drag horizontal.
            child: StatefulBuilder(
              builder: (context, setMenu) {
                return SizedBox(
                  width: 200,
                  child: Row(
                    children: [
                      Icon(_iconFor(current), color: Colors.white, size: 20),
                      Expanded(
                        child: Slider(
                          value: current,
                          min: 0,
                          max: 100,
                          activeColor: Colors.white,
                          inactiveColor: Colors.white24,
                          thumbColor: Colors.white,
                          onChanged: (v) {
                            setMenu(() => current = v);
                            widget.onChanged(v);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(_iconFor(widget.volume), color: Colors.white),
      ),
    );
  }
}

/// Botón de subtítulos con menú de pistas.
class _SubtitleButton extends StatelessWidget {
  const _SubtitleButton({
    required this.tracks,
    required this.external,
    required this.selected,
    required this.onSelected,
  });

  final Tracks tracks;
  final List<SubtitleTrack> external;
  final SubtitleTrack? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasExternal = external.isNotEmpty;

    String labelOf(String id, SubtitleTrack t) {
      final base = t.title ?? t.language;
      if (base != null && base.isNotEmpty) return base;
      if (id.startsWith('ext:')) {
        final idx = int.tryParse(id.substring(4));
        if (idx != null && idx < external.length) {
          final et = external[idx];
          return et.title ?? et.language ?? l10n.subtitle;
        }
      }
      return l10n.subtitle;
    }

    final selectedId = selected?.id ?? 'auto';
    bool isSelected(String id, SubtitleTrack? t) {
      if (id == 'no') return selectedId == 'no';
      return t != null && t.id == selectedId;
    }

    return PopupMenuButton<String>(
      tooltip: l10n.subtitle,
      offset: const Offset(0, -60),
      color: const Color(0xEE1A1A1A),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'no',
          child: Row(
            children: [
              Icon(
                isSelected('no', null) ? Icons.check_rounded : null,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.subtitlesOff,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        for (final t in tracks.subtitle)
          if (t.id != 'auto' && t.id != 'no')
            PopupMenuItem<String>(
              value: t.id,
              child: Row(
                children: [
                  Icon(
                    isSelected(t.id, t) ? Icons.check_rounded : null,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.title ?? t.language ?? l10n.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        if (hasExternal) const PopupMenuDivider(),
        for (var i = 0; i < external.length; i++)
          PopupMenuItem<String>(
            value: external[i].id,
            child: Row(
              children: [
                Icon(
                  isSelected(external[i].id, external[i])
                      ? Icons.check_rounded
                      : null,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    labelOf(external[i].id, external[i]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.subtitles_rounded, color: Colors.white),
      ),
    );
  }
}

/// Botón de audio con menú de pistas.
class _AudioButton extends StatelessWidget {
  const _AudioButton({
    required this.tracks,
    required this.selected,
    required this.onSelected,
  });

  final List<AudioTrack> tracks;
  final AudioTrack? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      tooltip: l10n.audio,
      offset: const Offset(0, -60),
      color: const Color(0xEE1A1A1A),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final t in tracks)
          PopupMenuItem<String>(
            value: t.id,
            child: Row(
              children: [
                Icon(
                  selected?.id == t.id ? Icons.check_rounded : null,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.title ?? t.language ?? l10n.audio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.audiotrack_rounded, color: Colors.white),
      ),
    );
  }
}
