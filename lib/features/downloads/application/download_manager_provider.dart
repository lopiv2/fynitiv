import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_paths.dart';
import '../domain/download_task.dart';

/// Transferencia en curso: el `Dio` + `CancelToken` propios de cada task
/// (las descargas son paralelas; pausar/cancelar una no afecta a otras).
class _ActiveTransfer {
  _ActiveTransfer(this.dio, this.token);

  final Dio dio;
  final CancelToken token;

  /// Intención del último cancel: pausar, descartar o ninguna (error real).
  _CancelIntent intent = _CancelIntent.none;
}

enum _CancelIntent { none, pause, cancel }

/// Ruta relativa segura para disco, preservando subcarpetas (ROMs multiarchivo
/// y juegos por carpeta) y saneando caracteres ilegales en Windows (`<>:"|?*`).
String _relativePath(String fileName) {
  final parts = fileName
      .split(RegExp(r'[/\\]+'))
      .where((p) => p.isNotEmpty && p != '.' && p != '..')
      .map((p) => p.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_').trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'download.bin';
  return parts.join(Platform.pathSeparator);
}

/// Motivo corto y legible para el toast (HTTP + mensaje, truncado).
/// Prioriza el `detail` que devuelve el servidor (FastAPI) sobre el
/// texto genérico de Dio, que no dice nada útil (p. ej. el 404 de ROMM
/// trae `ROM <id> has no file to download`).
String _reason(Object e) {
  String out;
  if (e is DioException) {
    final data = e.response?.data;
    String? detail;
    if (data is Map && data['detail'] is String) {
      detail = (data['detail'] as String).trim();
    } else if (data is String && data.trim().isNotEmpty) {
      detail = data.trim();
    }
    final code = e.response?.statusCode;
    if (detail != null && detail.isNotEmpty) {
      out = code != null ? 'HTTP $code: $detail' : detail;
    } else {
      final msg = (e.message ?? '').trim();
      if (code != null) {
        out = msg.isNotEmpty ? 'HTTP $code: $msg' : 'HTTP $code';
      } else {
        out = msg.isNotEmpty ? msg : e.type.toString();
      }
    }
  } else {
    out = e.toString();
  }
  const max = 160;
  return out.length > max ? '${out.substring(0, max)}…' : out;
}

/// Gestor global de descargas (ROMs de ROMM y vídeos de Jellyfin).
///
/// Estado: mapa id → [DownloadTask]. La barra inferior
/// ([DownloadManagerBar]) lo observa; las pantallas de detalle encolan
/// con [enqueue] y leen el spinner con [isDownloadingFile].
class DownloadManagerController extends Notifier<Map<String, DownloadTask>> {
  final Map<String, _ActiveTransfer> _transfers = {};
  final Map<String, Timer> _pruneTimers = {};

  /// Última emisión de progreso por task (throttle 200 ms).
  final Map<String, DateTime> _lastEmit = {};

  /// Muestras (instante, bytes reales) por task para la velocidad en
  /// ventana deslizante de 3 s. Sin el umbral mínimo anterior (`dt > 0.05`),
  /// que congelaba la velocidad en redes rápidas (eventos < 50 ms).
  final Map<String, List<(DateTime, int)>> _samples = {};

  @override
  Map<String, DownloadTask> build() {
    ref.onDispose(() {
      for (final t in _transfers.values) {
        t.intent = _CancelIntent.cancel;
        if (!t.token.isCancelled) t.token.cancel('dispose');
        t.dio.close(force: true);
      }
      _transfers.clear();
      for (final timer in _pruneTimers.values) {
        timer.cancel();
      }
      _pruneTimers.clear();
      _lastEmit.clear();
      _samples.clear();
    });
    return const {};
  }

  /// ¿Hay alguna task visible (no completada/descartada)?
  bool get hasVisible => state.values.any((t) => t.isActive);

  /// ¿Sigue activo (encolado/descargando/pausado/error) este archivo?
  /// Para el spinner de los botones de descarga de las fichas.
  bool isDownloadingFile(String fileName) => state.values.any(
        (t) => t.fileName == fileName && t.isActive,
      );

  /// Encola una descarga y la arranca. Si el mismo archivo ya está
  /// activo, lo reanuda (si estaba pausado) y devuelve su id.
  Future<String?> enqueue({
    required String url,
    required String fileName,
    String? sourceLabel,
    Map<String, String> headers = const {},
    String? destinationDir,
    required String doneMessage,
    required String failMessage,
  }) async {
    final existing = state.values
        .where((t) => t.fileName == fileName && t.url == url && t.isActive)
        .firstOrNull;
    if (existing != null) {
      if (existing.status == DownloadStatus.paused ||
          existing.status == DownloadStatus.error) {
        resume(existing.id);
      }
      return existing.id;
    }
    final Directory dir;
    if (destinationDir != null && destinationDir.isNotEmpty) {
      dir = Directory(destinationDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      dir = Directory(await AppPaths.downloads());
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
    final savePath =
        '${dir.path}${Platform.pathSeparator}${_relativePath(fileName)}';
    final id = '${DateTime.now().microsecondsSinceEpoch}-$fileName';
    state = {
      ...state,
      id: DownloadTask(
        id: id,
        fileName: fileName,
        sourceLabel: (sourceLabel == null || sourceLabel.isEmpty)
            ? fileName
            : sourceLabel,
        url: url,
        headers: Map.of(headers),
        savePath: savePath,
        doneMessage: doneMessage,
        failMessage: failMessage,
      ),
    };
    unawaited(_start(id, resumeFrom: 0, freshAttempt: true));
    return id;
  }

  /// Pausa: cancela el token conservando el `.part` para reanudar.
  void pause(String id) {
    final transfer = _transfers[id];
    final task = state[id];
    if (task == null || transfer == null) return;
    if (task.status != DownloadStatus.downloading &&
        task.status != DownloadStatus.queued) {
      return;
    }
    transfer.intent = _CancelIntent.pause;
    if (!transfer.token.isCancelled) transfer.token.cancel('paused');
  }

  /// Reanuda una task pausada o fallida (con `Range` si hay bytes).
  void resume(String id) {
    final task = state[id];
    if (task == null || _transfers.containsKey(id)) return;
    if (task.status != DownloadStatus.paused &&
        task.status != DownloadStatus.error) {
      return;
    }
    state = {
      ...state,
      id: task.copyWith(status: DownloadStatus.queued, clearError: true),
    };
    unawaited(_start(id, resumeFrom: task.receivedBytes, freshAttempt: false));
  }

  /// Cancela y retira la task (borra el `.part`; si estaba completada
  /// solo la descarta de la lista).
  void cancel(String id) {
    final task = state[id];
    if (task == null) return;
    _pruneTimers.remove(id)?.cancel();
    final transfer = _transfers.remove(id);
    if (transfer != null) {
      transfer.intent = _CancelIntent.cancel;
      if (!transfer.token.isCancelled) transfer.token.cancel('cancelled');
      transfer.dio.close();
    }
    _lastEmit.remove(id);
    _samples.remove(id);
    final next = Map<String, DownloadTask>.of(state)..remove(id);
    state = next;
    if (transfer == null) {
      // Sin transferencia viva: borrar resto en disco directamente.
      unawaited(_deletePart(task.savePath));
    } else {
      // Con transferencia viva el `deleteOnError` no aplica al `.part`
      // (descargamos ahí); se borra al resolverse el cancel.
      unawaited(_deletePart(task.savePath));
    }
  }

  Future<void> _deletePart(String savePath) async {
    try {
      final part = File('$savePath.part');
      if (await part.exists()) await part.delete();
    } catch (_) {}
  }

  /// Marca una task descargada como "extrayendo" (zip → carpeta del juego).
  void startExtracting(String id) {
    final task = state[id];
    if (task == null) return;
    _pruneTimers.remove(id)?.cancel();
    state = {
      ...state,
      id: task.copyWith(
        status: DownloadStatus.extracting,
        extractProgress: 0,
      ),
    };
  }

  /// Actualiza el progreso de extracción (0..1).
  void updateExtractProgress(String id, double progress) {
    final task = state[id];
    if (task == null || task.status != DownloadStatus.extracting) return;
    state = {
      ...state,
      id: task.copyWith(extractProgress: progress.clamp(0.0, 1.0)),
    };
  }

  /// Termina la extracción y programa el retirado de la barra.
  void finishExtracting(String id) {
    final task = state[id];
    if (task == null) return;
    state = {
      ...state,
      id: task.copyWith(
        status: DownloadStatus.completed,
        extractProgress: 1,
      ),
    };
    _pruneTimers.remove(id)?.cancel();
    _pruneTimers[id] = Timer(const Duration(seconds: 6), () {
      final done = state[id];
      if (done != null && done.status == DownloadStatus.completed) {
        final next = Map<String, DownloadTask>.of(state)..remove(id);
        state = next;
      }
      _pruneTimers.remove(id);
    });
  }

  Future<void> _start(
    String id, {
    required int resumeFrom,
    required bool freshAttempt,
  }) async {
    final task = state[id];
    if (task == null) return;
    final token = CancelToken();
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        headers: {
          ...task.headers,
          if (resumeFrom > 0) 'Range': 'bytes=$resumeFrom-',
        },
      ),
    );
    _transfers[id] = _ActiveTransfer(dio, token);
    state = {
      ...state,
      id: task.copyWith(status: DownloadStatus.downloading),
    };
    final partPath = '${task.savePath}.part';
    var knownTotal = task.totalBytes;
    debugPrint(
      '[DownloadManager] start id=$id resumeFrom=$resumeFrom '
      'url=${task.url} -> $partPath '
      'auth=${task.headers.containsKey('Authorization')}',
    );
    try {
      final res = await dio.download(
        task.url,
        partPath,
        cancelToken: token,
        deleteOnError: false,
        fileAccessMode:
            resumeFrom > 0 ? FileAccessMode.append : FileAccessMode.write,
        onReceiveProgress: (count, total) =>
            _onProgress(id, resumeFrom, count, total),
      );
      _transfers.remove(id)?.dio.close();
      final current = state[id];
      if (current == null) return;
      // El servidor ignoró el Range (200 en vez de 206): el `.part`
      // trae duplicado lo previo + el fichero entero → reintento limpio.
      if (resumeFrom > 0 && res.statusCode == 200 && !freshAttempt) {
        await _deletePart(task.savePath);
        state = {
          ...state,
          id: current.copyWith(receivedBytes: 0, totalBytes: 0, speedBps: 0),
        };
        _samples.remove(id);
        await _start(id, resumeFrom: 0, freshAttempt: true);
        return;
      }
      knownTotal = current.totalBytes;
      final file = File(partPath);
      if (knownTotal > 0 && await file.exists()) {
        final len = await file.length();
        if (len != knownTotal) {
          if (resumeFrom > 0 && !freshAttempt) {
            await _deletePart(task.savePath);
            state = {
              ...state,
              id: current.copyWith(
                receivedBytes: 0,
                totalBytes: 0,
                speedBps: 0,
              ),
            };
            _samples.remove(id);
            await _start(id, resumeFrom: 0, freshAttempt: true);
            return;
          }
          throw StateError('Incomplete file ($len/$knownTotal)');
        }
      }
      // Renombrar `.part` → final (en Windows no pisa existente).
      final target = File(task.savePath);
      try {
        if (await target.exists()) await target.delete();
        await file.rename(task.savePath);
      } catch (_) {
        // Destino en uso o sin permiso: se deja el `.part` y se avisa.
        throw StateError('Cannot move file to ${task.savePath}');
      }
      _lastEmit.remove(id);
      _samples.remove(id);
      state = {
        ...state,
        id: current.copyWith(status: DownloadStatus.completed),
      };
      unawaited(
        EasyLoading.showSuccess('${current.doneMessage}\n${current.savePath}'),
      );
      // Auto-retirar de la barra tras unos segundos.
      _pruneTimers.remove(id)?.cancel();
      _pruneTimers[id] = Timer(const Duration(seconds: 8), () {
        final done = state[id];
        if (done != null && done.status == DownloadStatus.completed) {
          final next = Map<String, DownloadTask>.of(state)..remove(id);
          state = next;
        }
        _pruneTimers.remove(id);
      });
    } on DioException catch (e) {
      _transfers.remove(id)?.dio.close();
      final current = state[id];
      if (current == null) return;
      if (e.type == DioExceptionType.cancel) {
        // Pausa o descarte intencionado (el `cancel()` ya retiró la task).
        if (state[id] != null) {
          state = {
            ...state,
            id: current.copyWith(status: DownloadStatus.paused),
          };
        }
        return;
      }
      // Error real de red/servidor: se conserva el `.part` para resume.
      _lastEmit.remove(id);
      _samples.remove(id);
      final reason = _reason(e);
      final respData = e.response?.data?.toString() ?? '';
      debugPrint(
        '[DownloadManager] FAILED id=$id url=${task.url} '
        'status=${e.response?.statusCode} type=${e.type} '
        'message=${e.message} data=${respData.length > 300 ? respData.substring(0, 300) : respData}',
      );
      state = {
        ...state,
        id: current.copyWith(
          status: DownloadStatus.error,
          error: reason,
        ),
      };
      unawaited(EasyLoading.showError('${current.failMessage}\n$reason'));
    } catch (e) {
      _transfers.remove(id);
      final current = state[id];
      if (current == null) return;
      _lastEmit.remove(id);
      _samples.remove(id);
      final reason = _reason(e);
      debugPrint(
        '[DownloadManager] FAILED(id=$id url=${task.url}): $e',
      );
      state = {
        ...state,
        id: current.copyWith(
          status: DownloadStatus.error,
          error: reason,
        ),
      };
      unawaited(EasyLoading.showError('${current.failMessage}\n$reason'));
    }
  }

  void _onProgress(String id, int baseOffset, int count, int totalResp) {
    final task = state[id];
    if (task == null || task.status != DownloadStatus.downloading) return;
    final now = DateTime.now();
    final received = baseOffset + count;
    // Total real: con `Range` el servidor informa el restante; se suma
    // la base ya descargada. Sin total, se conserva el conocido.
    final total = totalResp > 0
        ? baseOffset + totalResp
        : (task.totalBytes > 0 ? task.totalBytes : 0);
    // Velocidad en ventana deslizante (últimos 3 s): estable y correcta
    // tanto en redes lentas como rápidas.
    var speed = task.speedBps;
    final samples = _samples.putIfAbsent(id, () => []);
    samples.add((now, received));
    final cutoff = now.subtract(const Duration(seconds: 3));
    while (samples.length > 2 && samples.first.$1.isBefore(cutoff)) {
      samples.removeAt(0);
    }
    if (samples.length >= 2) {
      final first = samples.first;
      final dt = now.difference(first.$1).inMilliseconds / 1000.0;
      if (dt >= 0.3) {
        final windowed = (received - first.$2) / dt;
        if (windowed >= 0) speed = windowed;
      }
    }
    // Throttle: emitir como mucho cada 200 ms (o al completar).
    final last = _lastEmit[id];
    final done = total > 0 && received >= total;
    if (!done &&
        last != null &&
        now.difference(last).inMilliseconds < 200) {
      return;
    }
    _lastEmit[id] = now;
    state = {
      ...state,
      id: task.copyWith(
        receivedBytes: received,
        totalBytes: total,
        speedBps: speed < 0 ? 0 : speed,
      ),
    };
  }
}

final downloadManagerProvider =
    NotifierProvider<DownloadManagerController, Map<String, DownloadTask>>(
  DownloadManagerController.new,
);
