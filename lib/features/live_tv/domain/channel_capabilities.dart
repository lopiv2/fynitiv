/// Capacidades de un canal. La UI no decide por la fuente sino por lo que el
/// canal permite (evita asumir "IPTV → no grabar").
class ChannelCapabilities {
  const ChannelCapabilities({
    this.livePlayback = true,
    this.epg = true,
    this.recording = false,
    this.timeshift = false,
  });

  final bool livePlayback;
  final bool epg;
  final bool recording;
  final bool timeshift;

  /// Canal que solo permite reproducir en directo (sin EPG).
  static const ChannelCapabilities liveOnly = ChannelCapabilities(epg: false);

  /// Canal sin reproducción.
  static const ChannelCapabilities none = ChannelCapabilities(
    livePlayback: false,
    epg: false,
  );
}
