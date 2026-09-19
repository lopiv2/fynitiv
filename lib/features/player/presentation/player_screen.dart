import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_flux/audio_flux.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/audio/soloud_initializer.dart';
import '../../../core/audio/app_volume_provider.dart';
import '../../../core/audio/item_theme_player.dart';
import '../../music/application/soloud_music_provider.dart';

import '../../music/application/lrclib_providers.dart';
import '../../music/application/player_view_mode.dart';
import '../../music/application/audio_eq_provider.dart';
import '../../music/data/lrclib_repository.dart';
import '../../music/presentation/widgets/audio_eq_drawer.dart';
import '../../music/presentation/widgets/auto_eq_toggle.dart';
import '../../library/application/library_providers.dart';

import '../../../core/skin/music_player_skin_controller.dart';
import '../../../core/skin/music_player_skin_presets.dart';
import '../../../core/skin/skin.dart';
import '../../../core/skin/skin_controller.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/led_spectrum.dart';
import '../../../core/widgets/logo_image.dart';
import '../../../core/widgets/circular_spectrum.dart';
import '../../../core/widgets/raymarch.dart';
import '../../../core/widgets/smoke_rings.dart';
import '../../../core/widgets/sound_eclipse.dart';
import '../../../core/widgets/sound_sinus.dart';
import '../../../core/window/app_window.dart';
import '../../../l10n/app_localizations.dart';
import '../../library/application/image_url.dart';
import '../../music/application/music_player_provider.dart';
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

  /// La restauración del audio guardado se intenta una sola vez por
  /// sesión, cuando mpv ya informa de las pistas.
  bool _audioRestored = false;

  /// Pistas de audio de mpv (sin auto/no).
  List<AudioTrack> get _mpvAudioTracks => _tracks.audio
      .where((t) => t.id != 'auto' && t.id != 'no')
      .toList();

  /// Audios de Jellyfin en el mismo orden (para etiquetas y persistencia).
  List<MediaStream> get _jellyAudio =>
      (_session.mediaSource?.mediaStreams ?? const <MediaStream>[])
          .where((s) => s.type == MediaStreamType.audio)
          .toList();

  static String _audioPrefKey(String itemId) => 'audio_track_index_$itemId';
  bool _dragging = false;
  bool _fullscreen = false;

  PlaybackSession get _session => widget.session;

  /// True si el contenido es solo audio (sin pista de vídeo).
  bool get _isAudio {
    final streams = _session.mediaSource?.mediaStreams;
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

  /// Géneros del audio para el Auto-EQ. El item de navegación suele venir
  /// sin géneros (listas que no piden ese campo), así que se usa el detalle
  /// completo del item como respaldo.
  List<String>? get _audioGenres {
    final nav = widget.item?.genres;
    if (nav != null && nav.isNotEmpty) return nav;
    final detail = ref.watch(itemDetailProvider(_session.itemId)).value;
    return detail?.genres;
  }

  @override
  void initState() {
    super.initState();
    // El theme de la ficha se detiene al reproducir (no pausa: con pausa
    // la URL seguía guardada y cualquier resume (p. ej. volver del segundo
    // plano) lo reactivaba sobre la peli/serie).
    ItemThemePlayer.instance.stop();
    // Volumen universal como punto de partida (vídeo y fallback MediaKit).
    try {
      _volume = ref.read(appVolumeProvider).clamp(0, 100).toDouble();
      _player.setVolume(_volume);
    } catch (_) {}
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
    // Diferir la apertura al primer frame: `_open` muta providers (handoff
    // del mini player) y hace setState. Si corre dentro del montaje durante
    // la transición push, esas escrituras síncronas colisionan con el build
    // en curso (assert `!_dirty` en el Stack/Positioned del player).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_playerDisposed) _open();
    });
  }

  void _subscribe() {
    _subs.add(
      _player.stream.playing.listen((v) {
        if (mounted) setState(() => _playing = v);
      }),
    );
    _subs.add(
      _player.stream.position.listen((p) {
        // Limita rebuilds a 1 por segundo visible: el stream emite varias
        // veces por segundo y cada tick reconstruía todo el player (cover,
        // lyrics, onda) saturando la transición de maximizar.
        if (!mounted || _dragging) return;
        if (_position != Duration.zero && p.inSeconds == _position.inSeconds) {
          return;
        }
        setState(() => _position = p);
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
        unawaited(_maybeRestoreAudio());
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
    // Sin resume: el theme se detuvo al entrar y no debe volver solo.
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
    // Ruta SoLoud para solo-audio (música): deja MediaKit como fallback interno del provider
    if (_isAudio) {
      try {
        // Handoff desde mini SoLoud si es mismo track
        final soloudMini = ref.read(soloudMusicProvider);
        final soloudId = soloudMini.item?.id ?? soloudMini.session?.itemId;
        final curId = _session.itemId;
        if (soloudMini.hasItem && soloudId == curId && soloudMini.playing) {
          // Ya está sonando en SoLoud global, no re-abrir; solo asegúrate que siga
          _volume = soloudMini.volume;
          if (mounted) setState(() => _volume = soloudMini.volume);
          // Pausar fallback legacy si estuviera activo para no solapar
          try {
            ref.read(musicPlayerProvider.notifier).pause();
          } catch (_) {}
          // No abrir _player local
          try {
            await _player.pause();
          } catch (_) {}
          return;
        }
        // Otro track en mini SoLoud o legacy: limpiar
        try {
          ref.read(musicPlayerProvider.notifier).stop();
        } catch (_) {}
        // Abrir via SoLoud primario (con fallback MediaKit interno).
        // Sin handoff se pasa null para heredar el volumen universal.
        Duration? miniPos;
        double? miniVol;
        if (soloudMini.hasItem && soloudId == curId) {
          miniPos = soloudMini.position;
          final hv = soloudMini.volume;
          miniVol = hv;
          _volume = hv;
          if (mounted) setState(() => _volume = hv);
        } else {
          // Si había otro track en SoLoud, se sobreescribe
        }
        // Intentar herencia desde legacy mini si SoLoud estaba vacío pero legacy tenía mismo track
        if (miniPos == null) {
          try {
            final mini = ref.read(musicPlayerProvider);
            if (mini.hasItem &&
                (mini.item?.id ?? mini.session?.itemId) == curId) {
              miniPos = mini.position;
              final hv = mini.volume;
              miniVol = hv;
              _volume = hv;
              if (mounted) setState(() => _volume = hv);
            }
          } catch (_) {}
        }
        await ref
            .read(soloudMusicProvider.notifier)
            .playFromSession(
              _session,
              widget.item,
              start: miniPos,
              volume: miniVol,
            );
        _volume = ref.read(soloudMusicProvider).volume;
        if (mounted) setState(() {});
        try {
          await _player.pause();
        } catch (_) {}
        return;
      } catch (_) {
        // Si SoLoud falla, caer a MediaKit local
      }
    }
    // Si viene desde el mini-player (mismo track), heredar volumen/posición
    // y pausar mini para no solapar. Sin handoff, volumen universal.
    Duration? miniPos;
    double? miniVol;
    try {
      final mini = ref.read(musicPlayerProvider);
      if (mini.hasItem) {
        final miniId = mini.item?.id ?? mini.session?.itemId;
        final curId = _session.itemId;
        if (miniId != null && miniId == curId) {
          miniPos = mini.position;
          final hv = mini.volume;
          miniVol = hv;
          if (mini.playing) {
            // Pausar mini para la transición inversa sin doble audio
            ref.read(musicPlayerProvider.notifier).pause();
          }
          _volume = hv;
          try {
            await _player.setVolume(hv);
          } catch (_) {}
          if (mounted) setState(() => _volume = hv);
        } else {
          // Mini con otra pista: limpiarlo para no dejar dos audios
          ref.read(musicPlayerProvider.notifier).stop();
        }
      }
    } catch (_) {}
    // También pausar SoLoud mini si existe y es otro track
    try {
      final sMini = ref.read(soloudMusicProvider);
      if (sMini.hasItem &&
          (sMini.item?.id ?? sMini.session?.itemId) != _session.itemId) {
        ref.read(soloudMusicProvider.notifier).stop();
      }
    } catch (_) {}
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
      // Aplicar volumen: handoff del mini o universal. El Player nuevo
      // arranca a 100 por defecto y hay que corregirlo siempre.
      final double startVol = miniVol ?? ref.read(appVolumeProvider);
      _volume = startVol.clamp(0, 100).toDouble();
      try {
        await _player.setVolume(_volume);
      } catch (_) {}
      if (mounted) setState(() {});
      // Si venía del mini, miniPos tiene prioridad sobre session.start
      if (miniPos != null && miniPos > Duration.zero) {
        try {
          await _player.stream.duration
              .firstWhere((d) => d > Duration.zero)
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
        await _player.seek(miniPos);
        if (mounted) setState(() => _position = miniPos!);
        // Ya hemos usado la posición del mini, no repetir con session.start
        return;
      }
      // Continuar viendo: reanuda desde la posición guardada en Jellyfin
      // en todos los skins. Se usa la posición de la sesión y como fallback
      // la del item original (por si getItem no retornó userData).
      Duration? start =
          _session.start ??
          _durationFromTicks(widget.item?.userData?.playbackPositionTicks);
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
    if (_isAudio) {
      final s = ref.read(soloudMusicProvider);
      if (s.completed) {
        ref.read(soloudMusicProvider.notifier).replay();
        if (mounted) setState(() => _completed = false);
        return;
      }
      ref.read(soloudMusicProvider.notifier).toggle();
      return;
    }
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
    if (_isAudio) {
      ref.read(soloudMusicProvider.notifier).seekBy(delta);
      _showControls();
      return;
    }
    var ms = (_position + delta).inMilliseconds;
    if (ms < 0) ms = 0;
    if (_duration.inMilliseconds > 0 && ms > _duration.inMilliseconds) {
      ms = _duration.inMilliseconds;
    }
    _player.seek(Duration(milliseconds: ms));
  }

  void _onSliderChanged(double seconds) {
    if (_isAudio) {
      // Para SoLoud, actualizar visualmente y hacer seek inmediato con dragging flag local
      setState(() {
        _dragging = true;
        _position = Duration(milliseconds: (seconds * 1000).round());
      });
      return;
    }
    setState(() {
      _dragging = true;
      _position = Duration(milliseconds: (seconds * 1000).round());
    });
  }

  void _onSliderEnd(double seconds) {
    final target = Duration(milliseconds: (seconds * 1000).round());
    if (_isAudio) {
      ref.read(soloudMusicProvider.notifier).seek(target);
      if (mounted) setState(() => _dragging = false);
      return;
    }
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
    // SoLoud para música ya es global: no necesita handoff, solo pop
    if (_isAudio) {
      final soloudState = ref.read(soloudMusicProvider);
      if (soloudState.hasItem && soloudState.playing) {
        // Ya suena en SoLoud global, solo pop
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
        return;
      }
      // Fallback legacy handoff si SoLoud no estaba activo (HLS o error)
      final effPlaying = soloudState.hasItem ? soloudState.playing : _playing;
      final effPos = soloudState.hasItem ? soloudState.position : _position;
      final effVol = soloudState.hasItem ? soloudState.volume : _volume;
      if (effPlaying) {
        try {
          ref
              .read(soloudMusicProvider.notifier)
              .playFromSession(
                _session,
                widget.item,
                start: effPos,
                volume: effVol,
              );
        } catch (_) {}
        // También fallback a legacy si SoLoud no pudo (mantener compat)
        try {
          _player.pause();
          ref
              .read(musicPlayerProvider.notifier)
              .playFromSession(
                _session,
                widget.item,
                start: _position,
                volume: _volume,
              );
        } catch (_) {}
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
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
    // El vídeo local sigue al volumen universal si cambia desde otra
    // pantalla (el audio va por soloudMusicProvider, ya sincronizado).
    ref.listen<double>(appVolumeProvider, (prev, next) {
      if (!mounted || _isAudio) return;
      if ((_volume - next).abs() < 0.001) return;
      _volume = next;
      try {
        _player.setVolume(next);
      } catch (_) {}
      if (mounted) setState(() {});
    });
    // Estado SoLoud para audio: primario, con fallback a MediaKit local
    final soloudState = _isAudio ? ref.watch(soloudMusicProvider) : null;
    final hasSoloud = soloudState != null && soloudState.hasItem;
    final effPlaying = hasSoloud ? soloudState.playing : _playing;
    final effBuffering = hasSoloud ? soloudState.buffering : _buffering;
    final effCompleted = hasSoloud ? soloudState.completed : _completed;
    final effPosition = hasSoloud ? soloudState.position : _position;
    final effDuration = hasSoloud ? soloudState.duration : _duration;
    // Si está dragging, mostrar posición local para no pelear con ticker
    final displayPosition = (_isAudio && hasSoloud && _dragging)
        ? _position
        : effPosition;
    final displayDuration = effDuration;
    final displayPlaying = effPlaying;
    // Portada, Letra y Efectos pintan controles persistentes dentro de _AudioCover:
    // se oculta el overlay auto-hide y la pill va a la derecha.
    final audioCoverMode = _isAudio;
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
                      year: widget.item?.productionYear,
                      genres: _audioGenres,
                      logoUrl: widget.item != null
                          ? itemLogoUrl(_session.serverUrl, widget.item!)
                          : null,
                      serverUrl: _session.serverUrl,
                      playing: displayPlaying,
                      progress: displayDuration.inMilliseconds > 0
                          ? (displayPosition.inMilliseconds /
                                    displayDuration.inMilliseconds)
                                .clamp(0.0, 1.0)
                          : 0,
                      position: displayPosition,
                      duration: displayDuration,
                      heroTag:
                          'music-cover-${widget.item?.id ?? _session.itemId}',
                      onBack: _close,
                      onTogglePlay: _togglePlay,
                      onSeekChanged: (d) =>
                          _onSliderChanged(d.inMilliseconds / 1000),
                      onSeekEnd: (d) => _onSliderEnd(d.inMilliseconds / 1000),
                      onSkipBackward: () =>
                          _seekBy(const Duration(seconds: -10)),
                      onSkipForward: () => _seekBy(const Duration(seconds: 10)),
                      volume: hasSoloud ? soloudState.volume : _volume,
                      onVolumeChanged: (v) {
                        if (_isAudio && hasSoloud) {
                          ref.read(soloudMusicProvider.notifier).setVolume(v);
                        } else {
                          setState(() => _volume = v);
                          _player.setVolume(v);
                          try {
                            ref.read(appVolumeProvider.notifier).setVolume(v);
                          } catch (_) {}
                        }
                      },
                      onToggleFullscreen: _toggleFullscreen,
                    )
                  : Video(
                      controller: _videoController!,
                      controls: NoVideoControls,
                      fit: BoxFit.contain,
                      fill: const Color(0xFF000000),
                    ),
            ),
            if ((hasSoloud ? effBuffering : _buffering) &&
                !_error &&
                !(hasSoloud ? effCompleted : _completed))
              const Center(child: AppLoader()),
            if ((hasSoloud ? effCompleted : _completed))
              _ReplayOverlay(onReplay: () => _togglePlay(), onClose: _close),
            if (_error && !(hasSoloud ? effCompleted : _completed))
              _PlayerError(
                title: _session.itemName,
                message: _errorMessage,
                onRetry: () {
                  setState(() {});
                  _open();
                },
              ),
            _buildLogoOverlay(),
            // En modo portada de audio los controles son persistentes: se
            // oculta el overlay auto-hide (incluido el play central).
            if (!audioCoverMode)
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
            // Toggle pill Portada/Letra/Efectos: siempre visible y por encima
            // del GestureDetector para recibir taps. En portada va a la
            // derecha (foto de referencia); en el resto, centrado.
            if (_isAudio)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                    child: Align(
                      alignment: audioCoverMode
                          ? Alignment.topRight
                          : Alignment.topCenter,
                      child: _LyricsCoverToggle(),
                    ),
                  ),
                ),
              ),
            if (_isAudio && ref.watch(eqDrawerOpenProvider))
              Positioned.fill(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          ref.read(eqDrawerOpenProvider.notifier).close(),
                      child: Container(color: Colors.black54),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 360,
                        child: AudioEqDrawer(
                          onClose: () =>
                              ref.read(eqDrawerOpenProvider.notifier).close(),
                        ),
                      ),
                    ),
                  ],
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

    // Sin exigir título: mpv no informa título en pistas integradas
    // (solo idioma como "spa"/"eng"), y con ese filtro el botón
    // no aparecía nunca aunque la peli tuviera varios audios.
    // Metadatos de Jellyfin para las etiquetas (idioma - codec - canales):
    // en direct play van en el mismo orden que las pistas de mpv.
    final audioTracks = _mpvAudioTracks;
    final jellyAudio = _jellyAudio;
    // Subtítulos de Jellyfin en el mismo orden que las pistas de mpv
    // (integrados) y que los externos servidos por el servidor.
    final jellySubs =
        (_session.mediaSource?.mediaStreams ?? const <MediaStream>[])
            .where((s) => s.type == MediaStreamType.subtitle)
            .toList();
    final embeddedSubMeta =
        jellySubs.where((s) => s.isExternal != true).toList();
    final externalSubMeta = jellySubs.where((s) {
      final d = s.deliveryUrl;
      return d != null && d.isNotEmpty;
    }).toList();
    final hasSubtitles =
        _tracks.subtitle.any((t) => t.id != 'auto' && t.id != 'no') ||
        _session.externalSubtitles.isNotEmpty;

    // Estado SoLoud para audio
    final soloudState = _isAudio ? ref.watch(soloudMusicProvider) : null;
    final hasSoloud = soloudState != null && soloudState.hasItem;
    final effPlaying = hasSoloud ? soloudState.playing : _playing;
    final effCompleted = hasSoloud ? soloudState.completed : _completed;
    final effPosition = hasSoloud ? soloudState.position : _position;
    final effDuration = hasSoloud ? soloudState.duration : _duration;
    final effVolume = hasSoloud ? soloudState.volume : _volume;
    final displayPos = (_isAudio && hasSoloud && _dragging)
        ? _position
        : effPosition;

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
        if (!effPlaying && !effCompleted)
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
                          _formatDuration(displayPos),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: effDuration.inMilliseconds > 0
                                ? effDuration.inMilliseconds / 1000
                                : 1,
                            value: displayPos.inMilliseconds > 0
                                ? (displayPos.inMilliseconds / 1000).clamp(
                                    0,
                                    effDuration.inMilliseconds / 1000,
                                  )
                                : 0,
                            onChanged: effDuration.inMilliseconds > 0
                                ? _onSliderChanged
                                : null,
                            onChangeEnd: effDuration.inMilliseconds > 0
                                ? _onSliderEnd
                                : null,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                        ),
                        Text(
                          _formatDuration(effDuration),
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
                          tooltip: effPlaying ? l10n.pause : l10n.play,
                          icon: Icon(
                            effPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          onPressed: _togglePlay,
                        ),
                        _VolumeButton(
                          volume: effVolume,
                          onChanged: (v) {
                            if (_isAudio && hasSoloud) {
                              ref
                                  .read(soloudMusicProvider.notifier)
                                  .setVolume(v);
                            } else {
                              setState(() => _volume = v);
                              _player.setVolume(v);
                              try {
                                ref
                                    .read(appVolumeProvider.notifier)
                                    .setVolume(v);
                              } catch (_) {}
                            }
                          },
                        ),
                        const Spacer(),
                        if (hasSubtitles) ...[
                          _SubtitleButton(
                            tracks: _tracks,
                            external: _session.externalSubtitles,
                            embeddedMeta: embeddedSubMeta,
                            externalMeta: externalSubMeta,
                            selected: _selectedSubtitle,
                            onSelected: _selectSubtitle,
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (audioTracks.length > 1) ...[
                          _AudioButton(
                            tracks: audioTracks,
                            meta: jellyAudio,
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
    final mpv = _mpvAudioTracks;
    final pos = mpv.indexWhere((t) => t.id == id);
    if (pos < 0) return;
    await _player.setAudioTrack(mpv[pos]);
    // Persistencia por item: índice de stream de Jellyfin (estable entre
    // sesiones para el mismo fichero). Sin metadatos no se puede restaurar.
    try {
      final jelly = _jellyAudio;
      final streamIndex = pos < jelly.length ? jelly[pos].index : null;
      if (streamIndex != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_audioPrefKey(_session.itemId), streamIndex);
      }
    } catch (_) {}
  }

  /// Restaura el audio guardado para este item (una vez por sesión).
  /// No hace nada si solo hay una pista o no hay preferencia guardada.
  Future<void> _maybeRestoreAudio() async {
    if (_audioRestored || !mounted || _playerDisposed) return;
    final mpv = _mpvAudioTracks;
    final jelly = _jellyAudio;
    // Sin las pistas aún (o una sola) se reintenta en el próximo evento.
    if (mpv.length < 2 || jelly.isEmpty) return;
    _audioRestored = true;
    int? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getInt(_audioPrefKey(_session.itemId));
    } catch (_) {
      return;
    }
    if (saved == null || !mounted || _playerDisposed) return;
    final pos = jelly.indexWhere((s) => s.index == saved);
    if (pos < 0 || pos >= mpv.length) return;
    if (_selectedAudio?.id == mpv[pos].id) return;
    try {
      await _player.setAudioTrack(mpv[pos]);
    } catch (_) {}
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

/// Gradiente animado rápido (~900ms) que cicla entre los colores sin ocupar toda la canción.
class _FastAnimatedGradient extends StatefulWidget {
  const _FastAnimatedGradient({
    super.key,
    required this.colors,
    required this.child,
  });

  final List<Color> colors;
  final Widget child;

  @override
  State<_FastAnimatedGradient> createState() => _FastAnimatedGradientState();
}

class _FastAnimatedGradientState extends State<_FastAnimatedGradient> {
  final List<Alignment> _alignments = const [
    Alignment.bottomLeft,
    Alignment.bottomRight,
    Alignment.topRight,
    Alignment.topLeft,
  ];
  int _index = 0;
  late Color _bottomColor;
  late Color _topColor;
  Alignment _begin = Alignment.bottomLeft;
  Alignment _end = Alignment.topRight;

  Timer? _kickTimer;
  bool _kicked = false;

  @override
  void initState() {
    super.initState();
    _bottomColor = widget.colors.last;
    _topColor = widget.colors.first;
    // Un único kick inicial post-frame, no en cada build (evita !_dirty por setState durante build)
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickOnce());
  }

  void _kickOnce() {
    if (!mounted || _kicked) return;
    _kicked = true;
    // Pequeño delay para que AnimatedContainer tenga estado inicial
    _kickTimer = Timer(const Duration(milliseconds: 20), () {
      if (!mounted) return;
      setState(() {
        final shuffled = List<Color>.of(widget.colors)..shuffle();
        _bottomColor = shuffled.first;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _FastAnimatedGradient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.colors != widget.colors) {
      _kickTimer?.cancel();
      _kicked = false;
      _bottomColor = widget.colors.last;
      _topColor = widget.colors.first;
      _index = 0;
      _begin = Alignment.bottomLeft;
      _end = Alignment.topRight;
      WidgetsBinding.instance.addPostFrameCallback((_) => _kickOnce());
    }
  }

  @override
  void dispose() {
    _kickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 3500),
      onEnd: () {
        if (!mounted) return;
        setState(() {
          _index = _index + 1;
          _bottomColor = widget.colors[_index % widget.colors.length];
          _topColor = widget.colors[(_index + 1) % widget.colors.length];
          _begin = _alignments[_index % _alignments.length];
          _end = _alignments[(_index + 2) % _alignments.length];
        });
      },
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: _begin,
          end: _end,
          colors: [_bottomColor, _topColor],
        ),
      ),
      child: widget.child,
    );
  }
}

/// Fondo animado que extrae 4-5 colores predominantes de la carátula y
/// los cicla en bucle con gradiente rápido. Solo para PlayerScreen fullscreen.
/// Cuando cambia la canción/url se extrae nueva paleta y se reinicia la animación.
class _AnimatedPaletteBackground extends StatefulWidget {
  const _AnimatedPaletteBackground({
    required this.url,
    required this.fallbackColors,
    required this.child,
    this.onPalette,
  });

  final String url;
  final List<Color> fallbackColors;
  final Widget child;
  final ValueChanged<List<Color>>? onPalette;

  @override
  State<_AnimatedPaletteBackground> createState() =>
      _AnimatedPaletteBackgroundState();
}

class _AnimatedPaletteBackgroundState
    extends State<_AnimatedPaletteBackground> {
  static final Map<String, List<Color>> _cache = {};
  List<Color>? _palette;

  @override
  void initState() {
    super.initState();
    _extract();
  }

  @override
  void didUpdateWidget(covariant _AnimatedPaletteBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _extract();
    }
  }

  Future<void> _extract() async {
    final url = widget.url;
    if (url.isEmpty) {
      if (!mounted) return;
      // Diferir: _extract puede ser llamado desde didUpdateWidget (durante build)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _palette = null);
      });
      return;
    }
    if (_cache.containsKey(url)) {
      final cached = _cache[url]!;
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _palette = cached);
        widget.onPalette?.call(cached);
      });
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(200, 200),
        maximumColorCount: 20,
      );
      // Tomar los 5 colores más poblados
      final colors = palette.paletteColors.map((c) => c.color).toList();
      // Fallback si hay pocos: completar con vibrant/dominant
      if (colors.length < 2) {
        final extras = <Color?>[
          palette.dominantColor?.color,
          palette.vibrantColor?.color,
          palette.mutedColor?.color,
          palette.lightVibrantColor?.color,
          palette.darkVibrantColor?.color,
        ].whereType<Color>().toList();
        for (final c in extras) {
          if (!colors.contains(c)) colors.add(c);
          if (colors.length >= 5) break;
        }
      }
      final result = colors.take(5).toList();
      if (result.length >= 2) {
        _cache[url] = result;
        if (mounted) setState(() => _palette = result);
        widget.onPalette?.call(result);
      } else {
        if (mounted) setState(() => _palette = null);
        widget.onPalette?.call(widget.fallbackColors);
      }
    } catch (_) {
      if (mounted) setState(() => _palette = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    if (palette != null && palette.length >= 2) {
      return _FastAnimatedGradient(
        key: ValueKey(widget.url),
        colors: palette,
        child: widget.child,
      );
    }
    // Fallback animado con colores del skin mientras se extrae la paleta
    return _FastAnimatedGradient(
      key: ValueKey('fallback-${widget.fallbackColors.join()}'),
      colors: widget.fallbackColors.length >= 2
          ? widget.fallbackColors
          : [...widget.fallbackColors, widget.fallbackColors.first],
      child: widget.child,
    );
  }
}

/// Carátula del contenido cuando se reproduce solo audio (sin pista de vídeo),
/// con la onda animada entre la portada y la barra de progreso.
/// Bajo la carátula: artista → canción → álbum (resto igual).
class _AudioCover extends ConsumerStatefulWidget {
  const _AudioCover({
    required this.url,
    required this.title,
    required this.artist,
    required this.album,
    this.year,
    this.genres,
    this.logoUrl,
    this.serverUrl,
    required this.playing,
    required this.progress,
    required this.position,
    required this.duration,
    this.heroTag,
    this.onBack,
    this.onTogglePlay,
    this.onSeekChanged,
    this.onSeekEnd,
    this.onSkipBackward,
    this.onSkipForward,
    this.volume = 100,
    this.onVolumeChanged,
    this.onToggleFullscreen,
  });

  final String url;
  final String title;
  final String artist;
  final String album;
  final int? year;
  final List<String>? genres;
  final String? logoUrl;
  final String? serverUrl;
  final bool playing;
  final double progress;
  final Duration position;
  final Duration duration;
  final String? heroTag;
  final VoidCallback? onBack;

  /// Controles del modo portada (persistentes; el overlay auto-hide se oculta
  /// en ese modo).
  final VoidCallback? onTogglePlay;
  final ValueChanged<Duration>? onSeekChanged;
  final ValueChanged<Duration>? onSeekEnd;
  final VoidCallback? onSkipBackward;
  final VoidCallback? onSkipForward;
  final double volume;
  final ValueChanged<double>? onVolumeChanged;
  final VoidCallback? onToggleFullscreen;

  @override
  ConsumerState<_AudioCover> createState() => _AudioCoverState();
}

class _AudioCoverState extends ConsumerState<_AudioCover> {
  List<Color>? _palette;

  bool _isLight(List<Color> colors) {
    if (colors.isEmpty) return false;
    final avg =
        colors.map((c) => c.computeLuminance()).reduce((a, b) => a + b) /
        colors.length;
    return avg > 0.5;
  }

  @override
  void initState() {
    super.initState();
    // Auto-EQ inicial al abrir la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeApplyAutoEq(showFeedback: false);
    });
  }

  void _maybeApplyAutoEq({bool showFeedback = true}) {
    try {
      final eq = ref.read(audioEqProvider);
      if (!eq.autoEq) return;
      final applied = ref
          .read(audioEqProvider.notifier)
          .applyAutoEqForGenres(widget.genres);
      if (showFeedback && mounted) {
        // Solo avisar si ha habido cambio real de canción (lo llama
        // didUpdateWidget) o si hay coincidencia en la apertura.
        if (applied != null) {
          showAutoEqFeedback(context, applied);
        } else if (oldGenresKey != _genresKey(widget.genres)) {
          showAutoEqFeedback(context, null);
        }
      }
    } catch (_) {}
  }

  String _genresKey(List<String>? g) =>
      (g ?? const []).map((e) => e.trim().toLowerCase()).join('|');
  String? oldGenresKey;

  @override
  void didUpdateWidget(covariant _AudioCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      // No setState aquí: didUpdateWidget corre dentro del update del parent
      // y setState marcaría dirty durante el build -> !_dirty
      _palette = null;
    }
    if (oldWidget.url != widget.url ||
        _genresKey(oldWidget.genres) != _genresKey(widget.genres)) {
      oldGenresKey = _genresKey(oldWidget.genres);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeApplyAutoEq(showFeedback: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = ref.watch(skinControllerProvider).value;
    final musicSkin = ref.watch(musicPlayerSkinControllerProvider).value;
    final bgTop =
        musicSkin?.backgroundTop ??
        skin?.backgroundTop ??
        const Color(0xFF0B1030);
    final bgBottom =
        musicSkin?.backgroundBottom ??
        skin?.backgroundBottom ??
        const Color(0xFF1A2568);
    final accent = musicSkin?.accent ?? skin?.accent ?? const Color(0xFF2B7FFF);
    final waveform =
        musicSkin?.waveformEffect ??
        skin?.audioWaveformEffect ??
        AudioWaveformEffect.equalizer;
    // Color de texto inverso según fondo: claro→oscuro, oscuro→claro
    final fallbackColors = [bgTop, bgBottom];
    final effectivePalette = _palette ?? fallbackColors;
    final light = _isLight(effectivePalette);
    final textPrimary = light ? Colors.black : Colors.white;
    final textSecondary = light ? Colors.black87 : Colors.white70;
    final viewMode = ref.watch(playerViewModeProvider);
    final isEffects = viewMode == PlayerViewMode.effects;
    final showLyrics = viewMode == PlayerViewMode.lyrics;
    // Modo portada: layout propio persistente, sin onda de efectos.
    final isCover = !isEffects && !showLyrics;
    // Fondo animado con colores de la carátula; fallback a colores del skin.
    return _AnimatedPaletteBackground(
      url: widget.url,
      fallbackColors: fallbackColors,
      onPalette: (colors) {
        if (!mounted) return;
        setState(() => _palette = colors);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (isCover)
            Positioned.fill(
              child: _buildCoverLayout(
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent,
              ),
            )
          else if (showLyrics)
            Positioned.fill(
              child: _buildLyricsLayout(
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent,
              ),
            )
          else
            Positioned.fill(
              child: _buildEffectsLayout(
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                accent: accent,
                waveform: waveform,
              ),
            ),
        ],
      ),
    );
  }

  /// Layout del modo portada (foto de referencia): atrás arriba-izquierda,
  /// carátula grande centrada, artista/título/álbum·año, tiempos + barra de
  /// progreso con seek y fila de controles persistentes.
  Widget _buildCoverLayout({
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
  }) {
    final albumLine = [
      if (widget.album.isNotEmpty) widget.album,
      if (widget.year != null) '${widget.year}',
    ].join(' · ');
    // Degradado de la barra: acento hacia una versión más clara.
    final accentHsl = HSLColor.fromColor(accent);
    final accentLight = accentHsl
        .withLightness((accentHsl.lightness + 0.28).clamp(0.0, 1.0))
        .toColor();
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          children: [
            // Barra superior: solo atrás (la pill vive en el parent, derecha).
            Row(
              children: [
                _CoverDarkButton(icon: Icons.arrow_back, onTap: widget.onBack),
              ],
            ),
            const SizedBox(height: 8),
            // Carátula + textos, centrados en el espacio libre.
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTogglePlay,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = math
                        .min(
                          constraints.maxWidth * 0.62,
                          constraints.maxHeight - 132,
                        )
                        .clamp(200.0, 540.0)
                        .toDouble();
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  blurRadius: 40,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              widget.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _CoverFallback(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (widget.artist.isNotEmpty ||
                              widget.logoUrl != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: _ArtistLogoOrName(
                                artist: widget.artist,
                                serverUrl: widget.serverUrl,
                                trackLogoUrl: widget.logoUrl,
                                accent: accent,
                                height: 64,
                                fontSize: 14,
                                center: true,
                              ),
                            ),
                          if (widget.title.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                          if (albumLine.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                albumLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Tiempos + progreso con seek.
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    _formatCoverDuration(widget.position),
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: _CoverProgressBar(
                    progress: widget.progress,
                    duration: widget.duration,
                    fillStart: accent,
                    fillEnd: accentLight,
                    onSeekChanged: widget.onSeekChanged,
                    onSeekEnd: widget.onSeekEnd,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    _formatCoverDuration(widget.duration),
                    textAlign: TextAlign.right,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Controles persistentes.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    _CoverDarkButton(
                      icon: Icons.skip_previous_rounded,
                      onTap: widget.onSkipBackward,
                    ),
                    const SizedBox(width: 10),
                    _CoverPlayButton(
                      playing: widget.playing,
                      onTap: widget.onTogglePlay,
                    ),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      icon: Icons.skip_next_rounded,
                      onTap: widget.onSkipForward,
                    ),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      customChild: _VolumeButton(
                        volume: widget.volume,
                        onChanged: widget.onVolumeChanged ?? (_) {},
                      ),
                    ),
                    const Spacer(),
                    AutoEqToggleButton(genres: widget.genres),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      icon: Icons.equalizer_rounded,
                      onTap: () =>
                          ref.read(eqDrawerOpenProvider.notifier).open(),
                    ),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      icon: Icons.fullscreen_rounded,
                      onTap: widget.onToggleFullscreen,
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

  /// Layout modo Letra: cover izquierda + cabecera artista/título + lista de letra scrolleable (foto referencia).
  Widget _buildLyricsLayout({
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
  }) {
    final albumLine = widget.album.isNotEmpty ? widget.album : '';
    final trackTitle = widget.title;
    final artist = widget.artist;
    final accentHsl = HSLColor.fromColor(accent);
    final accentLight = accentHsl
        .withLightness((accentHsl.lightness + 0.28).clamp(0.0, 1.0))
        .toColor();
    final breadcrumb = [
      if (albumLine.isNotEmpty) albumLine,
      if (trackTitle.isNotEmpty) trackTitle,
    ].join(' · ');
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          children: [
            // Top bar: atrás + breadcrumb (la pill va en el parent, derecha).
            Row(
              children: [
                _CoverDarkButton(icon: Icons.arrow_back, onTap: widget.onBack),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    breadcrumb.isNotEmpty ? breadcrumb : trackTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 140),
              ],
            ),
            const SizedBox(height: 16),
            // Zona central: cover izq + letra der — tap en cover o letras hace play/pause
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTogglePlay,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Cover izquierda
                    Flexible(
                      flex: 4,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 380,
                            maxHeight: 380,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    blurRadius: 32,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white10,
                                  width: 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                widget.url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _CoverFallback(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Columna derecha: cabecera + letra
                    Flexible(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (artist.isNotEmpty || widget.logoUrl != null)
                            _ArtistLogoOrName(
                              artist: artist,
                              serverUrl: widget.serverUrl,
                              trackLogoUrl: widget.logoUrl,
                              accent: accent,
                              height: 66,
                              fontSize: 13,
                              center: false,
                            ),
                          if (trackTitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              trackTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          // Lista de letra
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) {
                                final query = LrcQuery(
                                  artist: widget.artist,
                                  track: widget.title,
                                  album: widget.album,
                                  duration: widget.duration.inSeconds > 0
                                      ? widget.duration
                                      : null,
                                );
                                final async = ref.watch(
                                  lrcLyricsProvider(query),
                                );
                                return async.when(
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white54,
                                    ),
                                  ),
                                  error: (_, _) => const SizedBox.shrink(),
                                  data: (result) {
                                    if (result == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return _CoverLyricsView(
                                      result: result,
                                      position: widget.position,
                                      accent: accent,
                                      textPrimary: textPrimary,
                                      textSecondary: textSecondary,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Barra de progreso y controles (igual que Portada)
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    _formatCoverDuration(widget.position),
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: _CoverProgressBar(
                    progress: widget.progress,
                    duration: widget.duration,
                    fillStart: accent,
                    fillEnd: accentLight,
                    onSeekChanged: widget.onSeekChanged,
                    onSeekEnd: widget.onSeekEnd,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    _formatCoverDuration(widget.duration),
                    textAlign: TextAlign.right,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    _CoverDarkButton(
                      icon: Icons.skip_previous_rounded,
                      onTap: widget.onSkipBackward,
                    ),
                    const SizedBox(width: 10),
                    _CoverPlayButton(
                      playing: widget.playing,
                      onTap: widget.onTogglePlay,
                    ),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      icon: Icons.skip_next_rounded,
                      onTap: widget.onSkipForward,
                    ),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      customChild: _VolumeButton(
                        volume: widget.volume,
                        onChanged: widget.onVolumeChanged ?? (_) {},
                      ),
                    ),
                    const Spacer(),
                    AutoEqToggleButton(genres: widget.genres),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      icon: Icons.equalizer_rounded,
                      onTap: () =>
                          ref.read(eqDrawerOpenProvider.notifier).open(),
                    ),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      icon: Icons.fullscreen_rounded,
                      onTap: widget.onToggleFullscreen,
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

  /// Layout modo Efectos: panel de onda grande tipo cristal + fila mini cover + selector + barra progreso.
  Widget _buildEffectsLayout({
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required AudioWaveformEffect waveform,
  }) {
    final accentHsl = HSLColor.fromColor(accent);
    final accentLight = accentHsl
        .withLightness((accentHsl.lightness + 0.28).clamp(0.0, 1.0))
        .toColor();
    final breadcrumb = [
      if (widget.album.isNotEmpty) widget.album,
      if (widget.title.isNotEmpty) widget.title,
    ].join(' · ');
    // Efecto actual viene del skin de música / skin global (mismo que Apariencia).
    final musicSkin = ref.watch(musicPlayerSkinControllerProvider).value;
    final skin = ref.watch(skinControllerProvider).value;
    final currentEffect =
        musicSkin?.waveformEffect ?? skin?.audioWaveformEffect ?? waveform;
    final displayEffect = currentEffect;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          children: [
            Row(
              children: [
                _CoverDarkButton(icon: Icons.arrow_back, onTap: widget.onBack),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    breadcrumb.isNotEmpty ? breadcrumb : widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 140),
              ],
            ),
            const SizedBox(height: 16),
            // Panel grande de efectos (cristal) — tap para play/pause (reducido)
            Expanded(
              flex: 4,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTogglePlay,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: _AudioWaveform(
                      playing: widget.playing,
                      progress: widget.progress,
                      effect: displayEffect,
                      color: accent,
                      expanded: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Fila mini cover + selector — más alta
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 156,
                    height: 156,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      widget.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _CoverFallback(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: _ArtistLogoOrName(
                            artist: widget.artist,
                            serverUrl: widget.serverUrl,
                            trackLogoUrl: widget.logoUrl,
                            accent: accent,
                            height: 44,
                            fontSize: 12,
                            center: false,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (widget.album.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                            ),
                            child: Text(
                              widget.album,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Consumer(
                    builder: (context, ref, _) {
                      final l10n = AppLocalizations.of(context)!;
                      final mSkin = ref
                          .watch(musicPlayerSkinControllerProvider)
                          .value;
                      final s = ref.watch(skinControllerProvider).value;
                      final cur =
                          mSkin?.waveformEffect ??
                          s?.audioWaveformEffect ??
                          waveform;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AudioWaveformEffect>(
                            value: cur,
                            dropdownColor: const Color(0xFF1A2568),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white70,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            items: [
                              for (final entry in [
                                (
                                  AudioWaveformEffect.equalizer,
                                  l10n.effectEqualizer,
                                ),
                                (AudioWaveformEffect.wave, l10n.effectWave),
                                (AudioWaveformEffect.mirror, l10n.effectMirror),
                                (AudioWaveformEffect.bars, l10n.effectBars),
                                (AudioWaveformEffect.surfer, l10n.effectSurfer),
                                (
                                  AudioWaveformEffect.audioFlux,
                                  l10n.effectAudioFlux,
                                ),
                                (
                                  AudioWaveformEffect.frequency,
                                  l10n.effectFrequency,
                                ),
                                (
                                  AudioWaveformEffect.ledSpectrum,
                                  l10n.effectLedSpectrum,
                                ),
                                (
                                  AudioWaveformEffect.soundEclipse,
                                  l10n.effectSoundEclipse,
                                ),
                                (
                                  AudioWaveformEffect.soundSinus,
                                  l10n.effectSoundSinus,
                                ),
                                (
                                  AudioWaveformEffect.raymarching,
                                  l10n.effectRaymarching,
                                ),
                                (
                                  AudioWaveformEffect.smokeRings,
                                  l10n.effectSmokeRings,
                                ),
                                (
                                  AudioWaveformEffect.circularSpectrum,
                                  l10n.effectCircularSpectrum,
                                ),
                              ])
                                DropdownMenuItem(
                                  value: entry.$1,
                                  child: Text(
                                    entry.$2,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              final ms = ref
                                  .read(musicPlayerSkinControllerProvider)
                                  .value;
                              if (ms != null) {
                                ref
                                    .read(
                                      musicPlayerSkinControllerProvider
                                          .notifier,
                                    )
                                    .apply(ms.copyWith(waveformEffect: v));
                              } else {
                                // Si aún no hay skin de música, aplicar preset con el efecto elegido.
                                ref
                                    .read(
                                      musicPlayerSkinControllerProvider
                                          .notifier,
                                    )
                                    .apply(
                                      MusicPlayerSkinPresets.jellyfinClassic
                                          .copyWith(waveformEffect: v),
                                    );
                              }
                              final sk = ref.read(skinControllerProvider).value;
                              if (sk != null) {
                                ref
                                    .read(skinControllerProvider.notifier)
                                    .apply(sk.copyWith(audioWaveformEffect: v));
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    _formatCoverDuration(widget.position),
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
                Expanded(
                  child: _CoverProgressBar(
                    progress: widget.progress,
                    duration: widget.duration,
                    fillStart: accent,
                    fillEnd: accentLight,
                    onSeekChanged: widget.onSeekChanged,
                    onSeekEnd: widget.onSeekEnd,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    _formatCoverDuration(widget.duration),
                    textAlign: TextAlign.right,
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  children: [
                    _CoverDarkButton(
                      icon: Icons.skip_previous_rounded,
                      onTap: widget.onSkipBackward,
                    ),
                    const SizedBox(width: 10),
                    _CoverPlayButton(
                      playing: widget.playing,
                      onTap: widget.onTogglePlay,
                    ),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      icon: Icons.skip_next_rounded,
                      onTap: widget.onSkipForward,
                    ),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      customChild: _VolumeButton(
                        volume: widget.volume,
                        onChanged: widget.onVolumeChanged ?? (_) {},
                      ),
                    ),
                    const Spacer(),
                    AutoEqToggleButton(genres: widget.genres),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      icon: Icons.equalizer_rounded,
                      onTap: () =>
                          ref.read(eqDrawerOpenProvider.notifier).open(),
                    ),
                    const SizedBox(width: 10),
                    _CoverDarkButton(
                      icon: Icons.fullscreen_rounded,
                      onTap: widget.onToggleFullscreen,
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

/// Botón cuadrado oscuro del modo portada (atrás, prev/next, volumen).
class _CoverDarkButton extends StatelessWidget {
  const _CoverDarkButton({this.icon, this.customChild, this.onTap});

  final IconData? icon;
  final Widget? customChild;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content =
        customChild ??
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 26),
          onPressed: onTap,
        );
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: content),
    );
  }
}

/// Play/pausa grande del modo portada: pastilla blanca con icono negro.
class _CoverPlayButton extends StatelessWidget {
  const _CoverPlayButton({required this.playing, this.onTap});

  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 62,
          height: 62,
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.black,
            size: 34,
          ),
        ),
      ),
    );
  }
}

/// Barra fina de progreso del modo portada con seek por tap/arrastre.
class _CoverProgressBar extends StatefulWidget {
  const _CoverProgressBar({
    required this.progress,
    required this.duration,
    required this.fillStart,
    required this.fillEnd,
    this.onSeekChanged,
    this.onSeekEnd,
  });

  final double progress;
  final Duration duration;
  final Color fillStart;
  final Color fillEnd;
  final ValueChanged<Duration>? onSeekChanged;
  final ValueChanged<Duration>? onSeekEnd;

  @override
  State<_CoverProgressBar> createState() => _CoverProgressBarState();
}

class _CoverProgressBarState extends State<_CoverProgressBar> {
  double? _dragFraction;

  Duration _at(double fraction) {
    final ms = (widget.duration.inMilliseconds * fraction.clamp(0.0, 1.0))
        .round();
    return Duration(milliseconds: ms);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double toFraction(double dx) => (dx / width).clamp(0.0, 1.0);
        final shown = _dragFraction ?? widget.progress.clamp(0.0, 1.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final at = _at(toFraction(d.localPosition.dx));
            widget.onSeekChanged?.call(at);
            widget.onSeekEnd?.call(at);
          },
          onHorizontalDragStart: (d) {
            final f = toFraction(d.localPosition.dx);
            setState(() => _dragFraction = f);
            widget.onSeekChanged?.call(_at(f));
          },
          onHorizontalDragUpdate: (d) {
            final f = toFraction(d.localPosition.dx);
            setState(() => _dragFraction = f);
            widget.onSeekChanged?.call(_at(f));
          },
          onHorizontalDragEnd: (_) {
            final f = _dragFraction ?? widget.progress;
            setState(() => _dragFraction = null);
            widget.onSeekEnd?.call(_at(f));
          },
          onHorizontalDragCancel: () => setState(() => _dragFraction = null),
          child: SizedBox(
            height: 24,
            child: Center(
              child: Container(
                height: 5,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: shown,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [widget.fillStart, widget.fillEnd],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatCoverDuration(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Lista de letra estilo Portada/Letra (foto referencia): activa blanca con barra lateral cyan.
class _CoverLyricsView extends StatefulWidget {
  const _CoverLyricsView({
    required this.result,
    required this.position,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  final LrcResult result;
  final Duration position;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  @override
  State<_CoverLyricsView> createState() => _CoverLyricsViewState();
}

class _CoverLyricsViewState extends State<_CoverLyricsView> {
  final ScrollController _controller = ScrollController();
  int _current = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant _CoverLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted) return;
    final lines = widget.result.syncedLines;
    if (lines == null || lines.isEmpty) return;
    int idx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (widget.position >= lines[i].time) idx = i;
    }
    if (idx != _current) {
      setState(() => _current = idx);
      if (idx >= 0 && _controller.hasClients) {
        final off = (idx * 36.0 - 80).clamp(
          0.0,
          _controller.position.maxScrollExtent,
        );
        _controller.animateTo(
          off,
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeInOutCubic,
        );
      } else if (idx >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_controller.hasClients) return;
          final off = (idx * 36.0 - 80).clamp(
            0.0,
            _controller.position.maxScrollExtent,
          );
          _controller.animateTo(
            off,
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeInOutCubic,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result.isInstrumental) {
      return Center(
        child: Text(
          'Instrumental',
          style: TextStyle(
            color: widget.textSecondary,
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final synced = widget.result.syncedLines;
    if (synced == null || synced.isEmpty) {
      return Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        thickness: 3,
        radius: const Radius.circular(8),
        child: SingleChildScrollView(
          controller: _controller,
          padding: const EdgeInsets.only(right: 12, left: 4, top: 4, bottom: 4),
          child: SelectableText(
            widget.result.plainLyrics,
            style: TextStyle(
              color: widget.textPrimary.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ),
      );
    }
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      thickness: 3,
      radius: const Radius.circular(8),
      child: ListView.builder(
        controller: _controller,
        padding: const EdgeInsets.only(right: 12),
        itemCount: synced.length,
        itemBuilder: (context, i) {
          final line = synced[i];
          final active = i == _current;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: _CoverLyricLine(
              text: line.text,
              active: active,
              accent: widget.accent,
              textPrimary: widget.textPrimary,
              textSecondary: widget.textSecondary,
            ),
          );
        },
      ),
    );
  }
}

class _CoverLyricLine extends StatelessWidget {
  const _CoverLyricLine({
    required this.text,
    required this.active,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  final String text;
  final bool active;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return Text(
        text,
        style: TextStyle(
          color: textSecondary.withValues(alpha: 0.62),
          fontSize: 18,
          fontWeight: FontWeight.w500,
          height: 1.35,
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo del artista si existe, si no el nombre. Intenta primero el logo del track,
/// si no, busca la entidad de artista Jellyfin y muestra su Logo (no Primary).
class _ArtistLogoOrName extends ConsumerWidget {
  const _ArtistLogoOrName({
    required this.artist,
    required this.serverUrl,
    this.trackLogoUrl,
    required this.accent,
    this.height = 28,
    this.fontSize = 13,
    this.center = true,
  });

  final String artist;
  final String? serverUrl;
  final String? trackLogoUrl;
  final Color accent;
  final double height;
  final double fontSize;
  final bool center;

  Widget _text() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 0.0),
    child: Text(
      artist,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: accent,
        fontSize: fontSize,
        fontWeight: center ? FontWeight.w600 : FontWeight.w700,
        letterSpacing: center ? 0 : 0.2,
      ),
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _artistFromEntity(ref);
  }

  Widget _artistFromEntity(WidgetRef ref) {
    if (artist.trim().isEmpty) return const SizedBox.shrink();
    if (serverUrl == null || serverUrl!.isEmpty) return _fallbackTrackOrText();
    final async = ref.watch(artistEntityByNameProvider(artist));
    return async.when(
      data: (entity) {
        if (entity != null) {
          final logoUrl = itemLogoUrl(serverUrl!, entity);
          if (logoUrl != null) {
            return Image.network(
              logoUrl,
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _fallbackTrackOrText(),
            );
          }
        }
        return _fallbackTrackOrText();
      },
      loading: () => _fallbackTrackOrText(),
      error: (_, _) => _fallbackTrackOrText(),
    );
  }

  Widget _fallbackTrackOrText() {
    if (trackLogoUrl != null && trackLogoUrl!.isNotEmpty) {
      return Image.network(
        trackLogoUrl!,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _text(),
      );
    }
    return _text();
  }
}

/// Onda animada del reproductor de audio: dibuja [AudioWaveformEffect] con un
/// [CustomPainter] propio. Se mueve mientras suena y se congela al pausar.
/// Incluye efecto audioFlux via audio_flux + SoLoud.
class _AudioWaveform extends ConsumerStatefulWidget {
  const _AudioWaveform({
    required this.playing,
    required this.progress,
    required this.effect,
    required this.color,
    this.expanded = false,
  });

  final bool playing;
  final double progress;
  final AudioWaveformEffect effect;
  final Color color;
  final bool expanded;

  @override
  ConsumerState<_AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends ConsumerState<_AudioWaveform>
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
    if (widget.expanded) {
      if (widget.effect == AudioWaveformEffect.frequency) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: _WaveformPainter(
                  effect: AudioWaveformEffect.equalizer,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: widget.color.withValues(alpha: 0.18),
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        // Efecto frequency FFT rainbow mirrored con reflejo — imagen de referencia
        // Menos alto: centrado con altura fija para no ocupar todo el full bleed
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
          child: Center(
            child: SizedBox(
              height: 540,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _FrequencyVisualizer(),
              ),
            ),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.audioFlux) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: _WaveformPainter(
                  effect: AudioWaveformEffect.equalizer,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: widget.color.withValues(alpha: 0.18),
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AudioFlux(
              dataSource: DataSources.soloud,
              fluxType: FluxType.waveform,
              modelParams: ModelParams(
                backgroundColor: Colors.transparent,
                barColor: widget.color,
                barGradient: LinearGradient(
                  colors: [widget.color, widget.color.withValues(alpha: 0.6)],
                ),
                audioScale: 1.6,
                fftParams: const FftParams(
                  minBinIndex: 1,
                  maxBinIndex: 120,
                  fftSmoothing: 0.85,
                ),
                waveformParams: const WaveformPainterParams(
                  barsWidth: 3,
                  barSpacingScale: 0.5,
                  chunkSize: 1,
                ),
              ),
            ),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.ledSpectrum) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: _WaveformPainter(
                  effect: AudioWaveformEffect.equalizer,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: widget.color.withValues(alpha: 0.18),
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: LedSpectrumVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.soundEclipse) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: _WaveformPainter(
                  effect: AudioWaveformEffect.equalizer,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: widget.color.withValues(alpha: 0.18),
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: SoundEclipseVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.soundSinus) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: _WaveformPainter(
                  effect: AudioWaveformEffect.equalizer,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: widget.color.withValues(alpha: 0.18),
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: SoundSinusVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.raymarching) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: _WaveformPainter(
                  effect: AudioWaveformEffect.equalizer,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: widget.color.withValues(alpha: 0.18),
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: RaymarchVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.smokeRings) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: _WaveformPainter(
                  effect: AudioWaveformEffect.equalizer,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: widget.color.withValues(alpha: 0.18),
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: SmokeRingsVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.circularSpectrum) {
        final soloudReady = SoloudInitializer.isInitialized;
        final soloudState = ref.watch(soloudMusicProvider);
        final hasSoloudPlaying =
            soloudReady && soloudState.isSoloud && soloudState.playing;
        if (!soloudReady || !hasSoloudPlaying) {
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _explosionController]),
            builder: (context, _) => SizedBox.expand(
              child: CustomPaint(
                painter: _WaveformPainter(
                  effect: AudioWaveformEffect.equalizer,
                  phase: _controller.value,
                  progress: widget.progress,
                  color: widget.color,
                  trackColor: widget.color.withValues(alpha: 0.18),
                  explosion: _explosionController.value,
                ),
              ),
            ),
          );
        }
        return const SizedBox.expand(
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            child: CircularSpectrumVisualizer(),
          ),
        );
      }
      if (widget.effect == AudioWaveformEffect.surfer) {
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox.expand(
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
        builder: (context, _) => SizedBox.expand(
          child: CustomPaint(
            painter: _WaveformPainter(
              effect: widget.effect,
              phase: _controller.value,
              progress: widget.progress,
              color: widget.color,
              trackColor: widget.color.withValues(alpha: 0.18),
              explosion: _explosionController.value,
            ),
          ),
        ),
      );
    }
    // Nuevo efecto audioFlux via SoLoud + audio_flux (waveform real)
    if (widget.effect == AudioWaveformEffect.audioFlux) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      // Fallback sintético si SoLoud no está sonando (ej. HLS fallback a MediaKit)
      if (!soloudReady || !hasSoloudPlaying) {
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 52,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                effect: AudioWaveformEffect.equalizer,
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
      return SizedBox(
        height: 52,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AudioFlux(
            dataSource: DataSources.soloud,
            fluxType: FluxType.waveform,
            modelParams: ModelParams(
              backgroundColor: Colors.transparent,
              barColor: widget.color,
              barGradient: LinearGradient(
                colors: [widget.color, widget.color.withValues(alpha: 0.6)],
              ),
              audioScale: 1.4,
              fftParams: const FftParams(
                minBinIndex: 1,
                maxBinIndex: 120,
                fftSmoothing: 0.85,
              ),
              waveformParams: const WaveformPainterParams(
                barsWidth: 3,
                barSpacingScale: 0.5,
                chunkSize: 1,
              ),
            ),
          ),
        ),
      );
    }
    // Nuevo efecto frequency (FFT rainbow mirrored con reflejo) — imagen de referencia
    if (widget.effect == AudioWaveformEffect.frequency) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                effect: AudioWaveformEffect.equalizer,
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
      return SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _FrequencyVisualizer(),
        ),
      );
    }
    // Espectro LED 2D con FFT real de SoLoud (FFT llega vía audio_flux/SoLoud).
    if (widget.effect == AudioWaveformEffect.ledSpectrum) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                effect: AudioWaveformEffect.equalizer,
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
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: LedSpectrumVisualizer(),
        ),
      );
    }
    // Eclipse sonoro con FFT real de SoLoud.
    if (widget.effect == AudioWaveformEffect.soundEclipse) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                effect: AudioWaveformEffect.equalizer,
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
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: SoundEclipseVisualizer(),
        ),
      );
    }
    // Onda sinus con FFT real de SoLoud.
    if (widget.effect == AudioWaveformEffect.soundSinus) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                effect: AudioWaveformEffect.equalizer,
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
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: SoundSinusVisualizer(),
        ),
      );
    }
    // Sala raymarcheada con FFT + onda reales de SoLoud.
    if (widget.effect == AudioWaveformEffect.raymarching) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                effect: AudioWaveformEffect.equalizer,
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
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: RaymarchVisualizer(),
        ),
      );
    }
    // Anillos de humo con FFT real de SoLoud.
    if (widget.effect == AudioWaveformEffect.smokeRings) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                effect: AudioWaveformEffect.equalizer,
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
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: SmokeRingsVisualizer(),
        ),
      );
    }
    // Espectro circular con FFT real de SoLoud.
    if (widget.effect == AudioWaveformEffect.circularSpectrum) {
      final soloudReady = SoloudInitializer.isInitialized;
      final soloudState = ref.watch(soloudMusicProvider);
      final hasSoloudPlaying =
          soloudReady && soloudState.isSoloud && soloudState.playing;
      if (!soloudReady || !hasSoloudPlaying) {
        return AnimatedBuilder(
          animation: Listenable.merge([_controller, _explosionController]),
          builder: (context, _) => SizedBox(
            height: 72,
            width: double.infinity,
            child: CustomPaint(
              painter: _WaveformPainter(
                effect: AudioWaveformEffect.equalizer,
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
      return const SizedBox(
        height: 130,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(6)),
          child: CircularSpectrumVisualizer(),
        ),
      );
    }
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

/// Visualizador de frecuencia FFT simétrico estilo Winamp/LED con reflejo.
/// Simetría horizontal: graves en el centro, agudos en los extremos (espejado como imagen).
/// Usa SoLoud FFT directo y pinta barras arcoíris con reflejo vertical atenuado.
class _FrequencyVisualizer extends StatefulWidget {
  const _FrequencyVisualizer();

  @override
  State<_FrequencyVisualizer> createState() => _FrequencyVisualizerState();
}

class _FrequencyVisualizerState extends State<_FrequencyVisualizer> {
  StreamSubscription? _sub;
  Float32List _fft = Float32List(256);

  @override
  void initState() {
    super.initState();
    try {
      SoLoud.instance.setVisualizationEnabled(true);
    } catch (_) {}
    _sub = SoLoud.instance.audioVisualizationEvents.listen((data) {
      if (data.fftData != null && mounted) {
        setState(() => _fft = data.fftData!);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _SymmetricFftPainter(fft: _fft, audioScale: 1),
    );
  }
}

class _SymmetricFftPainter extends CustomPainter {
  _SymmetricFftPainter({required this.fft, this.audioScale = 2.2});
  final Float32List fft;
  final double audioScale;
  static const int barCount = 64;
  static const double barSpacingScale = 0.28;
  static const double barRadius = 2.0;
  static const List<Color> rainbow = [
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFFFDD835),
    Color(0xFF8BC34A),
    Color(0xFF26C6DA),
    Color(0xFF42A5F5),
    Color(0xFF7E57C2),
    Color(0xFFEC407A),
  ];

  Color _colorAt(double t) {
    final scaled = t * (rainbow.length - 1);
    final idx = scaled.floor().clamp(0, rainbow.length - 2);
    final frac = scaled - idx;
    return Color.lerp(rainbow[idx], rainbow[idx + 1], frac)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final half = barCount ~/ 2;
    final range = fft.length.clamp(1, 256);
    final chunkSize = range / half;
    final halfValues = List<double>.filled(half, 0.0);
    for (var j = 0; j < half; j++) {
      final start = (j * chunkSize).floor().clamp(0, range - 1);
      final end = ((j + 1) * chunkSize).ceil().clamp(0, range);
      double sum = 0;
      int cnt = 0;
      for (var k = start; k < end && k < fft.length; k++) {
        sum += fft[k];
        cnt++;
      }
      halfValues[j] = cnt > 0 ? sum / cnt : 0.0;
    }
    final barWidth = size.width / barCount;
    final barInnerWidth = barWidth * (1.0 - barSpacingScale);
    final baseline = size.height * 0.58;
    for (var i = 0; i < barCount; i++) {
      final mirroredIdx = i < half ? (half - 1 - i) : (i - half);
      final value = halfValues[mirroredIdx.clamp(0, half - 1)];
      final clamped = value.clamp(0.0, 1.0);
      final barH = (size.height * 0.58 * clamped * audioScale).clamp(
        2.0,
        size.height * 0.58,
      );
      final x = i * barWidth + (barWidth - barInnerWidth) / 2;
      final color = _colorAt(i / (barCount - 1));
      final topRect = Rect.fromLTWH(x, baseline - barH, barInnerWidth, barH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(topRect, Radius.circular(barRadius)),
        Paint()..color = color,
      );
      final reflH = barH * 0.55;
      final reflRect = Rect.fromLTWH(x, baseline + 2, barInnerWidth, reflH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(reflRect, Radius.circular(barRadius)),
        Paint()..color = color.withValues(alpha: 0.32),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, baseline, size.width, 1),
      Paint()..color = Colors.white10,
    );
  }

  @override
  bool shouldRepaint(covariant _SymmetricFftPainter oldDelegate) => true;
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
              top: (by + 60 + bob * 0.3).clamp(0.0, h - 8),
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
      case AudioWaveformEffect.audioFlux:
        // audioFlux se renderiza con widget AudioFlux, este painter fallback a equalizer
        _paintBars(canvas, size, mirrored: false, animated: true);
      case AudioWaveformEffect.frequency:
        // frequency también usa AudioFlux FFT; fallback sintético espejado
        _paintBars(canvas, size, mirrored: true, animated: true);
      case AudioWaveformEffect.ledSpectrum:
        // ledSpectrum usa FFT real de SoLoud; fallback a equalizer
        _paintBars(canvas, size, mirrored: false, animated: true);
      case AudioWaveformEffect.soundEclipse:
        // soundEclipse usa FFT real de SoLoud; fallback a equalizer
        _paintBars(canvas, size, mirrored: false, animated: true);
      case AudioWaveformEffect.soundSinus:
        // soundSinus usa FFT real de SoLoud; fallback a equalizer
        _paintBars(canvas, size, mirrored: false, animated: true);
      case AudioWaveformEffect.raymarching:
        // raymarching usa FFT real de SoLoud; fallback a equalizer
        _paintBars(canvas, size, mirrored: false, animated: true);
      case AudioWaveformEffect.smokeRings:
        // smokeRings usa FFT real de SoLoud; fallback a equalizer
        _paintBars(canvas, size, mirrored: false, animated: true);
      case AudioWaveformEffect.circularSpectrum:
        // circularSpectrum usa FFT real de SoLoud; fallback a equalizer
        _paintBars(canvas, size, mirrored: false, animated: true);
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

/// Toggle pill 3 estados: Portada <-> Letra <-> Efectos
class _LyricsCoverToggle extends ConsumerWidget {
  const _LyricsCoverToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(playerViewModeProvider);
    // Pill estilo imagen: fondo oscuro semitransparente, segmento activo blanco.
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleSegment(
            label: l10n.cover.toUpperCase(),
            selected: mode == PlayerViewMode.cover,
            onTap: () => ref
                .read(playerViewModeProvider.notifier)
                .set(PlayerViewMode.cover),
          ),
          _ToggleSegment(
            label: l10n.lyrics.toUpperCase(),
            selected: mode == PlayerViewMode.lyrics,
            onTap: () => ref
                .read(playerViewModeProvider.notifier)
                .set(PlayerViewMode.lyrics),
          ),
          _ToggleSegment(
            label: l10n.effects.toUpperCase(),
            selected: mode == PlayerViewMode.effects,
            onTap: () => ref
                .read(playerViewModeProvider.notifier)
                .set(PlayerViewMode.effects),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  const _ToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
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
                  width: 230,
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
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${current.round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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

/// Botón de subtítulos con menú de pistas ("Idioma - Predeterminado - Formato").
class _SubtitleButton extends StatelessWidget {
  const _SubtitleButton({
    required this.tracks,
    required this.external,
    required this.embeddedMeta,
    required this.externalMeta,
    required this.selected,
    required this.onSelected,
  });

  final Tracks tracks;
  final List<SubtitleTrack> external;

  /// Metadatos de Jellyfin en el mismo orden (para las etiquetas).
  final List<MediaStream> embeddedMeta;
  final List<MediaStream> externalMeta;
  final SubtitleTrack? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasExternal = external.isNotEmpty;
    final embedded = tracks.subtitle
        .where((t) => t.id != 'auto' && t.id != 'no')
        .toList();

    // Metadatos Jellyfin > título mpv > idioma mpv > "Subtítulo N".
    String labelOf(SubtitleTrack t, MediaStream? m, int index) {
      if (m != null) {
        final parts = <String>[];
        final lang = _trackLanguageName(m.language);
        if (lang.isNotEmpty) parts.add(lang);
        if (m.isDefault == true) parts.add(l10n.audioTrackDefault);
        final format = _subtitleFormatLabel(m);
        if (format.isNotEmpty) parts.add(format);
        final label = parts.join(' - ');
        if (label.isNotEmpty) return label;
      }
      final base = t.title ?? t.language;
      if (base != null && base.isNotEmpty) return base;
      return '${l10n.subtitle} ${index + 1}';
    }

    final selectedId = selected?.id ?? 'auto';
    bool isSelected(String id, SubtitleTrack? t) {
      if (id == 'no') return selectedId == 'no';
      return t != null && t.id == selectedId;
    }

    Widget row(String id, SubtitleTrack? t, String label) {
      final sel = isSelected(id, t);
      return Container(
        color: sel ? const Color(0x2AFFFFFF) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              sel ? Icons.check_rounded : null,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: l10n.subtitle,
      offset: const Offset(0, -60),
      color: const Color(0xEE1A1A1A),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            l10n.subtitlesLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        PopupMenuItem<String>(
          value: 'no',
          child: row('no', null, l10n.subtitlesOff),
        ),
        for (var i = 0; i < embedded.length; i++)
          PopupMenuItem<String>(
            value: embedded[i].id,
            child: row(
              embedded[i].id,
              embedded[i],
              labelOf(
                embedded[i],
                i < embeddedMeta.length ? embeddedMeta[i] : null,
                i,
              ),
            ),
          ),
        if (hasExternal) const PopupMenuDivider(),
        for (var i = 0; i < external.length; i++)
          PopupMenuItem<String>(
            value: external[i].id,
            child: row(
              external[i].id,
              external[i],
              labelOf(
                external[i],
                i < externalMeta.length ? externalMeta[i] : null,
                i,
              ),
            ),
          ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.closed_caption, color: Colors.white),
      ),
    );
  }
}

/// Nombre de idioma para códigos ISO 639 (2 y 3 letras) de Jellyfin.
String _trackLanguageName(String? code) {
  if (code == null || code.isEmpty) return '';
  const names = <String, String>{
    'en': 'English',
    'eng': 'English',
    'es': 'Spanish',
    'spa': 'Spanish',
    'esp': 'Spanish',
    'fr': 'French',
    'fre': 'French',
    'fra': 'French',
    'de': 'German',
    'ger': 'German',
    'deu': 'German',
    'it': 'Italian',
    'ita': 'Italian',
    'pt': 'Portuguese',
    'por': 'Portuguese',
    'nl': 'Dutch',
    'dut': 'Dutch',
    'nld': 'Dutch',
    'ru': 'Russian',
    'rus': 'Russian',
    'ja': 'Japanese',
    'jpn': 'Japanese',
    'zh': 'Chinese',
    'chi': 'Chinese',
    'zho': 'Chinese',
    'ko': 'Korean',
    'kor': 'Korean',
    'ar': 'Arabic',
    'ara': 'Arabic',
    'hi': 'Hindi',
    'hin': 'Hindi',
    'tr': 'Turkish',
    'tur': 'Turkish',
    'pl': 'Polish',
    'pol': 'Polish',
    'sv': 'Swedish',
    'swe': 'Swedish',
    'no': 'Norwegian',
    'nor': 'Norwegian',
    'da': 'Danish',
    'dan': 'Danish',
    'fi': 'Finnish',
    'fin': 'Finnish',
    'el': 'Greek',
    'gre': 'Greek',
    'ell': 'Greek',
    'cs': 'Czech',
    'cze': 'Czech',
    'ces': 'Czech',
    'sk': 'Slovak',
    'slo': 'Slovak',
    'slk': 'Slovak',
    'hu': 'Hungarian',
    'hun': 'Hungarian',
    'ro': 'Romanian',
    'rum': 'Romanian',
    'ron': 'Romanian',
    'uk': 'Ukrainian',
    'ukr': 'Ukrainian',
    'vi': 'Vietnamese',
    'vie': 'Vietnamese',
    'th': 'Thai',
    'tha': 'Thai',
    'id': 'Indonesian',
    'ind': 'Indonesian',
    'ms': 'Malay',
    'msa': 'Malay',
    'he': 'Hebrew',
    'heb': 'Hebrew',
    'ca': 'Catalan',
    'cat': 'Catalan',
    'eu': 'Basque',
    'eus': 'Basque',
    'baq': 'Basque',
    'gl': 'Galician',
    'glg': 'Galician',
  };
  return names[code.toLowerCase()] ?? code;
}

/// Etiqueta comercial del codec de Jellyfin ("ac3" -> "Dolby Digital"...).
String _audioCodecLabel(MediaStream m) {
  final codec = (m.codec ?? '').toLowerCase();
  final profile = (m.profile ?? '').toUpperCase();
  switch (codec) {
    case 'ac3':
      return 'Dolby Digital';
    case 'eac3':
    case 'ec3':
      return 'Dolby Digital Plus';
    case 'truehd':
      return 'Dolby TrueHD';
    case 'dts':
    case 'dca':
      return 'DTS';
    case 'dtshd':
    case 'dts-hd':
    case 'dtsma':
      return 'DTS-HD MA';
    case 'aac':
      return profile.contains('HE') ? 'HE-AAC' : 'AAC';
    case 'mp3':
      return 'MP3';
    case 'flac':
      return 'FLAC';
    case 'opus':
      return 'Opus';
    case 'vorbis':
      return 'Vorbis';
    case 'alac':
      return 'ALAC';
    case 'pcm':
    case 'pcm_s16le':
    case 'pcm_s24le':
    case 'pcm_s32le':
      return 'PCM';
    case 'wmapro':
      return 'WMA Pro';
    case 'wmav2':
      return 'WMA';
    default:
      return (m.codec ?? '').toUpperCase();
  }
}

/// Formato del subtítulo de Jellyfin ("srt" -> "SUBRIP"...).
String _subtitleFormatLabel(MediaStream m) {
  switch ((m.codec ?? '').toLowerCase()) {
    case 'srt':
    case 'subrip':
      return 'SUBRIP';
    case 'ass':
      return 'ASS';
    case 'ssa':
      return 'SSA';
    case 'pgssub':
    case 'pgs':
      return 'PGS';
    case 'dvdsub':
      return 'VOBSUB';
    case 'dvbsub':
      return 'DVBSUB';
    case 'vtt':
    case 'webvtt':
      return 'VTT';
    case 'mov_text':
      return 'MOV_TEXT';
    case 'microdvd':
      return 'MicroDVD';
    default:
      return (m.codec ?? '').toUpperCase();
  }
}

/// Etiqueta de canales ("Stereo", "5.1"...).
String _audioChannelsLabel(int? channels) {
  switch (channels) {
    case 1:
      return 'Mono';
    case 2:
      return 'Stereo';
    case 6:
      return '5.1';
    case 7:
      return '6.1';
    case 8:
      return '7.1';
    default:
      return (channels != null && channels > 0) ? '$channels ch' : '';
  }
}

/// Botón de audio con menú de pistas ("Idioma - Codec - Canales").
class _AudioButton extends StatelessWidget {
  const _AudioButton({
    required this.tracks,
    required this.meta,
    required this.selected,
    required this.onSelected,
  });

  /// Pistas de mpv (las que se seleccionan).
  final List<AudioTrack> tracks;

  /// Metadatos de Jellyfin en el mismo orden (para las etiquetas).
  final List<MediaStream> meta;
  final AudioTrack? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Metadatos Jellyfin > título mpv > idioma mpv > "Audio N".
    String labelOf(AudioTrack t, int index) {
      final m = index < meta.length ? meta[index] : null;
      if (m != null) {
        final parts = <String>[];
        final lang = _trackLanguageName(m.language);
        if (lang.isNotEmpty) parts.add(lang);
        final codec = _audioCodecLabel(m);
        if (codec.isNotEmpty) parts.add(codec);
        final channels = _audioChannelsLabel(m.channels);
        if (channels.isNotEmpty) parts.add(channels);
        var label = parts.join(' - ');
        if (m.isDefault == true) {
          label = label.isEmpty
              ? l10n.audioTrackDefault
              : '$label - ${l10n.audioTrackDefault}';
        }
        if (label.isNotEmpty) return label;
      }
      final base = t.title ?? t.language;
      if (base != null && base.isNotEmpty) return base;
      return '${l10n.audio} ${index + 1}';
    }

    return PopupMenuButton<String>(
      tooltip: l10n.audio,
      offset: const Offset(0, -60),
      color: const Color(0xEE1A1A1A),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            l10n.audio,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (var i = 0; i < tracks.length; i++)
          PopupMenuItem<String>(
            value: tracks[i].id,
            child: Row(
              children: [
                Icon(
                  selected?.id == tracks[i].id ? Icons.check_rounded : null,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    labelOf(tracks[i], i),
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
