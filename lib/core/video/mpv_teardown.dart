import 'package:media_kit/media_kit.dart';

/// Drenaje seguro de un `Player` libmpv en Windows.
///
/// Secuencia: `pause()` → `stop()` → gracia de 300 ms → `dispose()`.
/// La gracia deja que mpv suelte sus recursos GL en su propio hilo antes
/// de destruir la salida de vídeo; sin ella, desactivar un fondo o cerrar
/// un trailer aborta el proceso con
/// `egl::Surface::releaseTexImage: context` o `unlock of unowned mutex`.
/// Todo es tolerante a fallos (teardown en caliente / engine cerrándose).
Future<void> disposeMpvPlayer(Player? player) async {
  if (player == null) return;
  try {
    await player.pause();
  } catch (_) {}
  try {
    await player.stop();
  } catch (_) {}
  await Future.delayed(const Duration(milliseconds: 300));
  try {
    await player.dispose();
  } catch (_) {}
}
