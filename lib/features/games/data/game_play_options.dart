import 'package:shared_preferences/shared_preferences.dart';

/// Opciones de reproducción persistentes por juego.
class GamePlayOptions {
  const GamePlayOptions({this.subtitles = false, this.fullscreen = false});

  final bool subtitles;
  final bool fullscreen;
}

/// Persistencia local (SharedPreferences) de las opciones por juego.
class GamePlayOptionsStore {
  GamePlayOptionsStore();

  static const _kSubtitles = 'romm.game.subtitles.';
  static const _kFullscreen = 'romm.game.fullscreen.';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<GamePlayOptions> read(int gameId) async {
    final prefs = await _prefs;
    return GamePlayOptions(
      subtitles: prefs.getBool('$_kSubtitles$gameId') ?? false,
      fullscreen: prefs.getBool('$_kFullscreen$gameId') ?? false,
    );
  }

  Future<void> setSubtitles(int gameId, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool('$_kSubtitles$gameId', value);
  }

  Future<void> setFullscreen(int gameId, bool value) async {
    final prefs = await _prefs;
    await prefs.setBool('$_kFullscreen$gameId', value);
  }
}
