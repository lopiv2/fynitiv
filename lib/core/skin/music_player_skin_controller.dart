import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_player_skin.dart';
import 'music_player_skin_presets.dart';

const _kMusicSkinKey = 'jellyfin.music_skin';
const _kMusicPresetKey = 'jellyfin.music_preset';

class MusicPlayerSkinController extends AsyncNotifier<MusicPlayerSkin> {
  @override
  Future<MusicPlayerSkin> build() async {
    final prefs = await SharedPreferences.getInstance();
    final presetId = prefs.getString(_kMusicPresetKey);
    if (presetId != null) {
      final preset = MusicPlayerSkinPresets.all.where((s) => s.id == presetId).firstOrNull;
      if (preset != null) return preset;
    }
    final raw = prefs.getString(_kMusicSkinKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return MusicPlayerSkin.fromJson(map);
      } catch (_) {}
    }
    return MusicPlayerSkinPresets.jellyfinClassic;
  }

  Future<void> apply(MusicPlayerSkin skin) async {
    state = AsyncData(skin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMusicPresetKey);
    await prefs.setString(_kMusicSkinKey, jsonEncode(skin.toJson()));
  }

  Future<void> applyPreset(String id) async {
    final preset = MusicPlayerSkinPresets.all.where((s) => s.id == id).firstOrNull;
    if (preset != null) await applyPresetSkin(preset);
  }

  Future<void> applyPresetSkin(MusicPlayerSkin preset) async {
    state = AsyncData(preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMusicSkinKey);
    await prefs.setString(_kMusicPresetKey, preset.id);
  }

  Future<void> reset() => applyPresetSkin(MusicPlayerSkinPresets.jellyfinClassic);
}

final musicPlayerSkinControllerProvider =
    AsyncNotifierProvider<MusicPlayerSkinController, MusicPlayerSkin>(
        MusicPlayerSkinController.new);
