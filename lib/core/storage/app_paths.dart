import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Error al crear la raíz de datos (p. ej. sin permisos en `C:\Fynitiv`).
class AppPathsException implements Exception {
  AppPathsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resuelve la raíz de datos de Fynitiv y sus subcarpetas.
///
/// - Windows: `C:\Fynitiv`.
/// - Android: externo de la app (`Android/data/<pkg>/files/Fynitiv`).
/// - Otros: directorio de soporte de la app.
class AppPaths {
  AppPaths._();

  static Future<String> root() async {
    if (kIsWeb) {
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}Fynitiv',
      );
      await _ensure(dir);
      return dir.path;
    }
    if (Platform.isWindows) {
      final dir = Directory(r'C:\Fynitiv');
      await _ensure(dir);
      return dir.path;
    }
    if (Platform.isAndroid) {
      final base = await getExternalStorageDirectory() ??
          await getApplicationSupportDirectory();
      final dir = Directory('${base.path}${Platform.pathSeparator}Fynitiv');
      await _ensure(dir);
      return dir.path;
    }
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}Fynitiv');
    await _ensure(dir);
    return dir.path;
  }

  static Future<String> roms() => _sub('roms');
  static Future<String> bios() => _sub('bios');
  static Future<String> saves() => _sub('saves');
  static Future<String> states() => _sub('states');

  /// Carpeta de descargas generales (vídeos/música de Jellyfin).
  static Future<String> downloads() => _sub('Downloads');

  static Future<String> _sub(String name) async {
    final base = await root();
    final dir = Directory('$base${Platform.pathSeparator}$name');
    await _ensure(dir);
    return dir.path;
  }

  static Future<void> _ensure(Directory dir) async {
    try {
      if (!await dir.exists()) await dir.create(recursive: true);
    } on FileSystemException catch (e) {
      throw AppPathsException(
        'No se pudo crear ${dir.path}: ${e.message}',
      );
    }
  }
}
