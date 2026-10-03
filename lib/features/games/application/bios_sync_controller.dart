import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/romm_repository.dart';
import 'romm_providers.dart';

/// Resultado de una sincronización de BIOS/firmware (RomM → cliente).
class BiosSyncResult {
  const BiosSyncResult({
    required this.downloaded,
    required this.skipped,
    required this.failed,
    required this.total,
  });

  final int downloaded;
  final int skipped;
  final int failed;
  final int total;
}

/// Estado observable de la sincronización de BIOS.
class BiosSyncState {
  const BiosSyncState({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.last,
  });

  final bool running;
  final int done;
  final int total;
  final BiosSyncResult? last;
}

/// Descarga al cliente todo el firmware/BIOS que RomM tiene y aún falta
/// en local (dirección RomM → cliente). La subida queda para otra fase.
class BiosSyncController extends Notifier<BiosSyncState> {
  @override
  BiosSyncState build() => const BiosSyncState();

  /// Devuelve el resultado, o `null` si no hay servidor/autenticación o falló
  /// la consulta del listado.
  Future<BiosSyncResult?> sync() async {
    if (state.running) return null;
    final repo = ref.read(rommRepositoryProvider);
    if (repo == null) return null;
    final store = ref.read(localGameStoreProvider);
    final dir = await store.biosDir();
    await store.ensureDir(dir);

    final List<RommFirmware> all;
    try {
      all = await repo.getFirmware();
    } catch (_) {
      return null;
    }
    final valid = all
        .where((f) => !f.missingFromFs && f.fileName.trim().isNotEmpty)
        .toList();
    state = BiosSyncState(running: true, total: valid.length);

    var downloaded = 0;
    var skipped = 0;
    var failed = 0;
    var done = 0;
    final seen = <String>{};

    for (final fw in valid) {
      final name = fw.fileName.trim();
      if (seen.add(name)) {
        final path = store.localPathFor(dir, name);
        if (await store.fileExists(path)) {
          skipped++;
        } else {
          try {
            await Directory(File(path).parent.path).create(recursive: true);
            await repo.downloadFirmware(
              id: fw.id,
              fileName: name,
              savePath: path,
            );
            downloaded++;
          } catch (_) {
            failed++;
          }
        }
      }
      done++;
      state = BiosSyncState(running: true, done: done, total: valid.length);
    }

    final result = BiosSyncResult(
      downloaded: downloaded,
      skipped: skipped,
      failed: failed,
      total: valid.length,
    );
    state = BiosSyncState(
      running: false,
      done: done,
      total: valid.length,
      last: result,
    );
    return result;
  }
}

final biosSyncProvider = NotifierProvider<BiosSyncController, BiosSyncState>(
  BiosSyncController.new,
);
