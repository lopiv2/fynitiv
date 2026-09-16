library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'radio_skin.dart';
import 'radio_skin_presets.dart';

const _kRadioSkinKey = 'fynitiv.radio_skin';
const _kRadioPresetKey = 'fynitiv.radio_preset';

class RadioSkinController extends AsyncNotifier<RadioSkin> {
  @override
  Future<RadioSkin> build() async {
    final prefs = await SharedPreferences.getInstance();
    final presetId = prefs.getString(_kRadioPresetKey);
    if (presetId != null) {
      final preset = RadioSkinPresets.all.where((s) => s.id == presetId).firstOrNull;
      if (preset != null) return preset;
    }
    final raw = prefs.getString(_kRadioSkinKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return RadioSkin.fromJson(map);
      } catch (_) {}
    }
    return RadioSkinPresets.fynitivDefault;
  }

  Future<void> apply(RadioSkin skin) async {
    state = AsyncData(skin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRadioPresetKey);
    await prefs.setString(_kRadioSkinKey, jsonEncode(skin.toJson()));
  }

  Future<void> applyPreset(String id) async {
    final preset = RadioSkinPresets.all.where((s) => s.id == id).firstOrNull;
    if (preset != null) await applyPresetSkin(preset);
  }

  Future<void> applyPresetSkin(RadioSkin preset) async {
    state = AsyncData(preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRadioSkinKey);
    await prefs.setString(_kRadioPresetKey, preset.id);
  }

  Future<void> reset() => applyPresetSkin(RadioSkinPresets.fynitivDefault);
}

final radioSkinControllerProvider = AsyncNotifierProvider<RadioSkinController, RadioSkin>(
  RadioSkinController.new,
);
