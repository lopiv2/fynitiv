import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'debug_device.dart';
import 'dpad_overlay.dart';

/// Activa/desactiva la barra y la simulación de dispositivos (debug).
const bool debugDeviceBarEnabled = true;

/// Envuelve la app para simular la vista de distintos dispositivos.
///
/// Se usa como `MaterialApp.builder`: muestra una barra superior con botones
/// para elegir el dispositivo y encaja el contenido en sus dimensiones,
/// sobrescribiendo el [MediaQuery] para que el layout responda igual que en
/// el dispositivo real. Los botones quedan fuera de la zona simulada.
class DeviceSimulatorHost extends ConsumerWidget {
  const DeviceSimulatorHost({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(debugDeviceProvider);
    final dpadVisible = ref.watch(debugDpadVisibleProvider);

    if (!debugDeviceBarEnabled) {
      return child ?? const SizedBox.shrink();
    }

    final realMq = MediaQuery.of(context);
    final simulatedMq = device.isSimulated
        ? realMq.copyWith(
            size: Size(device.width!, device.height!),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          )
        : realMq;

    return Stack(
      children: [
        Column(
          children: [
            _DebugDeviceBar(device: device),
            Expanded(
              // MediaQuery y SizedBox siempre presentes para conservar el estado
              // del Navigator (navegación) al alternar la simulación.
              child: MediaQuery(
                data: simulatedMq,
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: device.isSimulated ? device.width : double.infinity,
                    height: device.isSimulated ? device.height : double.infinity,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (dpadVisible) const DpadOverlay(),
      ],
    );
  }
}

/// Barra superior con los botones para elegir el dispositivo simulado.
class _DebugDeviceBar extends ConsumerWidget {
  const _DebugDeviceBar({required this.device});

  final DebugDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final select = ref.read(debugDeviceProvider.notifier).select;
    final dpadVisible = ref.watch(debugDpadVisibleProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF0B1030),
        border: Border(bottom: BorderSide(color: Color(0xFF1A2568))),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Simular dispositivo:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final d in DebugDevice.values) ...[
                    _DeviceChip(
                      label: d.label,
                      selected: d == device,
                      onTap: () => select(d),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Toggle D-pad overlay (mando TV draggable)
          GestureDetector(
            onTap: () => ref.read(debugDpadVisibleProvider.notifier).toggle(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: dpadVisible ? const Color(0xFF2B7FFF) : Colors.white10,
                border: Border.all(color: dpadVisible ? const Color(0xFF2B7FFF) : Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gamepad_outlined, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    dpadVisible ? 'Mando ON' : 'Mando',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: dpadVisible ? FontWeight.w600 : FontWeight.w400),
                  ),
                ],
              ),
            ),
          ),
          if (device.isSimulated) ...[
            const SizedBox(width: 8),
            Text(
              '${device.width!.round()}×${device.height!.round()}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceChip extends StatelessWidget {
  const _DeviceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? const Color(0xFF2B7FFF) : Colors.white10,
          border: Border.all(
            color: selected ? const Color(0xFF2B7FFF) : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
