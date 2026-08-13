import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo de ejecución según la plataforma y el dispositivo.
enum PlatformMode { desktop, mobile, tv }

const _platformChannel = MethodChannel('jellyfinitive/platform');

/// Determina el modo de la app.
/// - Android TV (UI_MODE_TYPE_TELEVISION) → [PlatformMode.tv]
/// - Windows/Linux/macOS → [PlatformMode.desktop]
/// - Resto (móvil) → [PlatformMode.mobile]
final platformModeProvider = FutureProvider<PlatformMode>((ref) async {
  if (kIsWeb) return PlatformMode.mobile;
  final info = await DeviceInfoPlugin().deviceInfo;
  if (info is AndroidDeviceInfo) {
    try {
      final isTv = await _platformChannel.invokeMethod<bool>('isTv');
      if (isTv == true) return PlatformMode.tv;
    } catch (_) {
      // Sin canal nativo (p. ej. tests): usar device_info.
    }
    return PlatformMode.mobile;
  }
  if (info is WindowsDeviceInfo) return PlatformMode.desktop;
  if (info is LinuxDeviceInfo) return PlatformMode.desktop;
  if (info is MacOsDeviceInfo) return PlatformMode.desktop;
  return PlatformMode.mobile;
});
