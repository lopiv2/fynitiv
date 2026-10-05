import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/app_paths.dart';

/// Extensions considered playable ROM content (used to pick the primary file
/// inside an extracted archive).
const _kRomExtensions = <String>{
  'nes',
  'fds',
  'unf',
  'unif',
  'snes',
  'smc',
  'sfc',
  'gb',
  'gbc',
  'gba',
  'n64',
  'z64',
  'v64',
  'md',
  'gen',
  'smd',
  'sms',
  'gg',
  '32x',
  'pce',
  'sgx',
  'ngp',
  'ngc',
  'ws',
  'wsc',
  'a26',
  'a52',
  'a78',
  'col',
  'int',
  'vec',
  'lnx',
  'iso',
  'cue',
  'chd',
  'cso',
  'pbp',
  'gdi',
  'bin',
  'zip',
  '7z',
};

/// Almacén local de ROMs descargadas de RomM.
///
/// La raíz por defecto es `<appSupport>/romm` (con `roms/`, `bios/`, `saves/`
/// y `states/` dentro), sobrescribible por el usuario (`romm.roms_dir`).
/// Cada juego vive en `roms/<slug>/<juego>/`.
class LocalGameStore {
  LocalGameStore();

  static const _kRootDir = 'romm.roms_dir';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String> rootDir() async {
    final prefs = await _prefs;
    final override = prefs.getString(_kRootDir);
    if (override != null && override.isNotEmpty) return override;
    return AppPaths.root();
  }

  Future<void> setRootDir(String? dir) async {
    final prefs = await _prefs;
    if (dir == null || dir.trim().isEmpty) {
      await prefs.remove(_kRootDir);
    } else {
      await prefs.setString(_kRootDir, dir.trim());
    }
  }

  /// Carpeta de ROMs de una plataforma: `<raíz>/roms/<slug>/`.
  Future<String> platformDir(String platformSlug) async {
    final root = await romsRoot();
    final safe = platformSlug.trim().isEmpty ? 'unknown' : platformSlug.trim();
    return '$root${Platform.pathSeparator}$safe';
  }

  /// Carpeta de un juego: `roms/<slug>/<juego>/` (agrupa sus archivos).
  Future<String> gameDir(String platformSlug, String gameName) async {
    final base = await platformDir(platformSlug);
    final safe = _safeSegment(gameName);
    return '$base${Platform.pathSeparator}${safe.isEmpty ? 'game' : safe}';
  }

  /// Raíz de BIOS/firmware (directorio "system" de los emuladores).
  Future<String> biosDir() async {
    final root = await rootDir();
    return '$root${Platform.pathSeparator}bios';
  }

  /// Raíz de partidas guardadas.
  Future<String> savesDir() async {
    final root = await rootDir();
    return '$root${Platform.pathSeparator}saves';
  }

  /// Raíz de estados.
  Future<String> statesDir() async {
    final root = await rootDir();
    return '$root${Platform.pathSeparator}states';
  }

  /// Carpetas de ROMs por plataforma bajo la raíz.
  Future<String> romsRoot() async {
    final root = await rootDir();
    return '$root${Platform.pathSeparator}roms';
  }

  Future<void> ensureDir(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
  }

  Future<bool> fileExists(String path) => File(path).exists();

  /// Ruta local de un archivo del juego, preservando subcarpetas y saneando
  /// caracteres ilegales en disco (coincide con el gestor de descargas).
  String localPathFor(String dir, String fileName) {
    final parts = fileName
        .split(RegExp(r'[/\\]+'))
        .where((p) => p.isNotEmpty && p != '.' && p != '..')
        .map(_safeSegment)
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) parts.add('download.bin');
    return [dir, ...parts].join(Platform.pathSeparator);
  }

  static String _safeSegment(String raw) {
    final clean = raw.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_').trim();
    return clean;
  }

  Future<bool> isDownloaded(String path) => File(path).exists();

  /// Extrae un `.zip` a una carpeta hermana y devuelve el fichero jugable
  /// principal. Para el resto de archivos, devuelve la ruta tal cual.
  Future<String> resolvePlayableFile(String downloadedPath) async {
    // ── Archivo .scummvm: devuelve directamente (el launcher lo usa como gameid)
    if (downloadedPath.toLowerCase().endsWith('.scummvm')) {
      return downloadedPath;
    }

    // ── No es un zip: devuelve tal cual
    if (!downloadedPath.toLowerCase().endsWith('.zip')) return downloadedPath;

    final file = File(downloadedPath);
    if (!await file.exists()) return downloadedPath;

    final stem = file.uri.pathSegments.last.replaceAll(RegExp(r'\.zip$'), '');
    final outDir = Directory(
      '${file.parent.path}${Platform.pathSeparator}$stem',
    );
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    try {
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      String? primary;

      for (final entry in archive) {
        if (!entry.isFile) continue;
        final out = File(
          '${outDir.path}${Platform.pathSeparator}${entry.name}',
        );
        await out.parent.create(recursive: true);
        await out.writeAsBytes(entry.content as List<int>);

        // Prioriza .scummvm sobre cualquier otro archivo dentro del zip
        if (entry.name.toLowerCase().endsWith('.scummvm')) {
          primary = out.path;
        } else {
          primary ??= _pickPrimary(entry.name, out.path);
        }
      }

      // Si hay un directorio con .scummvm dentro (carpeta extraída), búscalo
      if (primary == null) {
        final scummFile = outDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.scummvm'))
            .firstOrNull;
        if (scummFile != null) primary = scummFile.path;
      }

      return primary ?? downloadedPath;
    } catch (_) {
      return downloadedPath;
    }
  }

  String? _pickPrimary(String entryName, String outPath) {
    final dot = entryName.lastIndexOf('.');
    if (dot < 0) return null;
    final ext = entryName.substring(dot + 1).toLowerCase();
    if (ext == 'zip' || ext == '7z') return null;
    return _kRomExtensions.contains(ext) ? outPath : null;
  }

  /// True si la carpeta existe y contiene al menos un archivo.
  Future<bool> hasFiles(String dir) async {
    final d = Directory(dir);
    if (!await d.exists()) return false;
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is File) return true;
    }
    return false;
  }

  static const _kReadyMarker = '.fynitiv.ready';

  /// Marca la carpeta del juego como lista (extraída y verificada).
  Future<void> markReady(String dir) async {
    await ensureDir(dir);
    await File(
      '$dir${Platform.pathSeparator}$_kReadyMarker',
    ).writeAsString('1');
  }

  /// True si la carpeta del juego ya fue extraída/marcada como lista.
  Future<bool> isReady(String dir) =>
      File('$dir${Platform.pathSeparator}$_kReadyMarker').exists();

  /// Borra por completo el contenido de una carpeta (si existe).
  Future<void> clearDir(String dir) async {
    final d = Directory(dir);
    if (await d.exists()) await d.delete(recursive: true);
  }

  static const _kMetaFile = '.fynitiv.meta';

  /// Fichero de metadatos de un juego (romId, plataforma, jugable).
  String metaPath(String gameDir) =>
      '$gameDir${Platform.pathSeparator}$_kMetaFile';

  /// Escribe los metadatos de un juego para poder mapear sus partidas/estados
  /// al `rom_id` de RomM al sincronizar.
  Future<void> writeGameMeta(String gameDir, Map<String, dynamic> meta) async {
    await ensureDir(gameDir);
    await File(metaPath(gameDir)).writeAsString(jsonEncode(meta));
  }

  Future<Map<String, dynamic>?> readGameMeta(String gameDir) async {
    final f = File(metaPath(gameDir));
    if (!await f.exists()) return null;
    try {
      final raw = await f.readAsString();
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Recorre `roms/` y devuelve cada juego con metadatos: `(gameDir, meta)`.
  Future<List<(String, Map<String, dynamic>)>> listGameMetas() async {
    final root = Directory(await romsRoot());
    if (!await root.exists()) return [];
    final out = <(String, Map<String, dynamic>)>[];
    await for (final e in root.list(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      if (e.uri.pathSegments.last != _kMetaFile) continue;
      try {
        final raw = await e.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          out.add((e.parent.path, decoded));
        }
      } catch (_) {}
    }
    return out;
  }

  /// Lista los archivos (no ocultos) de una carpeta; vacío si no existe.
  Future<List<String>> listFiles(String dir) async {
    final d = Directory(dir);
    if (!await d.exists()) return [];
    final out = <String>[];
    await for (final e in d.list(followLinks: false)) {
      if (e is File) out.add(e.path);
    }
    return out;
  }

  /// Lista recursivamente los archivos de una carpeta y sus subcarpetas
  /// (para encontrar saves/estados que los cores guardan en subcarpetas,
  /// p. ej. `saves/ScummVM/<gameid>.s00`).
  Future<List<String>> listFilesRecursive(String dir) async {
    final d = Directory(dir);
    if (!await d.exists()) return [];
    final out = <String>[];
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is File) out.add(e.path);
    }
    return out;
  }

  /// Subcarpetas que no son necesarias para jugar y se omiten al extraer.
  static const _kSkipFolders = <String>{'soundtrack'};

  /// Extrae un `.zip` en [destDir] aplanando los prefijos comunes redundantes
  /// (p. ej. `roms/<juego>/<juego>/…` → `…/<juego>/`) y omitiendo carpetas
  /// prescindibles (`soundtrack`). Notifica progreso por archivo.
  Future<void> extractZipInto(
    String zipPath,
    String destDir, {
    void Function(int done, int total)? onProgress,
  }) async {
    final file = File(zipPath);
    if (!await file.exists()) return;
    await ensureDir(destDir);
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());

    final entries = <ArchiveFile>[];
    final segLists = <List<String>>[];
    for (final entry in archive) {
      if (!entry.isFile || entry.name.isEmpty) continue;
      final segments = entry.name
          .replaceAll('\\', '/')
          .split('/')
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.isEmpty) continue;
      final folders = segments
          .take(segments.length - 1)
          .map((s) => s.toLowerCase());
      if (folders.any(_kSkipFolders.contains)) continue;
      entries.add(entry);
      segLists.add(segments);
    }

    // Aplana prefijos comunes: mientras todos tengan al menos 2 segmentos
    // (una carpeta + archivo) y compartan el primer segmento, se elimina.
    while (true) {
      if (segLists.any((s) => s.length <= 1)) break;
      final first = segLists.map((s) => s.first.toLowerCase()).toSet();
      if (first.length != 1) break;
      for (final s in segLists) {
        s.removeAt(0);
      }
    }

    final total = entries.length;
    for (var i = 0; i < entries.length; i++) {
      final rel = segLists[i].join(Platform.pathSeparator);
      if (rel.isNotEmpty) {
        final out = File('$destDir${Platform.pathSeparator}$rel');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(entries[i].content as List<int>);
      }
      onProgress?.call(i + 1, total);
    }
  }
}
