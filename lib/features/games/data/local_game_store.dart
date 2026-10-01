import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Extensions considered playable ROM content (used to pick the primary file
/// inside an extracted archive).
const _kRomExtensions = <String>{
  'nes', 'fds', 'unf', 'unif', 'snes', 'smc', 'sfc', 'gb', 'gbc', 'gba',
  'n64', 'z64', 'v64', 'md', 'gen', 'smd', 'sms', 'gg', '32x', 'pce', 'sgx',
  'ngp', 'ngc', 'ws', 'wsc', 'a26', 'a52', 'a78', 'col', 'int', 'vec', 'lnx',
  'iso', 'cue', 'chd', 'cso', 'pbp', 'gdi', 'bin', 'zip', '7z',
};

/// Almacén local de ROMs descargadas de RomM.
///
/// La raíz por defecto es `<appSupport>/romm/roms`, sobrescribible por el
/// usuario (`romm.roms_dir`). Cada plataforma vive en `roms/<slug>/`.
class LocalGameStore {
  LocalGameStore();

  static const _kRootDir = 'romm.roms_dir';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String> rootDir() async {
    final prefs = await _prefs;
    final override = prefs.getString(_kRootDir);
    if (override != null && override.isNotEmpty) return override;
    final base = await getApplicationSupportDirectory();
    return '${base.path}${Platform.pathSeparator}romm'
        '${Platform.pathSeparator}roms';
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

  String localPathFor(String platformDir, String fileName) {
    final name = fileName.split('/').last.split('\\').last;
    return '$platformDir${Platform.pathSeparator}$name';
  }

  Future<bool> isDownloaded(String path) => File(path).exists();

  /// Extrae un `.zip` a una carpeta hermana y devuelve el fichero jugable
  /// principal. Para el resto de archivos, devuelve la ruta tal cual.
  Future<String> resolvePlayableFile(String downloadedPath) async {
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
        primary ??= _pickPrimary(entry.name, out.path) ?? primary;
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
}
