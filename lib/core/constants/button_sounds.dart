/// Constantes para sonidos de selección (hover/focus) en AppHover.
/// Añade aquí cualquier archivo nuevo en assets/audio/fx/buttons/ y
/// aparecerá automáticamente en Ajustes → Sonidos.
/// key: valor persistido en SharedPreferences
/// asset: ruta relativa para AssetSource (sin prefijo assets/)
class ButtonSound {
  const ButtonSound({required this.key, required this.label, required this.asset});
  final String key;
  final String label;
  final String asset;
}

const kButtonSounds = <ButtonSound>[
  ButtonSound(key: 'none', label: 'Ninguno', asset: ''),
  ButtonSound(key: 'gameboy-pluck', label: 'Gameboy Pluck', asset: 'audio/fx/buttons/gameboy-pluck.mp3'),
  ButtonSound(key: '8-bit-laser', label: '8-Bit Laser', asset: 'audio/fx/buttons/8-bit-laser.mp3'),
  ButtonSound(key: '8-bit-powerup', label: '8-Bit Powerup', asset: 'audio/fx/buttons/8-bit-powerup.mp3'),
  ButtonSound(key: 'glitch-bass', label: 'Glitch Bass', asset: 'audio/fx/buttons/glitch-bass.mp3'),
  ButtonSound(key: 'interface', label: 'Interface', asset: 'audio/fx/buttons/interface.mp3'),
  ButtonSound(key: 'minimal-pop-click', label: 'Minimal Pop Click', asset: 'audio/fx/buttons/minimal-pop-click.mp3'),
  ButtonSound(key: 'radio-select', label: 'Radio Select', asset: 'audio/fx/buttons/radio-select.mp3'),
  ButtonSound(key: 'retro-blip', label: 'Retro Blip', asset: 'audio/fx/buttons/retro-blip.mp3'),
  ButtonSound(key: 'sfx-jump', label: 'SFX Jump', asset: 'audio/fx/buttons/sfx_jump.mp3'),
];

const String kDefaultButtonSoundKey = 'gameboy-pluck';

ButtonSound buttonSoundForKey(String key) {
  return kButtonSounds.firstWhere((s) => s.key == key, orElse: () => kButtonSounds[1]);
}

String assetForButtonSoundKey(String key) => buttonSoundForKey(key).asset;
