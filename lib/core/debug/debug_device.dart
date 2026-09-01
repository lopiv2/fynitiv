import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dispositivo simulado para previsualizar el layout durante el desarrollo.
enum DebugDevice {
  none('Actual'),
  phone('Teléfono', 390, 844),
  tablet('Tablet', 768, 1024),
  tv('TV', 1280, 720),
  desktop('Escritorio', 1920, 1080);

  const DebugDevice(this.label, [this.width, this.height]);

  final String label;

  /// Dimensiones lógicas del dispositivo simulado.
  final double? width;
  final double? height;

  bool get isSimulated => width != null && height != null;
}

class DebugDeviceController extends Notifier<DebugDevice> {
  @override
  DebugDevice build() => DebugDevice.none;

  void select(DebugDevice device) => state = device;
}

/// Dispositivo activo en la simulación de vista (debug).
final debugDeviceProvider =
    NotifierProvider<DebugDeviceController, DebugDevice>(
  DebugDeviceController.new,
);

class DebugDpadController extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setVisible(bool v) => state = v;
}

/// Toggle para mostrar el overlay D-pad (mando TV) draggable.
final debugDpadVisibleProvider =
    NotifierProvider<DebugDpadController, bool>(DebugDpadController.new);
