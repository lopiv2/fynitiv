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
    this.coverBackUrl,
    this.coverSpineUrl,
    this.box3dUrl,
    this.logoUrl,
    this.screenshotUrl,
    this.hasStreaming = false,
    this.firstFile,
    this.lastPlayed,
    this.firstReleaseDate,
    this.fsSizeBytes = 0,
  });

  final int id;
  final String name;
  final int platformId;
  final String platformSlug;
  final String platformDisplayName;
  final String? summary;
  final String? coverSmallUrl;
  final String? coverLargeUrl;

  /// Trasera 2D (backcover) si RomM la expone, para la cara trasera del 3D.
  final String? coverBackUrl;

  /// Lomo lateral 2D (spine/side) si RomM lo expone, para los cantos del 3D.
  final String? coverSpineUrl;

  /// Caja 3D pre-renderizada de RomM (box3d). Se usa como fallback 2D
  /// premium cuando no hay trasera+lomo para montar el modelo.
  final String? box3dUrl;

  /// Logo/wheel del juego (`ss_metadata.logo_path`/`logo_url`). Si viene
  /// vacío, el detalle usa el título en texto como hasta ahora.
  final String? logoUrl;

  /// Primera captura del juego para el fondo del detalle
  /// (top-level `screenshots[0]` o `ss_metadata.screenshot_path/url`).
  /// Vacía si ROMM no devuelve ninguna: el detalle usa la carátula.
  final String? screenshotUrl;

  /// Si ROMM tiene un contenedor de streaming configurado para la plataforma
  /// de este juego (permite jugar en el navegador/emulador web).
  final bool hasStreaming;

  /// Nombre del primer archivo del juego (para la descarga).
  final String? firstFile;

  /// Última vez jugado (rom_user.last_played) – usado para “Continuar jugando”.
  final DateTime? lastPlayed;

  /// Fecha de lanzamiento (metadatum.first_release_date de ROMM, timestamp
  /// Unix en segundos). Puede venir null si el juego no tiene metadatos.
  final DateTime? firstReleaseDate;

  /// Tamaño en disco del juego (`fs_size_bytes` de ROMM, en bytes).
  final int fsSizeBytes;

  RommGame copyWith({
    String? summary,
    String? coverSmallUrl,
    String? coverLargeUrl,
    String? coverBackUrl,
    String? coverSpineUrl,
    String? box3dUrl,
    String? logoUrl,
    String? screenshotUrl,
    bool? hasStreaming,
    String? firstFile,
    DateTime? lastPlayed,
    DateTime? firstReleaseDate,
    int? fsSizeBytes,
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
      coverBackUrl: coverBackUrl ?? this.coverBackUrl,
      coverSpineUrl: coverSpineUrl ?? this.coverSpineUrl,
      box3dUrl: box3dUrl ?? this.box3dUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      hasStreaming: hasStreaming ?? this.hasStreaming,
      firstFile: firstFile ?? this.firstFile,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      firstReleaseDate: firstReleaseDate ?? this.firstReleaseDate,
      fsSizeBytes: fsSizeBytes ?? this.fsSizeBytes,
    );
  }

  /// True si hay caras suficientes para montar el modelo 3D.
  /// La API de ROMM no expone lomo: basta frontal + trasera; los cantos
  /// usan material sólido.
  bool get has3DFaces {
    return (coverLargeUrl ?? coverSmallUrl)?.isNotEmpty == true &&
        (coverBackUrl?.isNotEmpty == true);
  }

  /// True si hay frontal para mostrar la caja 3D aunque no haya trasera:
  /// la trasera y el lomo ausentes usan material sólido. Es el caso normal
  /// en servidores RomM que solo guardan la frontal (p.ej. ScummVM).
  bool get hasFrontCover {
    return (coverLargeUrl ?? coverSmallUrl)?.isNotEmpty == true;
  }

  /// Puerta del visor 3D: frontal basta; con trasera real se usa ella.
  bool get can3D => hasFrontCover;
}