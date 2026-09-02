import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'skin.dart';
import 'skin_presets.dart';

const _kSkinKey = 'jellyfin.skin';
const _kSkinPresetKey = 'jellyfin.skin_preset';

/// Skin activo de la app (persistido).
///
/// Si el usuario aplicó un preset sin personalizarlo, solo se guarda su id
/// para que el skin se rehidrate SIEMPRE de la definición actual del preset
/// en el código (así los cambios en `SkinPresets` se reflejan al recargar).
class SkinController extends AsyncNotifier<Skin> {
  @override
  Future<Skin> build() async {
    final prefs = await SharedPreferences.getInstance();
    // Preset sin personalizar → usar la definición actual en el código.
    final presetId = prefs.getString(_kSkinPresetKey);
    if (presetId != null) {
      final preset = SkinPresets.all
          .where((s) => s.id == presetId)
          .firstOrNull;
      if (preset != null) return preset;
    }
    final raw = prefs.getString(_kSkinKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        var skin = Skin.fromJson(map);
        // Migración: skins Prime guardados antes de showCardBadge lo tenían false
        // por defecto; activar si es Prime y la key no existía.
        if (skin.id == 'amazon_prime' &&
            !map.containsKey('showCardBadge')) {
          skin = skin.copyWith(showCardBadge: true);
        }
        // Los skins guardados antes de añadir las filas extra no las traen.
        // Si el skin coincide con un preset, se heredan sus scrolls para que
        // la customización no pierda las filas definidas en el preset.
        if (skin.homeScrolls.isEmpty) {
          final preset = SkinPresets.all
              .where((s) => s.id == skin.id)
              .firstOrNull;
          if (preset != null && preset.homeScrolls.isNotEmpty) {
            return skin.copyWith(homeScrolls: preset.homeScrolls);
          }
        }
        return skin;
      } catch (_) {
        // Skin corrupto: usamos el predeterminado.
      }
    }
    return SkinPresets.jellyfinDefault;
  }

  /// Aplica un skin personalizado y lo persiste completo.
  Future<void> apply(Skin skin) async {
    state = AsyncData(skin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSkinPresetKey);
    await prefs.setString(_kSkinKey, jsonEncode(skin.toJson()));
  }

  /// Aplica un skin a partir de su id (busca en presets; si no, mantiene).
  /// Al ser un preset sin personalizar, solo persiste el id.
  Future<void> applyPreset(String id) async {
    final preset = SkinPresets.all.where((s) => s.id == id).firstOrNull;
    if (preset != null) await applyPresetSkin(preset);
  }

  /// Aplica un preset (sin personalizar) y guarda solo su id.
  Future<void> applyPresetSkin(Skin preset) async {
    state = AsyncData(preset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSkinKey);
    await prefs.setString(_kSkinPresetKey, preset.id);
  }

  /// Restablece al skin predeterminado (como preset sin personalizar).
  Future<void> reset() => applyPresetSkin(SkinPresets.jellyfinDefault);

  /// Devuelve el skin actual como JSON (para exportar/compartir).
  String exportToJson(Skin skin) => jsonEncode(skin.toJson());

  /// Importa un skin desde un JSON. Lanza [FormatException] si es inválido.
  /// Devuelve el skin importado (sin aplicarlo).
  Skin importFromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El JSON no es un objeto válido.');
    }
    return Skin.fromJson(decoded);
  }
}

final skinControllerProvider =
    AsyncNotifierProvider<SkinController, Skin>(SkinController.new);
