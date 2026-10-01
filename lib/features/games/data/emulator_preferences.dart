import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias del jugador para emuladores externos:
/// asociación plataforma→emulador y overrides por emulador.
class EmulatorPreferences {
  EmulatorPreferences();

  static const _kAssoc = 'romm.emulator.assoc.';
  static const _kWinExe = 'romm.emulator.win_exe.';
  static const _kWinArgs = 'romm.emulator.win_args.';
  static const _kAndroidPkg = 'romm.emulator.android_pkg.';
  static const _kBiosDir = 'romm.emulator.bios_dir.';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> association(String slug) async =>
      (await _prefs).getString('$_kAssoc$slug');

  Future<void> setAssociation(String slug, String? emulatorId) async {
    final prefs = await _prefs;
    if (emulatorId == null || emulatorId.isEmpty) {
      await prefs.remove('$_kAssoc$slug');
    } else {
      await prefs.setString('$_kAssoc$slug', emulatorId);
    }
  }

  Future<String?> windowsExe(String emulatorId) async =>
      (await _prefs).getString('$_kWinExe$emulatorId');

  Future<void> setWindowsExe(String emulatorId, String? value) =>
      _set('$_kWinExe$emulatorId', value);

  Future<String?> windowsArgs(String emulatorId) async =>
      (await _prefs).getString('$_kWinArgs$emulatorId');

  Future<void> setWindowsArgs(String emulatorId, String? value) =>
      _set('$_kWinArgs$emulatorId', value);

  Future<String?> androidPackage(String emulatorId) async =>
      (await _prefs).getString('$_kAndroidPkg$emulatorId');

  Future<void> setAndroidPackage(String emulatorId, String? value) =>
      _set('$_kAndroidPkg$emulatorId', value);

  Future<String?> biosDir(String emulatorId) async =>
      (await _prefs).getString('$_kBiosDir$emulatorId');

  Future<void> setBiosDir(String emulatorId, String? value) =>
      _set('$_kBiosDir$emulatorId', value);

  Future<void> _set(String key, String? value) async {
    final prefs = await _prefs;
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value.trim());
    }
  }
}
