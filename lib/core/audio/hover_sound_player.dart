import 'package:audioplayers/audioplayers.dart';

/// Singleton para reproducir sonido corto de hover/focus.
/// Usa volumen del sistema (no override).
class HoverSoundPlayer {
  HoverSoundPlayer._();
  static final HoverSoundPlayer instance = HoverSoundPlayer._();

  final AudioPlayer _player = AudioPlayer();
  int _lastPlayMs = 0;
  static const int _debounceMs = 90;

  Future<void> play(String asset) async {
    if (asset.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayMs < _debounceMs) return;
    _lastPlayMs = now;
    try {
      await _player.stop();
      await _player.play(AssetSource(asset));
    } catch (_) {}
  }

  Future<void> preload(List<String> assets) async {
    for (final a in assets) {
      if (a.isEmpty) continue;
      try {
        await _player.setSource(AssetSource(a));
      } catch (_) {}
    }
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    _player.dispose();
  }
}
