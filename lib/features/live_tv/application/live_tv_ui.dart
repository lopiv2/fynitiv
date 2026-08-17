import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flags de UI del Live TV compartidos entre la pantalla, el flotante y el
/// reproductor a pantalla completa (para no tener dos Video activos a la vez).
class LiveTvUiState {
  const LiveTvUiState({this.floating = false, this.fullscreen = false});

  /// El vídeo se muestra en el reproductor flotante (no en el preview).
  final bool floating;

  /// Hay un reproductor a pantalla completa abierto.
  final bool fullscreen;

  LiveTvUiState copyWith({bool? floating, bool? fullscreen}) {
    return LiveTvUiState(
      floating: floating ?? this.floating,
      fullscreen: fullscreen ?? this.fullscreen,
    );
  }
}

class LiveTvUiController extends Notifier<LiveTvUiState> {
  @override
  LiveTvUiState build() => const LiveTvUiState();

  void setFloating(bool value) => state = state.copyWith(floating: value);
  void setFullscreen(bool value) => state = state.copyWith(fullscreen: value);
}

final liveTvUiProvider =
    NotifierProvider<LiveTvUiController, LiveTvUiState>(
  LiveTvUiController.new,
);
