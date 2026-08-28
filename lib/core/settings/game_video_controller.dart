import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';

final gameVideoDisabledProvider = NotifierProvider<GameVideoDisabledController, bool>(GameVideoDisabledController.new);

class GameVideoDisabledController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false; // por defecto video activo
  }

  Future<void> _load() async {
    final v = await ref.read(sessionStorageProvider).readGameVideoDisabled();
    if (v != null) state = v;
  }

  Future<void> setDisabled(bool disabled) async {
    state = disabled;
    await ref.read(sessionStorageProvider).writeGameVideoDisabled(disabled);
  }

  Future<void> toggle() => setDisabled(!state);
}
