import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../debug/debug_device.dart';

/// Modo de ejecución según la plataforma y el dispositivo.
enum PlatformMode { desktop, mobile, tv }

const _platformChannel = MethodChannel('jellyfinitive/platform');

/// Determina el modo de la app.
/// - Android TV (UI_MODE_TYPE_TELEVISION) → [PlatformMode.tv]
/// - Windows/Linux/macOS → [PlatformMode.desktop]
/// - Resto (móvil) → [PlatformMode.mobile]
///
/// Si hay un dispositivo simulado activo (debug), se usa su modo.
final platformModeProvider = FutureProvider<PlatformMode>((ref) async {
  final simulated = ref.watch(debugDeviceProvider);
  if (simulated != DebugDevice.none) {
    switch (simulated) {
      case DebugDevice.phone || DebugDevice.tablet:
        return PlatformMode.mobile;
      case DebugDevice.tv:
        return PlatformMode.tv;
      case DebugDevice.desktop:
        return PlatformMode.desktop;
      case DebugDevice.none:
        break;
    }
  }
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
