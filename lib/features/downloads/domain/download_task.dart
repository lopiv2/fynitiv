/// Estado de una descarga gestionada por el [DownloadManagerController].
enum DownloadStatus {
  /// En cola, aún sin primer byte.
  queued,

  /// Descargando activamente.
  downloading,

  /// Pausada por el usuario (conserva los bytes en `.part`).
  paused,

  /// Falló (red, servidor, disco). Reintentable con resume.
  error,

  /// Descargado y extrayendo (zip → carpeta del juego).
  extracting,

  /// Completada y renombrada a su nombre final.
  completed,
}

/// Una descarga individual (ROM de ROMM o vídeo de Jellyfin).
///
/// Inmutable: el controller emite copias vía [copyWith].
class DownloadTask {
  const DownloadTask({
    required this.id,
    required this.fileName,
    required this.sourceLabel,
    required this.url,
    required this.headers,
    required this.savePath,
    required this.doneMessage,
    required this.failMessage,
    this.status = DownloadStatus.queued,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedBps = 0,
    this.extractProgress = 0,
    this.error,
  });

  /// Id único de la task (no del contenido: el mismo archivo puede
  /// encolarse dos veces).
  final String id;

  /// Nombre del archivo destino (p. ej. `sonic.smc`).
  final String fileName;

  /// Etiqueta visible (nombre del juego / película).
  final String sourceLabel;

  /// URL de descarga.
  final String url;

  /// Cabeceras (p. ej. `Authorization: Bearer <token ROMM>`).
  final Map<String, String> headers;

  /// Ruta final en disco (se descarga a `$savePath.part`).
  final String savePath;

  /// Texto localizado del toast de éxito (resuelto por quien encola,
  /// el provider no tiene contexto/l10n).
  final String doneMessage;

  /// Texto localizado del toast de error.
  final String failMessage;

  final DownloadStatus status;
  final int receivedBytes;

  /// Total en bytes; `<= 0` si el servidor no lo informa.
  final int totalBytes;

  /// Velocidad suavizada en bytes/segundo.
  final double speedBps;

  /// 0..1 del proceso de extracción del zip (cuando `status == extracting`).
  final double extractProgress;
  final String? error;

  /// 0..1; 0 si el total es desconocido.
  double get progress {
    if (totalBytes <= 0 || receivedBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// Tiempo estimado restante, o null si no se puede calcular.
  Duration? get eta {
    if (totalBytes <= 0 || speedBps <= 0 || receivedBytes >= totalBytes) {
      return null;
    }
    return Duration(seconds: ((totalBytes - receivedBytes) / speedBps).ceil());
  }

  /// Visible en la barra: todo menos tareas ya retiradas (el controller
  /// elimina del mapa al descartar).
  bool get isActive => status != DownloadStatus.completed;

  DownloadTask copyWith({
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    double? speedBps,
    double? extractProgress,
    String? error,
    bool clearError = false,
  }) {
    return DownloadTask(
      id: id,
      fileName: fileName,
      sourceLabel: sourceLabel,
      url: url,
      headers: headers,
      savePath: savePath,
      doneMessage: doneMessage,
      failMessage: failMessage,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBps: speedBps ?? this.speedBps,
      extractProgress: extractProgress ?? this.extractProgress,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
