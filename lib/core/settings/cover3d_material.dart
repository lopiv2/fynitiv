import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tipo de material con el que se pinta la carátula 3D del detalle de juego.
///
/// Solo lleva parámetros numéricos: el visor de `flutter_scene` los traduce a
/// `PhysicallyBasedMaterial` (PBR) o `UnlitMaterial` (plano). Se persiste por
/// nombre en `SharedPreferences`.
enum Cover3dMaterial {
  /// Plano, sin iluminación: colores exactos de la carátula 2D.
  unlit(metallic: 0, roughness: 1, isUnlit: true),

  /// Plástico mate de baja reflexión.
  matte(metallic: 0, roughness: 0.85),

  /// Plástico con tacto suave (soft-touch).
  softTouch(metallic: 0, roughness: 0.55),

  /// Plástico brillante (default actual).
  glossy(metallic: 0, roughness: 0.3),

  /// Metal cepillado.
  brushedMetal(metallic: 1, roughness: 0.5),

  /// Cromo pulido, muy reflectante.
  chrome(metallic: 1, roughness: 0.12);

  const Cover3dMaterial({
    required this.metallic,
    required this.roughness,
    this.isUnlit = false,
  });

  /// 0 = dieléctrico, 1 = metálico (PBR metallic-roughness).
  final double metallic;

  /// 0 = espejo, 1 = mate (PBR metallic-roughness).
  final double roughness;

  /// True = sin iluminación (`UnlitMaterial`, colores planos exactos).
  final bool isUnlit;
}

const _kCover3dMaterialKey = 'app.cover3d_material';

class Cover3dMaterialController extends Notifier<Cover3dMaterial> {
  @override
  Cover3dMaterial build() {
    _load();
    return Cover3dMaterial.glossy;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCover3dMaterialKey);
    if (raw == null) return;
    final found = Cover3dMaterial.values.asNameMap()[raw];
    if (found != null) state = found;
  }

  Future<void> setMaterial(Cover3dMaterial material) async {
    state = material;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCover3dMaterialKey, material.name);
  }
}

final cover3dMaterialProvider =
    NotifierProvider<Cover3dMaterialController, Cover3dMaterial>(
      Cover3dMaterialController.new,
    );
