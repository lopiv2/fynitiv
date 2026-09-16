import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';
import 'package:media_kit/media_kit.dart';

import '../../library/application/image_url.dart';
import '../../player/application/playback_provider.dart';
import '../../../core/audio/soloud_initializer.dart';
import 'audio_eq_provider.dart';

/// Motor activo para playback de música.
enum PlaybackEngine { soloud, mediaKit, none }

/// Estado unificado para música (SoLoud primario, MediaKit fallback).
class SoloudMusicState {
  const SoloudMusicState({
    this.item,
    this.session,
    this.playing = false,
    this.buffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 100,
    this.error,
    this.completed = false,
    this.engine = PlaybackEngine.none,
  });

  final BaseItemDto? item;
  final PlaybackSession? session;
  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final double volume; // 0..100
  final String? error;
  final bool completed;
  final PlaybackEngine engine;

  bool get hasItem => item != null && session != null;
  bool get isSoloud => engine == PlaybackEngine.soloud;
  bool get isMediaKit => engine == PlaybackEngine.mediaKit;

  String get coverUrl {
    if (item == null || session == null) return '';
    return itemImageUrl(session!.serverUrl, item!, maxWidth: 400);
  }

  String get title => item?.name ?? session?.itemName ?? '';
  String get artist => item?.artists?.join(', ') ?? '';

  SoloudMusicState copyWith({
    BaseItemDto? item,
    PlaybackSession? session,
    bool? playing,
    bool? buffering,
    Duration? position,
    Duration? duration,
    double? volume,
    String? error,
    bool clearError = false,
    bool? completed,
    PlaybackEngine? engine,
  }) {
    return SoloudMusicState(
      item: item ?? this.item,
      session: session ?? this.session,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      error: clearError ? null : (error ?? this.error),
      completed: completed ?? this.completed,
      engine: engine ?? this.engine,
    );
  }
}

class SoloudMusicController extends Notifier<SoloudMusicState> {
  AudioSource? _source;
  SoundHandle? _handle;
  Player? _fallbackPlayer;
  final List<StreamSubscription> _fallbackSubs = [];
  Timer? _posTimer;
  Timer? _completionTimer;
  bool _disposed = false;

  bool get _soloudReady => SoloudInitializer.isInitialized && SoLoud.instance.isInitialized;

  Player get _fallback {
    _fallbackPlayer ??= Player();
    _ensureFallbackSubs();
    return _fallbackPlayer!;
  }

  void _ensureFallbackSubs() {
    if (_fallbackSubs.isNotEmpty) return;
    final p = _fallbackPlayer!;
    _fallbackSubs.add(p.stream.playing.listen((v) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(playing: v);
    }));
    _fallbackSubs.add(p.stream.position.listen((pos) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(position: pos);
    }));
    _fallbackSubs.add(p.stream.duration.listen((dur) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(duration: dur);
    }));
    _fallbackSubs.add(p.stream.buffering.listen((b) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(buffering: b);
    }));
    _fallbackSubs.add(p.stream.completed.listen((c) {
      if (_disposed || !c || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(completed: true, playing: false);
    }));
    _fallbackSubs.add(p.stream.error.listen((e) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(error: e);
    }));
    _fallbackSubs.add(p.stream.volume.listen((v) {
      if (_disposed || state.engine != PlaybackEngine.mediaKit) return;
      state = state.copyWith(volume: v);
    }));
  }

  void _stopPosTimer() {
    _posTimer?.cancel();
    _posTimer = null;
    _completionTimer?.cancel();
    _completionTimer = null;
  }

  void _startSoloudPosTimer() {
    _stopPosTimer();
    _posTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed || _handle == null || state.engine != PlaybackEngine.soloud) return;
      try {
        final pos = SoLoud.instance.getPosition(_handle!);
        final len = _source != null ? SoLoud.instance.getLength(_source!) : state.duration;
        // Detect completed: handle invalid or near end
        bool isValid = false;
        try {
          isValid = SoLoud.instance.getIsValidVoiceHandle(_handle!);
        } catch (_) {
          isValid = false;
        }
        // Si el handle ya no es válido y estábamos playing => completado
        if (!isValid && state.playing) {
          state = state.copyWith(position: len, completed: true, playing: false, buffering: false);
          _stopPosTimer();
          return;
        }
        // También detectar por posición cerca del final
        if (len > Duration.zero && pos >= len - const Duration(milliseconds: 300) && state.playing) {
          // Esperar un poco para confirmar que se detiene
        }
        state = state.copyWith(position: pos, duration: len);
      } catch (_) {}
    });
  }

  Duration? _durationFromTicks(int? ticks) {
    if (ticks == null || ticks <= 0) return null;
    return Duration(microseconds: ticks ~/ 10);
  }

  @override
  SoloudMusicState build() {
    ref.keepAlive();
    ref.onDispose(() {
      _disposed = true;
      _stopPosTimer();
      for (final s in _fallbackSubs) {
        s.cancel();
      }
      _fallbackSubs.clear();
      // No dispose SoLoud source here, se hace en stop
      try {
        _fallbackPlayer?.dispose();
      } catch (_) {}
    });
    // Reaplicar EQ cuando cambie el estado (incluido al iniciar)
    ref.listen<AudioEqState>(audioEqProvider, (prev, next) => _applyEq(next));
    return const SoloudMusicState();
  }

  void _applyEq(AudioEqState eq) {
    if (!_soloudReady || _source == null || _handle == null) return;
    if (state.engine != PlaybackEngine.soloud) return;
    try {
      final f = _source!.filters;
      // NOTA: activate() lanza SoLoudFilterAlreadyAddedException si el filtro
      // ya está añadido (solo uno de cada tipo en C++). Por eso todo activate/
      // deactivate va protegido con isActive.
      // Activar / desactivar EQ principal
      if (!eq.enabled) {
        try { final x = f.parametricEqFilter; if (x.isActive) x.deactivate(); } catch (_) {}
        try { final x = f.bassBoostFilter; if (x.isActive) x.deactivate(); } catch (_) {}
        try { final x = f.freeverbFilter; if (x.isActive) x.deactivate(); } catch (_) {}
        try { final x = f.limiterFilter; if (x.isActive) x.deactivate(); } catch (_) {}
        // Reset velocidad
        try { SoLoud.instance.setRelativePlaySpeed(_handle!, 1.0); } catch (_) {}
        return;
      }
      // --- EQ 10 bandas ---
      try {
        final eqF = f.parametricEqFilter;
        if (!eqF.isActive) eqF.activate();
        eqF.numBands(soundHandle: _handle).value = 10;
        eqF.wet(soundHandle: _handle).value = 1.0;
        for (int i = 0; i < 10; i++) {
          final g = eq.bands[i].clamp(0.0, 4.0);
          eqF.bandGain(i, soundHandle: _handle).value = g;
        }
      } catch (_) {}
      // --- Bass boost ---
      try {
        final bb = f.bassBoostFilter;
        if (eq.bassBoost) {
          if (!bb.isActive) bb.activate();
          bb.wet(soundHandle: _handle).value = 1.0;
          bb.boost(soundHandle: _handle).value = 3.0;
        } else {
          if (bb.isActive) bb.deactivate();
        }
      } catch (_) {}
      // --- Normalizar (limiter) ---
      try {
        final lim = f.limiterFilter;
        if (eq.normalize) {
          if (!lim.isActive) lim.activate();
          lim.wet(soundHandle: _handle).value = 1.0;
        } else {
          if (lim.isActive) lim.deactivate();
        }
      } catch (_) {}
      // --- Reverb ---
      try {
        final rv = f.freeverbFilter;
        if (eq.reverb == 'Ninguna') {
          if (rv.isActive) rv.deactivate();
        } else {
          if (!rv.isActive) rv.activate();
          rv.wet(soundHandle: _handle).value = 0.5;
          // Mapear preset a roomSize/damp
          double room = 0.5, damp = 0.5;
          switch (eq.reverb) {
            case 'Habitación':
              room = 0.4; damp = 0.5; break;
            case 'Catedral':
              room = 0.85; damp = 0.3; break;
            case 'Placa':
              room = 0.6; damp = 0.7; break;
            case 'Eco':
              room = 0.7; damp = 0.4; break;
          }
          rv.roomSize(soundHandle: _handle).value = room;
          rv.damp(soundHandle: _handle).value = damp;
          rv.width(soundHandle: _handle).value = 1.0;
        }
      } catch (_) {}
      // --- Velocidad ---
      try {
        SoLoud.instance.setRelativePlaySpeed(_handle!, eq.speed.clamp(0.5, 2.0));
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> playFromSession(PlaybackSession session, BaseItemDto? item, {Duration? start, double? volume}) async {
    state = state.copyWith(item: item, session: session, error: null, clearError: true, completed: false, buffering: true, volume: volume ?? state.volume);
    final isHls = session.streamUrl.contains('master.m3u8') || session.streamUrl.contains('.m3u8');

    // Intento SoLoud si no es HLS y está inicializado
    if (!isHls && _soloudReady) {
      try {
        // Limpiar fallback si estaba activo
        try {
          await _fallbackPlayer?.stop();
        } catch (_) {}
        // Limpiar soloud previo
        if (_handle != null) {
          try {
            SoLoud.instance.stop(_handle!);
          } catch (_) {}
          _handle = null;
        }
        if (_source != null) {
          try {
            SoLoud.instance.disposeSource(_source!);
          } catch (_) {}
          _source = null;
        }
        _stopPosTimer();

        // Habilitar visualización
        try {
          SoLoud.instance.setVisualizationEnabled(true);
        } catch (_) {}

        _source = await SoLoud.instance.loadUrl(session.streamUrl);
        final vol = (volume ?? state.volume).clamp(0, 100) / 100.0;
        _handle = SoLoud.instance.play(_source!, volume: vol);

        Duration? startPos = start ??
            (session.start != null && session.start! > Duration.zero ? session.start : null) ??
            _durationFromTicks(item?.userData?.playbackPositionTicks);

        if (startPos != null && startPos > Duration.zero) {
          try {
            SoLoud.instance.seek(_handle!, startPos);
          } catch (_) {}
        }

        Duration dur = Duration.zero;
        try {
          dur = SoLoud.instance.getLength(_source!);
        } catch (_) {}

        state = state.copyWith(playing: true, buffering: false, completed: false, duration: dur, engine: PlaybackEngine.soloud, volume: volume ?? state.volume);
        _startSoloudPosTimer();
        // Aplicar EQ / filtros actuales al nuevo handle
        try { _applyEq(ref.read(audioEqProvider)); } catch (_) {}
        return;
      } catch (e) {
        // Fallback a MediaKit: limpiar soloud parcial
        if (_handle != null) {
          try {
            SoLoud.instance.stop(_handle!);
          } catch (_) {}
          _handle = null;
        }
        if (_source != null) {
          try {
            SoLoud.instance.disposeSource(_source!);
          } catch (_) {}
          _source = null;
        }
        // Continuar a fallback
      }
    }

    // Fallback MediaKit (HLS o error SoLoud)
    try {
      final p = _fallback;
      if (volume != null) {
        try {
          await p.setVolume(volume);
        } catch (_) {}
      }
      await p.open(
        Media(
          session.streamUrl,
          httpHeaders: const {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
          },
        ),
      );
      await p.play();
      final startPos = start ?? (session.start != null && session.start! > Duration.zero ? session.start : null) ?? _durationFromTicks(item?.userData?.playbackPositionTicks);
      if (startPos != null && startPos > Duration.zero) {
        try {
          await p.stream.duration.firstWhere((d) => d > Duration.zero).timeout(const Duration(seconds: 5));
        } catch (_) {}
        await p.seek(startPos);
      }
      state = state.copyWith(playing: true, buffering: false, engine: PlaybackEngine.mediaKit, volume: volume ?? state.volume);
    } catch (e) {
      state = state.copyWith(error: '$e', buffering: false, engine: PlaybackEngine.none);
    }
  }

  void pause() {
    if (state.engine == PlaybackEngine.soloud && _handle != null) {
      try {
        SoLoud.instance.pauseSwitch(_handle!);
      } catch (_) {}
      state = state.copyWith(playing: false);
      return;
    }
    if (state.engine == PlaybackEngine.mediaKit) {
      try {
        _fallback.pause();
      } catch (_) {}
      state = state.copyWith(playing: false);
      return;
    }
  }

  void resume() {
    if (state.engine == PlaybackEngine.soloud && _handle != null) {
      try {
        SoLoud.instance.pauseSwitch(_handle!);
      } catch (_) {}
      state = state.copyWith(playing: true);
      return;
    }
    if (state.engine == PlaybackEngine.mediaKit) {
      try {
        _fallback.play();
      } catch (_) {}
      state = state.copyWith(playing: true);
      return;
    }
  }

  void toggle() {
    if (state.completed) {
      seek(Duration.zero);
      resume();
      state = state.copyWith(completed: false);
      return;
    }
    if (state.playing) {
      pause();
    } else {
      resume();
    }
  }

  void stop() {
    _stopPosTimer();
    if (_handle != null) {
      try {
        SoLoud.instance.stop(_handle!);
      } catch (_) {}
      _handle = null;
    }
    if (_source != null) {
      try {
        SoLoud.instance.disposeSource(_source!);
      } catch (_) {}
      _source = null;
    }
    try {
      _fallbackPlayer?.stop();
    } catch (_) {}
    state = const SoloudMusicState();
  }

  void seek(Duration pos) {
    if (state.engine == PlaybackEngine.soloud && _handle != null) {
      try {
        SoLoud.instance.seek(_handle!, pos);
      } catch (_) {}
      state = state.copyWith(position: pos);
      return;
    }
    if (state.engine == PlaybackEngine.mediaKit) {
      try {
        _fallback.seek(pos);
      } catch (_) {}
      state = state.copyWith(position: pos);
      return;
    }
  }

  void setVolume(double v) {
    final clamped = v.clamp(0, 100).toDouble();
    if (state.engine == PlaybackEngine.soloud && _handle != null) {
      try {
        SoLoud.instance.setVolume(_handle!, clamped / 100.0);
      } catch (_) {}
      state = state.copyWith(volume: clamped);
      return;
    }
    if (state.engine == PlaybackEngine.mediaKit) {
      try {
        _fallback.setVolume(clamped);
      } catch (_) {}
      state = state.copyWith(volume: clamped);
      return;
    }
    // Sin engine activo: solo guarda volumen
    state = state.copyWith(volume: clamped);
    // También aplica a ambos para siguiente play
    try {
      if (_handle != null) SoLoud.instance.setVolume(_handle!, clamped / 100.0);
    } catch (_) {}
    try {
      _fallbackPlayer?.setVolume(clamped);
    } catch (_) {}
  }

  void seekBy(Duration delta) {
    var ms = (state.position + delta).inMilliseconds;
    if (ms < 0) ms = 0;
    if (state.duration.inMilliseconds > 0 && ms > state.duration.inMilliseconds) ms = state.duration.inMilliseconds;
    seek(Duration(milliseconds: ms));
  }

  /// Para AudioFlux: expone si SoLoud está activo y sonando.
  bool get isSoloudActive => state.isSoloud && state.playing && _handle != null && _soloudReady;
}

final soloudMusicProvider = NotifierProvider<SoloudMusicController, SoloudMusicState>(SoloudMusicController.new);
