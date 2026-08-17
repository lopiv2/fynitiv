import 'channel.dart';
import 'program.dart';

/// Fuente unificada de canales y guía para FYNITIV LIVE.
///
/// La UI depende solo de esta interfaz; los adaptadores (Jellyfin, IPTV,
/// ErsatzTV…) se conectan por detrás sin que la UI se entere.
abstract class LiveRepository {
  Future<List<Channel>> getChannels();

  /// Programas en la ventana [start]–[end] (UTC).
  Future<List<Program>> getGuide({
    required DateTime start,
    required DateTime end,
  });
}
