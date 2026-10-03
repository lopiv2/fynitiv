import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'romm_providers.dart';

/// Resultado de un sync de partidas/estados (Device Sync Protocol).
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

/// Estado observable del sync de partidas/estados.
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
  });

  final int romId;
  final String file;
  final String path;
}

/// Sync bidireccional de saves/states con RomM (`/api/sync/negotiate`).
///
/// Escanea las partidas/estados locales, las mapea a `rom_id` mediante los
/// metadatos `.fynitiv.meta` de cada juego, negocia con el servidor y ejecuta
/// las operaciones. Los conflictos se conservan (`keep_both`), sin sobrescribir.
class RommSyncController extends Notifier<RommSyncState> {
  @override
  RommSyncState build() => const RommSyncState();

  Future<RommSyncReport?> sync() async {
    if (state.running) return null;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return null;
    final deviceId = await ref.read(rommStorageProvider).readDeviceId();
    if (deviceId == null || deviceId.isEmpty) return null;
    final store = ref.read(localGameStoreProvider);

    final metas = await store.listGameMetas();
    if (metas.isEmpty) {
      const empty = RommSyncReport(
        uploaded: 0,
        downloaded: 0,
        conflicts: 0,
        failed: 0,
        skipped: 0,
        scanned: 0,
      );
      state = const RommSyncState(last: empty);
      return empty;
    }

    // stem (nombre base del archivo jugable) -> romId. Si varias plataformas
    // comparten el mismo stem, se omite para no cruzar partidas entre juegos.
    final stemToRom = <String, int>{};
    final ambiguous = <String>{};
    for (final (_, meta) in metas) {
      final romId = (meta['romId'] as num?)?.toInt();
      final stem = (meta['stem'] as String?)?.trim();
      if (romId == null || stem == null || stem.isEmpty) continue;
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

    final savesDir = await store.savesDir();
    final statesDir = await store.statesDir();
    final files = <String>[
      ...await store.listFiles(savesDir),
      ...await store.listFiles(statesDir),
    ];

    final assets = <_LocalAsset>[];
    for (final path in files) {
      final name = path.split(RegExp(r'[/\\]+')).last;
      if (name.startsWith('.')) continue;
      final stem = _stemOf(name)?.toLowerCase();
      if (stem == null) continue;
      final romId = stemToRom[stem];
      if (romId == null) continue;
      assets.add(_LocalAsset(romId: romId, file: name, path: path));
    }

    final byRom = <int, List<Map<String, dynamic>>>{};
    for (final a in assets) {
      final f = File(a.path);
      if (!await f.exists()) continue;
      final stat = await f.stat();
      final digest = sha1.convert(await f.readAsBytes()).toString();
      (byRom[a.romId] ??= []).add({
        'file': a.file,
        'mtime': _isoUtc(stat.modified),
        'sha1': digest,
      });
    }
    final roms = byRom.entries
        .map((e) => {'rom_id': e.key, 'saves': e.value})
        .toList();

    state = RommSyncState(running: true, total: roms.length);
    final Map<String, dynamic> negotiate;
    try {
      negotiate = await repo.negotiateSync(deviceId: deviceId, roms: roms);
    } catch (_) {
      state = const RommSyncState();
      return null;
    }
    final sessionId = negotiate['session_id'];
    final opsRaw = negotiate['operations'];
    final ops = opsRaw is List
        ? opsRaw.whereType<Map>().toList()
        : const <Map>[];

    final pathIndex = <String, String>{
      for (final a in assets) '${a.romId}|${a.file}': a.path,
    };

    var uploaded = 0;
    var downloaded = 0;
    var conflicts = 0;
    var failed = 0;
    var skipped = 0;
    var done = 0;

    for (final op in ops) {
      final type = op['type']?.toString() ?? '';
      final romId = (op['rom_id'] as num?)?.toInt();
      final file = op['file']?.toString() ?? '';
      try {
        switch (type) {
          case 'upload':
            final src = romId == null ? null : pathIndex['$romId|$file'];
            if (src != null) {
              await repo.uploadSave(
                romId: romId!,
                deviceId: deviceId,
                filePath: src,
                fileName: file,
                sessionId: sessionId,
              );
              uploaded++;
            } else {
              skipped++;
            }
          case 'download':
            final source = op['source']?.toString();
            if (source != null && source.isNotEmpty && file.isNotEmpty) {
              final destDir = _isState(file) ? statesDir : savesDir;
              await store.ensureDir(destDir);
              final dest = '$destDir${Platform.pathSeparator}$file';
              await repo.downloadUrlTo(repo.assetUrl(source), dest);
              downloaded++;
            } else {
              skipped++;
            }
          case 'conflict':
            // keep_both: se conservan ambas versiones, no sobrescribimos.
            conflicts++;
          case 'noop':
            skipped++;
          default:
            skipped++;
        }
      } catch (_) {
        failed++;
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
      } catch (_) {}
    }

    final report = RommSyncReport(
      uploaded: uploaded,
      downloaded: downloaded,
      conflicts: conflicts,
      failed: failed,
      skipped: skipped,
      scanned: assets.length,
    );
    state = RommSyncState(
      running: false,
      done: done,
      total: ops.length,
      last: report,
    );
    return report;
  }

  static bool _isState(String file) {
    final lower = file.toLowerCase();
    return lower.contains('.state') ||
        lower.endsWith('.st0') ||
        lower.endsWith('.ss0');
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
