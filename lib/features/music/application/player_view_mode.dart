import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo de vista del player de audio: portada, letra o efectos a pantalla completa.
enum PlayerViewMode { cover, lyrics, effects }

class PlayerViewModeNotifier extends Notifier<PlayerViewMode> {
  @override
  PlayerViewMode build() => PlayerViewMode.lyrics; // siempre arrancar en LETRA (compat con bool true)

  void set(PlayerViewMode mode) => state = mode;
}

final playerViewModeProvider = NotifierProvider<PlayerViewModeNotifier, PlayerViewMode>(PlayerViewModeNotifier.new);
