import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';

final gameBgMutedProvider = NotifierProvider<GameBgMutedController, bool>(GameBgMutedController.new);

class GameBgMutedController extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return false; // por defecto suena, volumen 0.5
  }

  Future<void> _load() async {
    final v = await ref.read(sessionStorageProvider).readGameBgMuted();
    if (v != null) state = v;
  }

  Future<void> setMuted(bool muted) async {
    state = muted;
    await ref.read(sessionStorageProvider).writeGameBgMuted(muted);
  }

  Future<void> toggle() => setMuted(!state);
}
