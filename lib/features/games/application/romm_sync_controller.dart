import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_game_store.dart';
import 'romm_providers.dart';

void _log(String msg) => debugPrint('[RommSync] $msg');

String _short(String id) => id.length <= 8 ? id : id.substring(0, 8);

/// Resultado de un sync de partidas (Device Sync Protocol).
class RommSyncReport {
  const RommSyncReport({
    required this.uploaded,
    required this.downloaded,
    required this.conflicts,
    required this.failed,
    required this.skipped,
    required this.scanned,
  });

  final int uploaded;
  final int downloaded;
  final int conflicts;
  final int failed;
  final int skipped;
  final int scanned;
}

/// Estado observable del sync de partidas.
class RommSyncState {
  const RommSyncState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.last,
  });

  final bool running;
  final int done;
  final int total;
  final RommSyncReport? last;
}

class _LocalAsset {
  const _LocalAsset({
    required this.romId,
    required this.file,
    required this.path,
    required this.relDir,
  });

  final int romId;
  final String file;
  final String path;

  /// Subcarpeta relativa a `saves/`; '' = raíz.
  final String relDir;
}

/// Subcarpeta de [path] relativa a [root]; '' si el fichero está en la raíz.
String _relDirOf(String path, String root) {
  var rel = path;
  if (rel.startsWith(root)) rel = rel.substring(root.length);
  rel = rel.replaceAll(RegExp(r'^[/\\]+'), '');
  final sep = rel.lastIndexOf(RegExp(r'[/\\]'));
  return sep <= 0 ? '' : rel.substring(0, sep);
}

/// Sync bidireccional de **partidas** con RomM 5.x
/// (`POST /api/sync/negotiate`).
///
/// Escanea las partidas locales, las mapea a `rom_id` mediante los metadatos
/// `.fynitiv.meta` de cada juego, negocia con el servidor y ejecuta las
/// operaciones (`upload`/`download`/`conflict`/`no_op`). Los conflictos se
/// conservan (`keep_both`), sin sobrescribir.
///
/// Nota: esta versión de RomM (5.3.1) solo negocia **saves**, no states.
class RommSyncController extends Notifier<RommSyncState> {
  @override
  RommSyncState build() => const RommSyncState();

  Future<RommSyncReport?> sync() async {
    if (state.running) {
      _log('ya en curso; ignorado');
      return null;
    }
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) {
      _log('sin repositorio RomM; empareja el dispositivo');
      return null;
    }
    final deviceId = await ref.read(rommStorageProvider).readDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      _log('sin device_id; empareja el dispositivo');
      return null;
    }
    final store = ref.read(localGameStoreProvider);

    final metas = await store.listGameMetas();
    _log('device=${_short(deviceId)} metas=${metas.length}');
    if (metas.isEmpty) {
      _log('sin metas (.fynitiv.meta); lanza un juego al menos una vez');
      return _finish(
        const RommSyncReport(
          uploaded: 0,
          downloaded: 0,
          conflicts: 0,
          failed: 0,
          skipped: 0,
          scanned: 0,
        ),
      );
    }

    // stem (nombre base del jugable) -> romId. Si varias plataformas comparten
    // el mismo stem, se omite para no cruzar partidas entre juegos.
    final stemToRom = <String, int>{};
    final ambiguous = <String>{};
    final romSaveSubdir = <int, String>{}; // pista de subcarpeta por rom
    final romEmulator = <int, String>{};
    final romIds = <int>{};
    for (final (_, meta) in metas) {
      final romId = (meta['romId'] as num?)?.toInt();
      final stem = (meta['stem'] as String?)?.trim();
      if (romId == null) continue;
      romIds.add(romId);
      // Solo RetroArch (base o core) guarda en nuestro `saves/`; los
      // emuladores standalone usan su propio directorio y nombres.
      if (meta['saveSync'] == false) {
        _log(
          'skip rom=$romId name=${meta['name']} '
          '(emulador sin soporte de guardado)',
        );
        continue;
      }
      if (meta['saveSync'] == null) {
        _log('rom=$romId sin flag saveSync (asumido soportado)');
      }
      romSaveSubdir[romId] = meta['saveSubdir']?.toString() ?? '';
      final emulator = meta['emulator']?.toString();
      if (emulator != null && emulator.isNotEmpty) romEmulator[romId] = emulator;
      if (stem == null || stem.isEmpty) continue;
      final key = stem.toLowerCase();
      if (stemToRom.containsKey(key) && stemToRom[key] != romId) {
        ambiguous.add(key);
      } else {
        stemToRom[key] = romId;
      }
    }
    for (final a in ambiguous) {
      stemToRom.remove(a);
    }
    if (ambiguous.isNotEmpty) {
      _log('stems ambiguos omitidos: ${ambiguous.join(', ')}');
    }
    _log('mapping stems=${stemToRom.length} de metas=${metas.length}');

    final savesDir = await store.savesDir();
    final files = await store.listFilesRecursive(savesDir);
    _log('ficheros locales en saves/=${files.length}');

    final assets = <_LocalAsset>[];
    for (final path in files) {
      final name = path.split(RegExp(r'[/\\]+')).last;
      if (name.startsWith('.')) continue;
      final lower = name.toLowerCase();
      // Ficheros de servicio de los emuladores (no son partidas).
      if (lower.endsWith('.cfg') || lower.endsWith('.ini')) {
        _log('scan skip service $name');
        continue;
      }
      final relDir = _relDirOf(path, savesDir);
      final display = relDir.isEmpty ? name : '$relDir/$name';
      final stem = _stemOf(name)?.toLowerCase();
      final romId = stem == null ? null : stemToRom[stem];
      _log('scan $display stem=$stem -> rom=${romId ?? "sin match"}');
      if (stem == null || romId == null) continue;
      assets.add(
        _LocalAsset(romId: romId, file: name, path: path, relDir: relDir),
      );
    }

    // Primera subcarpeta observada por rom; pista para la descarga.
    final relDirHint = <int, String>{};
    for (final a in assets) {
      relDirHint.putIfAbsent(a.romId, () => a.relDir);
    }

    // RomM 5.x: lista plana de saves. `slot` estable = nombre del fichero local
    // (permite emparejar no_op/download y recuperar el nombre al bajar).
    final saves = <Map<String, dynamic>>[];
    final slotPath = <String, String>{}; // '<romId>|<slot>' -> ruta local
    for (final a in assets) {
      final f = File(a.path);
      if (!await f.exists()) continue;
      final stat = await f.stat();
      // RomM compara `content_hash` con **MD5** (ver assets_handler de RomM).
      final digest = md5.convert(await f.readAsBytes()).toString();
      saves.add({
        'rom_id': a.romId,
        'file_name': a.file,
        'slot': a.file,
        'content_hash': digest,
        'updated_at': _isoUtc(stat.modified),
        'file_size_bytes': stat.size,
        if (romEmulator[a.romId] != null) 'emulator': romEmulator[a.romId],
      });
      slotPath['${a.romId}|${a.file}'] = a.path;
      _log(
        'local rom=${a.romId} file=${a.file} '
        'md5=${digest.substring(0, 8)} size=${stat.size}',
      );
    }
    // RomM limita `rom_ids` a 500 por petición; si hay más, se omite el scope
    // (menos ideal: ofrecería descargas de toda la biblioteca de saves).
    final scope = romIds.length <= 500 ? romIds.toList() : null;
    _log(
      'negotiate saves=${saves.length} '
      'rom_ids=${scope == null ? "(omitido >500)" : scope.length}',
    );

    state = RommSyncState(running: true, total: saves.length);
    final Map<String, dynamic> negotiate;
    try {
      negotiate = await repo.negotiateSync(
        deviceId: deviceId,
        saves: saves,
        romIds: scope,
      );
    } on DioException catch (e) {
      _log(
        'negotiate FALLÓ status=${e.response?.statusCode} '
        'body=${e.response?.data}',
      );
      state = const RommSyncState();
      return null;
    } catch (e) {
      _log('negotiate FALLÓ: $e');
      state = const RommSyncState();
      return null;
    }
    final sessionId = negotiate['session_id'];
    final opsRaw = negotiate['operations'];
    final ops = opsRaw is List
        ? opsRaw.whereType<Map>().toList()
        : const <Map>[];
    _log('session=$sessionId ops=${ops.length}');

    var uploaded = 0;
    var downloaded = 0;
    var conflicts = 0;
    var failed = 0;
    var skipped = 0;
    var done = 0;

    for (final op in ops) {
      final action = (op['action'] ?? op['type'])?.toString() ?? '';
      final romId = (op['rom_id'] as num?)?.toInt();
      final fileName =
          (op['file_name'] ?? op['file'])?.toString() ?? '';
      final slot = op['slot']?.toString() ?? fileName;
      final saveId = (op['save_id'] as num?)?.toInt();
      _log('op action=$action rom=$romId file=$fileName slot=$slot');
      try {
        switch (action) {
          case 'upload':
            final src = romId == null ? null : slotPath['$romId|$slot'];
            if (src != null) {
              await repo.uploadSave(
                romId: romId!,
                deviceId: deviceId,
                filePath: src,
                fileName: fileName,
                slot: slot,
                emulator: romEmulator[romId],
                sessionId: sessionId,
              );
              uploaded++;
              _log('upload OK rom=$romId file=$fileName');
            } else {
              skipped++;
              _log('upload skip rom=$romId file=$fileName (sin fichero local)');
            }
          case 'download':
            if (saveId != null) {
              final dest = await _downloadDest(
                store: store,
                savesDir: savesDir,
                slotPath: slotPath,
                relDirHint: relDirHint,
                romSaveSubdir: romSaveSubdir,
                romId: romId,
                slot: slot,
                fileName: fileName,
              );
              await repo.downloadUrlTo(
                repo.saveContentUrl(
                  saveId,
                  deviceId: deviceId,
                  sessionId: sessionId,
                ),
                dest,
              );
              downloaded++;
              _log('download OK rom=$romId file=$fileName -> $dest');
            } else {
              skipped++;
              _log('download skip rom=$romId file=$fileName (sin save_id)');
            }
          case 'conflict':
            // keep_both: se conservan ambas versiones, no sobrescribimos.
            conflicts++;
            _log('conflict keep-both rom=$romId file=$fileName');
          case 'no_op':
          case 'noop':
            skipped++;
            _log('no-op rom=$romId file=$fileName');
          default:
            skipped++;
            _log('op desconocida action=$action');
        }
      } catch (e) {
        failed++;
        _log('op FAIL action=$action rom=$romId file=$fileName: $e');
      }
      done++;
      state = RommSyncState(running: true, done: done, total: ops.length);
    }

    if (sessionId != null) {
      try {
        await repo.completeSyncSession(
          sessionId: sessionId,
          completed: uploaded + downloaded,
          failed: failed,
        );
        _log(
          'complete OK session=$sessionId '
          'completed=${uploaded + downloaded} failed=$failed',
        );
      } catch (e) {
        _log('complete FALLÓ session=$sessionId: $e');
      }
    }

    final report = RommSyncReport(
      uploaded: uploaded,
      downloaded: downloaded,
      conflicts: conflicts,
      failed: failed,
      skipped: skipped,
      scanned: assets.length,
    );
    _log(
      'report scanned=${assets.length} up=$uploaded down=$downloaded '
      'conflict=$conflicts skip=$skipped fail=$failed',
    );
    state = RommSyncState(
      running: false,
      done: done,
      total: ops.length,
      last: report,
    );
    return report;
  }

  /// Ruta local donde escribir una partida descargada: reutiliza la local si
  /// la hay (misma subcarpeta), si no la pista del rom o el subdir del meta.
  Future<String> _downloadDest({
    required LocalGameStore store,
    required String savesDir,
    required Map<String, String> slotPath,
    required Map<int, String> relDirHint,
    required Map<int, String> romSaveSubdir,
    required int? romId,
    required String slot,
    required String fileName,
  }) async {
    final existing = romId == null ? null : slotPath['$romId|$slot'];
    if (existing != null && existing.isNotEmpty) return existing;
    var relDir = romId == null ? '' : (relDirHint[romId] ?? '');
    if (relDir.isEmpty && romId != null) {
      relDir = romSaveSubdir[romId] ?? '';
    }
    final destDir = relDir.isEmpty
        ? savesDir
        : '$savesDir${Platform.pathSeparator}$relDir';
    await store.ensureDir(destDir);
    return '$destDir${Platform.pathSeparator}${_localNameFor(slot, fileName)}';
  }

  /// Nombre local para una descarga: si el `slot` parece un nombre de fichero
  /// (tiene extensión) se usa tal cual (es el nombre que guardó el core); si no
  /// (p. ej. `autosave`), se usa el `file_name` que devuelve RomM.
  static String _localNameFor(String slot, String fileName) {
    if (RegExp(r'\.[A-Za-z0-9]+$').hasMatch(slot)) return slot;
    return fileName.isNotEmpty ? fileName : slot;
  }

  /// Sincroniza (pull) las partidas de **un solo juego antes de jugar**:
  /// negocia para ese `romId` y descarga las que falten o sean más nuevas. No
  /// sube nada (la subida se hace al cerrar la sesión).
  Future<RommSyncReport?> pullRom({
    required int romId,
    required String? stem,
    required String subdir,
    String? emulator,
  }) async {
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return null;
    final deviceId = await ref.read(rommStorageProvider).readDeviceId();
    if (deviceId == null || deviceId.isEmpty) return null;
    final store = ref.read(localGameStoreProvider);
    final savesDir = await store.savesDir();

    // Partidas locales de este rom (por stem/gameid).
    final key = stem?.toLowerCase();
    final files = await store.listFilesRecursive(savesDir);
    final saves = <Map<String, dynamic>>[];
    final slotPath = <String, String>{};
    for (final path in files) {
      final name = path.split(RegExp(r'[/\\]+')).last;
      if (name.startsWith('.')) continue;
      final lower = name.toLowerCase();
      if (lower.endsWith('.cfg') || lower.endsWith('.ini')) continue;
      if (key == null || _stemOf(name)?.toLowerCase() != key) continue;
      final f = File(path);
      if (!await f.exists()) continue;
      final stat = await f.stat();
      final digest = md5.convert(await f.readAsBytes()).toString();
      saves.add({
        'rom_id': romId,
        'file_name': name,
        'slot': name,
        'content_hash': digest,
        'updated_at': _isoUtc(stat.modified),
        'file_size_bytes': stat.size,
        if (emulator != null && emulator.isNotEmpty) 'emulator': emulator,
      });
      slotPath['$romId|$name'] = path;
    }
    _log('pull rom=$romId stem=$stem saves=${saves.length}');

    final Map<String, dynamic> negotiate;
    try {
      negotiate = await repo.negotiateSync(
        deviceId: deviceId,
        saves: saves,
        romIds: [romId],
      );
    } on DioException catch (e) {
      _log(
        'pull negotiate FALLÓ status=${e.response?.statusCode} '
        'body=${e.response?.data}',
      );
      return null;
    } catch (e) {
      _log('pull negotiate FALLÓ: $e');
      return null;
    }
    final sessionId = negotiate['session_id'];
    final opsRaw = negotiate['operations'];
    final ops = opsRaw is List
        ? opsRaw.whereType<Map>().toList()
        : const <Map>[];
    _log('pull session=$sessionId ops=${ops.length}');

    var downloaded = 0;
    var failed = 0;
    var skipped = 0;
    for (final op in ops) {
      final action = (op['action'] ?? op['type'])?.toString() ?? '';
      final opRomId = (op['rom_id'] as num?)?.toInt() ?? romId;
      final fileName = (op['file_name'] ?? op['file'])?.toString() ?? '';
      final slot = op['slot']?.toString() ?? fileName;
      final saveId = (op['save_id'] as num?)?.toInt();
      _log('pull op action=$action rom=$opRomId file=$fileName slot=$slot');
      try {
        if (action == 'download') {
          if (saveId == null) {
            skipped++;
            continue;
          }
          final dest = await _downloadDest(
            store: store,
            savesDir: savesDir,
            slotPath: slotPath,
            relDirHint: const <int, String>{},
            romSaveSubdir: <int, String>{opRomId: subdir},
            romId: opRomId,
            slot: slot,
            fileName: fileName,
          );
          await repo.downloadUrlTo(
            repo.saveContentUrl(
              saveId,
              deviceId: deviceId,
              sessionId: sessionId,
            ),
            dest,
          );
          downloaded++;
          _log('pull download OK rom=$opRomId file=$fileName -> $dest');
        } else {
          skipped++;
        }
      } catch (e) {
        failed++;
        _log('pull op FAIL action=$action rom=$opRomId file=$fileName: $e');
      }
    }

    // RomM no re-ofrece una partida que cree borrada a propósito. Rellenamos lo
    // que falte localmente a partir del resumen por slot del servidor.
    try {
      final summary = await repo.getSavesSummary(romId);
      final slots = summary['slots'] as List? ?? const [];
      _log('pull server slots=${slots.length}');
      final destDir = subdir.isEmpty
          ? savesDir
          : '$savesDir${Platform.pathSeparator}$subdir';
      for (final item in slots.whereType<Map>()) {
        final latest = item['latest'];
        if (latest is! Map) continue;
        final id = (latest['id'] as num?)?.toInt();
        final sfile = latest['file_name']?.toString() ?? '';
        final sslot = latest['slot']?.toString() ?? '';
        final localName = _localNameFor(sslot, sfile);
        if (id == null || localName.isEmpty) continue;
        final dest = '$destDir${Platform.pathSeparator}$localName';
        if (await File(dest).exists()) continue;
        await store.ensureDir(destDir);
        await repo.downloadUrlTo(
          repo.saveContentUrl(id, deviceId: deviceId, sessionId: sessionId),
          dest,
        );
        downloaded++;
        _log('pull fallback download slot=$sslot -> $dest');
      }
    } catch (e) {
      _log('pull getSavesSummary falló: $e');
    }

    if (sessionId != null) {
      try {
        await repo.completeSyncSession(
          sessionId: sessionId,
          completed: downloaded,
          failed: failed,
        );
      } catch (_) {}
    }
    final report = RommSyncReport(
      uploaded: 0,
      downloaded: downloaded,
      conflicts: 0,
      failed: failed,
      skipped: skipped,
      scanned: saves.length,
    );
    _log('pull report down=$downloaded skip=$skipped fail=$failed');
    return report;
  }

  RommSyncReport _finish(RommSyncReport report) {
    state = RommSyncState(last: report);
    return report;
  }

  static String? _stemOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return null;
    return name.substring(0, dot);
  }

  static String _isoUtc(DateTime dt) =>
      dt.toUtc().toIso8601String().replaceAll(RegExp(r'\.\d+'), '');
}

final rommSyncProvider = NotifierProvider<RommSyncController, RommSyncState>(
  RommSyncController.new,
);
