import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

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
            configuration: const VideoControllerConfiguration(hwdec: 'auto-copy'),
          );
    _subscribe();
    _open();
  }

  void _subscribe() {
    _subs.add(_player.stream.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    }));
    _subs.add(_player.stream.position.listen((p) {
      if (mounted && !_dragging) setState(() => _position = p);
    }));
    _subs.add(_player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));
    _subs.add(_player.stream.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    }));
    _subs.add(_player.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    }));
    _subs.add(_player.stream.tracks.listen((t) {
      if (mounted) setState(() => _tracks = t);
    }));
    _subs.add(_player.stream.track.listen((t) {
      if (mounted) {
        setState(() {
          _selectedAudio = t.audio;
          _selectedSubtitle = t.subtitle;
        });
      }
    }));
    _subs.add(_player.stream.completed.listen((c) {
      if (mounted) setState(() => _completed = c);
    }));
    _subs.add(_player.stream.error.listen((e) {
      if (mounted) {
        setState(() {
          _error = true;
          _errorMessage = e;
        });
      }
    }));
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

  /// Pausa o detiene el reproductor según el ciclo de vida de la app, para que
  /// nunca quede reproduciendo en segundo plano ni con la ventana cerrada.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        // La ventana se está cerrando / la app se va a terminar: se para.
        _stopPlayer();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_playing) _player.pause();
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
      final start = _session.start;
      if (start != null) await _player.seek(start);
      await _player.play();
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
                      title: _session.itemName,
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
            if (_completed && !_error)
              _ReplayOverlay(
                onReplay: () => _togglePlay(),
                onClose: _close,
              ),
            if (_error)
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
    if (position == LogoOverlayPosition.none ||
        logo == null ||
        logo.isEmpty) {
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
    final l10n = AppLocalizations.of(context)!;    final title = _session.itemName.isNotEmpty
        ? _session.itemName
        : (widget.item?.name ?? '');

    final audioTracks = _tracks.audio
        .where((t) => t.id != 'auto' && t.id != 'no' && t.title != null)
        .toList();
    final hasSubtitles = _tracks.subtitle
            .any((t) => t.id != 'auto' && t.id != 'no') ||
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
                          style:
                              const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: _duration.inMilliseconds > 0
                                ? _duration.inMilliseconds / 1000
                                : 1,
                            value: _position.inMilliseconds > 0
                                ? (_position.inMilliseconds / 1000).clamp(
                                    0, _duration.inMilliseconds / 1000)
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
                          style:
                              const TextStyle(color: Colors.white, fontSize: 13),
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
            child: Text(l10n.back, style: const TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}

/// Carátula del contenido cuando se reproduce solo audio (sin pista de vídeo),
/// con la onda animada entre la portada y la barra de progreso.
class _AudioCover extends ConsumerWidget {
  const _AudioCover({
    required this.url,
    required this.title,
    required this.playing,
    required this.progress,
  });

  final String url;
  final String title;
  final bool playing;
  final double progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinControllerProvider).value;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            skin?.backgroundTop ?? const Color(0xFF0B1030),
            skin?.backgroundBottom ?? const Color(0xFF1A2568),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size =
                    (constraints.maxWidth * 0.4).clamp(180.0, 340.0).toDouble() *
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
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          // Onda animada, entre la portada y la barra de progreso inferior.
          Positioned(
            bottom: 120,
            left: 40,
            right: 40,
            child: _AudioWaveform(
              playing: playing,
              progress: progress,
              effect: skin?.audioWaveformEffect ??
                  AudioWaveformEffect.equalizer,
              color: skin?.accent ?? const Color(0xFF2B7FFF),
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
                      math.sin(x * math.pi * 5 +
                          math.sin(x * math.pi * 9) * 1.2));
    }
    final t = phase * 2 * math.pi;
    final noise = math.sin(t + index * 0.9) * 0.5 +
        math.sin(t * 1.9 + index * 0.5) * 0.3 +
        math.sin(t * 3.1 + index * 1.3) * 0.2;
    return (0.5 + noise * 0.5).clamp(0.0, 1.0);
  }

  void _paintBars(Canvas canvas, Size size,
      {required bool mirrored, required bool animated}) {
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
                  math.sin(u * math.pi * 5 - t * 1.3) * 0.25 +
                  math.sin(u * math.pi * 7 + t * 0.7) * 0.15);
    }

    // Relleno degradado bajo la línea.
    final fill = Path()
      ..moveTo(0, center);
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
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.0),
          ],
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
                  math.sin(phase * 2 * math.pi * 2.3 + i * 2.7) * 2.0) *
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
class _VolumeButton extends StatelessWidget {
  const _VolumeButton({required this.volume, required this.onChanged});

  final double volume;
  final ValueChanged<double> onChanged;

  IconData get _icon {
    if (volume <= 0) return Icons.volume_off_rounded;
    if (volume < 50) return Icons.volume_down_rounded;
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
      itemBuilder: (context) => [
        PopupMenuItem<double>(
          enabled: false,
          child: SizedBox(
            width: 160,
            child: Row(
              children: [
                Icon(_icon, color: Colors.white, size: 20),
                Expanded(
                  child: Slider(
                    value: volume.clamp(0, 100),
                    min: 0,
                    max: 100,
                    onChanged: onChanged,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(_icon, color: Colors.white),
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
              Text(l10n.subtitlesOff, style: const TextStyle(color: Colors.white)),
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
