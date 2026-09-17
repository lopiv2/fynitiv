import 'soloud_single_player.dart';

/// Singleton para reproducir sonido corto de hover/focus.
/// Usa volumen del sistema (no override).
class HoverSoundPlayer {
  HoverSoundPlayer._();
  static final HoverSoundPlayer instance = HoverSoundPlayer._();

  final SoloudSinglePlayer _player = SoloudSinglePlayer();
  int _lastPlayMs = 0;
  static const int _debounceMs = 90;

  Future<void> play(String asset) async {
    if (asset.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayMs < _debounceMs) return;
    _lastPlayMs = now;
    try {
      await _player.playAsset(asset);
    } catch (_) {}
  }

  /// Precalienta la caché compartida para arrancar sin delay.
  Future<void> preload(List<String> assets) =>
      _player.preloadAssets(assets);

  void dispose() {
    _player.dispose();
  }
}
