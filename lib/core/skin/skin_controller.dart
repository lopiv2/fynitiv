import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'skin.dart';
import 'skin_presets.dart';

const _kSkinKey = 'jellyfin.skin';

/// Skin activo de la app (persistido).
class SkinController extends AsyncNotifier<Skin> {
  @override
  Future<Skin> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSkinKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return Skin.fromJson(map);
      } catch (_) {
        // Skin corrupto: usamos el predeterminado.
      }
    }
    return SkinPresets.jellyfinDefault;
  }

  /// Aplica un skin y lo persiste.
  Future<void> apply(Skin skin) async {
    state = AsyncData(skin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSkinKey, jsonEncode(skin.toJson()));
  }

  /// Aplica un skin a partir de su id (busca en presets; si no, mantiene).
  Future<void> applyPreset(String id) async {
    final preset = SkinPresets.all.where((s) => s.id == id).firstOrNull;
    if (preset != null) await apply(preset);
  }

  /// Restablece al skin predeterminado.
  Future<void> reset() => apply(SkinPresets.jellyfinDefault);

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
