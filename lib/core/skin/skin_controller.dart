import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'layout_section.dart';
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
        // Migración: skins custom guardados antes de que `newReleases` tuviera
        // `showLogo:true` (vodLayout con logo de película/serie). Si el preset
        // actual tiene `LayoutSection.newReleases` con `showLogo:true` y el
        // skin guardado no lo tiene, se hereda solo esa sección para que el
        // logo vuelva a aparecer sin perder el resto de personalizaciones.
        final presetForMigration = SkinPresets.all
            .where((s) => s.id == skin.id)
            .firstOrNull;
        if (presetForMigration != null) {
          var migrated = skin;
          bool needsSave = false;

          // Heredar homeLayout/vodLayout si están vacíos y el preset los tiene.
          if (migrated.homeLayout.isEmpty &&
              presetForMigration.homeLayout.isNotEmpty) {
            migrated = migrated.copyWith(
              homeLayout: presetForMigration.homeLayout,
            );
            needsSave = true;
          }
          if (migrated.vodLayout.isEmpty &&
              presetForMigration.vodLayout.isNotEmpty) {
            migrated = migrated.copyWith(
              vodLayout: presetForMigration.vodLayout,
            );
            needsSave = true;
          }

          // Parche específico para `newReleases` con `showLogo:true`.
          // Busca en el preset si hay un newReleases con showLogo y compáralo
          // con el del skin guardado; si el guardado no lo tiene, lo reemplaza.
          LayoutSection? presetNewReleasesHome;
          for (final s in presetForMigration.homeLayout) {
            if (s.type == LayoutSectionType.newReleases) {
              presetNewReleasesHome = s;
              break;
            }
          }
          LayoutSection? presetNewReleasesVod;
          for (final s in presetForMigration.vodLayout) {
            if (s.type == LayoutSectionType.newReleases) {
              presetNewReleasesVod = s;
              break;
            }
          }

          List<LayoutSection> patchSections(
            List<LayoutSection> current,
            LayoutSection? presetSection,
          ) {
            if (presetSection == null) return current;
            final presetScroll = presetSection.scroll;
            // Solo migrar si el preset pide logo y el actual no lo tiene.
            final presetWantsLogo = presetScroll?.showLogo ?? false;
            if (!presetWantsLogo) return current;
            bool patched = false;
            final out = <LayoutSection>[];
            bool found = false;
            for (final sec in current) {
              if (sec.type == LayoutSectionType.newReleases) {
                found = true;
                final curLogo = sec.scroll?.showLogo ?? false;
                if (!curLogo) {
                  out.add(presetSection);
                  patched = true;
                } else {
                  out.add(sec);
                }
              } else {
                out.add(sec);
              }
            }
            // Si el skin guardado no tenía la sección newReleases y el preset sí,
            // no la añadimos automáticamente para no alterar layouts custom,
            // salvo que sea vodLayout de disney_plus donde se espera.
            // Para disney_plus vodLayout sí la inyectamos si falta.
            if (!found &&
                presetWantsLogo &&
                migrated.id == 'disney_plus') {
              // Insertar newReleases del preset en la posición del preset
              // (busca índice en preset y replica en current).
              final presetIndex = presetForMigration.vodLayout.indexOf(
                presetSection,
              );
              if (presetIndex >= 0 && presetIndex <= out.length) {
                out.insert(presetIndex, presetSection);
                patched = true;
              }
            }
            if (patched) needsSave = true;
            return patched ? out : current;
          }

          if (presetNewReleasesHome != null) {
            final patchedHome = patchSections(
              migrated.homeLayout,
              presetNewReleasesHome,
            );
            if (!identical(patchedHome, migrated.homeLayout)) {
              migrated = migrated.copyWith(homeLayout: patchedHome);
              needsSave = true;
            }
          }
          if (presetNewReleasesVod != null) {
            final patchedVod = patchSections(
              migrated.vodLayout,
              presetNewReleasesVod,
            );
            if (!identical(patchedVod, migrated.vodLayout)) {
              migrated = migrated.copyWith(vodLayout: patchedVod);
              needsSave = true;
            }
          }

          if (needsSave) {
            // Persistir la migración para no repetirla.
            // ignore: unawaited_futures
            SharedPreferences.getInstance().then((p) {
              p.setString(_kSkinKey, jsonEncode(migrated.toJson()));
            });
            return migrated;
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
