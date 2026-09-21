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

/// Suspensión transitoria del vídeo de fondo (p. ej. visor 3D en el detalle
/// del juego). No se persiste: es solo para evitar que dos superficies ANGLE
/// (media_kit + three_js) convivan en Windows y aborten el proceso.
final gameVideoSuspendedProvider =
    NotifierProvider<GameVideoSuspendedController, bool>(
      GameVideoSuspendedController.new,
    );

class GameVideoSuspendedController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Nº de fondos de vídeo con player activo. El visor 3D espera a que sea 0
/// antes de crear su superficie GL, y reanuda al salir (orden inverso).
final gameVideoActiveCountProvider =
    NotifierProvider<GameVideoActiveCountController, int>(
      GameVideoActiveCountController.new,
    );

class GameVideoActiveCountController extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;

  void decrement() {
    state = (state - 1).clamp(0, 1 << 30);
  }
}
