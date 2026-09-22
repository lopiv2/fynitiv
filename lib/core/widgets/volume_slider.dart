import 'package:material_ui/material_ui.dart';

/// Icono de volumen según nivel 0..100 (mismo criterio en toda la app).
IconData volumeIconFor(double v) {
  if (v <= 0) return Icons.volume_off_rounded;
  if (v < 50) return Icons.volume_down_rounded;
  return Icons.volume_up_rounded;
}

/// Fila de volumen genérica reutilizable (OST, música, radio…): botón de
/// mute + slider + etiqueta %.
///
/// El estado vive fuera (p.ej. `appVolumeProvider` 0..100): aquí entra
/// `volume` y sale `onChanged`. Sin textos propios que traducir (solo
/// tooltips y `%`, que vienen por parámetro).
class VolumeSliderRow extends StatelessWidget {
  const VolumeSliderRow({
    super.key,
    required this.volume,
    required this.onChanged,
    required this.muted,
    required this.onToggleMute,
    required this.volumeTooltip,
    required this.muteTooltip,
    required this.unmuteTooltip,
    this.accent = const Color(0xFF00A8E1),
    this.compact = false,
  });

  /// Nivel 0..100.
  final double volume;

  /// Recibe el nivel 0..100 al arrastrar (el dueño lo persiste).
  final ValueChanged<double> onChanged;

  /// Si está silenciado (el icono lo refleja aunque el slider conserve nivel).
  final bool muted;

  /// Alterna el mute (el slider no toca el mute a propósito).
  final VoidCallback onToggleMute;

  final String volumeTooltip;
  final String muteTooltip;
  final String unmuteTooltip;

  /// Color de acento del slider (cada sección usa el suyo).
  final Color accent;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final v = volume.clamp(0, 100).toDouble();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: muted ? unmuteTooltip : muteTooltip,
          onPressed: onToggleMute,
          icon: Icon(
            muted ? Icons.volume_off_rounded : volumeIconFor(v),
            color: Colors.white70,
            size: compact ? 18 : 20,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: accent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: accent.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: v,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${v.round()}%',
              onChanged: (nv) => onChanged(nv.clamp(0, 100).toDouble()),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${v.round()}%',
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
