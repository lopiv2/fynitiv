/// Juego (ROM) de la biblioteca de ROMM.
class RommGame {
  const RommGame({
    required this.id,
    required this.name,
    required this.platformId,
    required this.platformSlug,
    required this.platformDisplayName,
    this.summary,
    this.coverSmallUrl,
    this.coverLargeUrl,
    this.hasStreaming = false,
    this.firstFile,
    this.lastPlayed,
  });

  final int id;
  final String name;
  final int platformId;
  final String platformSlug;
  final String platformDisplayName;
  final String? summary;
  final String? coverSmallUrl;
  final String? coverLargeUrl;

  /// Si ROMM tiene un contenedor de streaming configurado para la plataforma
  /// de este juego (permite jugar en el navegador/emulador web).
  final bool hasStreaming;

  /// Nombre del primer archivo del juego (para la descarga).
  final String? firstFile;

  /// Última vez jugado (rom_user.last_played) – usado para “Continuar jugando”.
  final DateTime? lastPlayed;

  RommGame copyWith({
    String? summary,
    String? coverSmallUrl,
    String? coverLargeUrl,
    bool? hasStreaming,
    String? firstFile,
    DateTime? lastPlayed,
  }) {
    return RommGame(
      id: id,
      name: name,
      platformId: platformId,
      platformSlug: platformSlug,
      platformDisplayName: platformDisplayName,
      summary: summary ?? this.summary,
      coverSmallUrl: coverSmallUrl ?? this.coverSmallUrl,
      coverLargeUrl: coverLargeUrl ?? this.coverLargeUrl,
      hasStreaming: hasStreaming ?? this.hasStreaming,
      firstFile: firstFile ?? this.firstFile,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }
}