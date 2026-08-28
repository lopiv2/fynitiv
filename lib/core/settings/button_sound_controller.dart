import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/button_sounds.dart';
import '../di/providers.dart';

final buttonSoundKeyProvider = NotifierProvider<ButtonSoundController, String>(ButtonSoundController.new);

class ButtonSoundController extends Notifier<String> {
  @override
  String build() {
    // Carga async; mientras tanto default
    _load();
    return kDefaultButtonSoundKey;
  }

  Future<void> _load() async {
    final storage = ref.read(sessionStorageProvider);
    final stored = await storage.readButtonSoundKey();
    if (stored != null && stored.isNotEmpty && kButtonSounds.any((s) => s.key == stored)) {
      state = stored;
    }
  }

  Future<void> setKey(String key) async {
    if (!kButtonSounds.any((s) => s.key == key)) return;
    state = key;
    final storage = ref.read(sessionStorageProvider);
    await storage.writeButtonSoundKey(key);
  }

  String get asset => assetForButtonSoundKey(state);
}
