import 'package:flutter/services.dart';

/// Control nativo de la ventana de escritorio (Windows).
class AppWindow {
  static const MethodChannel _channel = MethodChannel('fynitiv/window');

  /// Pone/restaura la ventana a pantalla completa real: oculta la barra de
  /// título del sistema y cubre todo el monitor.
  static Future<void> setFullscreen(bool fullscreen) async {
    try {
      await _channel.invokeMethod(
        'setFullscreen',
        {'fullscreen': fullscreen},
      );
    } on MissingPluginException {
      // Plataforma sin soporte nativo: se ignora.
    }
  }

  /// Indica si la ventana está actualmente en pantalla completa.
  static Future<bool> isFullscreen() async {
    try {
      return await _channel.invokeMethod<bool>('isFullscreen') ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}
