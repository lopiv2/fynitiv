import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kAppVolumeKey = 'app_volume';

/// Volumen universal de la app (0..100), compartido por música (SoLoud y
/// legacy), vídeos, radio y previews. Es la única fuente de verdad: cada
/// reproductor lo lee al abrir y lo actualiza cuando el usuario lo cambia.
class AppVolumeController extends Notifier<double> {
  @override
  double build() {
    _load();
    return 100;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_kAppVolumeKey);
      if (saved != null) {
        state = saved.clamp(0, 100).toDouble();
      }
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kAppVolumeKey, state);
    } catch (_) {}
  }

  void setVolume(double v) {
    final next = v.clamp(0, 100).toDouble();
    if ((next - state).abs() < 0.001) return;
    state = next;
    _persist();
  }
}

final appVolumeProvider =
    NotifierProvider<AppVolumeController, double>(AppVolumeController.new);
