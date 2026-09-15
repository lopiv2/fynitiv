import 'package:flutter_soloud/flutter_soloud.dart';

/// Inicializa SoLoud para música con visualización habilitada.
/// Retorna true si se inicializó correctamente, false si fallback a MediaKit.
class SoloudInitializer {
  static bool _initialized = false;
  static bool _initAttempted = false;
  static String? _error;

  static bool get isInitialized => _initialized;
  static bool get initAttempted => _initAttempted;
  static String? get error => _error;

  static Future<bool> ensureInitialized() async {
    if (_initAttempted) return _initialized;
    _initAttempted = true;
    try {
      await SoLoud.instance.init();
      // Habilita visualización para audio_flux waveform
      try {
        SoLoud.instance.setVisualizationEnabled(true);
      } catch (_) {}
      _initialized = true;
      return true;
    } catch (e) {
      _error = '$e';
      _initialized = false;
      return false;
    }
  }

  static Future<void> dispose() async {
    if (!_initialized) return;
    try {
      SoLoud.instance.deinit();
    } catch (_) {}
    _initialized = false;
    _initAttempted = false;
  }
}
