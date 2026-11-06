import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/seerr_models.dart';
import 'seerr_controller.dart';

const _kStudiosCache = Duration(minutes: 20);

Color? _parseColor(String? value) {
  final hex = value?.replaceAll('#', '').trim() ?? '';
  if (hex.length != 6 && hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(hex.length == 8 ? parsed : 0xFF000000 | parsed);
}

/// Estudio de la fila "Estudios": nombre curado, id de TMDB, logo y estilo de
/// tarjeta (logo a sangre o degradado + glassmorphism).
class SeerrStudioEntry {
  const SeerrStudioEntry({
    required this.name,
    required this.companyId,
    this.logo,
    this.fillCard = false,
    this.gradient = const [],
  });

  final String name;
  final int companyId;
  final String? logo;

  /// `true` = el logo ocupa toda la tarjeta (tiene fondo propio).
  final bool fillCard;

  /// Colores del degradado para el fondo de la tarjeta.
  final List<Color> gradient;
}

Future<String?> _existingAsset(String? path) async {
  final value = path?.trim() ?? '';
  if (value.isEmpty) return null;
  try {
    await rootBundle.load(value);
    return value;
  } catch (_) {
    return null;
  }
}

String _normalizeStudio(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Archivos de `assets/images/studios/` indexados por nombre normalizado
/// (sin espacios, mayúsculas ni extensión), para que el nombre del archivo no
/// tenga que coincidir exactamente con el del JSON.
Future<Map<String, String>> _studioAssets() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  const extensions = {'png', 'webp', 'jpg', 'jpeg', 'svg'};
  final out = <String, String>{};
  for (final asset in manifest.listAssets()) {
    if (!asset.startsWith('assets/images/studios/')) continue;
    final name = asset.substring(asset.lastIndexOf('/') + 1);
    final dot = name.lastIndexOf('.');
    if (dot <= 0) continue;
    final extension = name.substring(dot + 1).toLowerCase();
    if (!extensions.contains(extension)) continue;
    out[_normalizeStudio(name.substring(0, dot))] = asset;
  }
  return out;
}

/// Catálogo de un estudio desde Seerr (metadatos + películas).
/// Solo los éxitos se cachean 20 min: un fallo transitorio (red, Seerr) no
/// debe envenenar el estudio con un `null`; al salir y entrar (o reintentar)
/// se repite la petición.
final seerrStudioCatalogProvider =
    FutureProvider.family<SeerrStudioCatalog?, int>((ref, studioId) async {
      final link = ref.keepAlive();
      var ok = false;
      try {
        final api = ref.watch(seerrApiProvider);
        if (api == null) return null;
        final catalog = await api.studioCatalog(studioId);
        ok = catalog != null;
        return catalog;
      } catch (_) {
        return null;
      } finally {
        if (ok) {
          Timer(_kStudiosCache, link.close);
        } else {
          link.close();
        }
      }
    });

/// Estudios configurados en `assets/data/studios.json`.
/// Devuelve vacío si Seerr no está configurado: la fila no se muestra.
/// Solo resuelve el logo local; el catálogo se pide al abrir el estudio.
final seerrStudiosProvider = FutureProvider<List<SeerrStudioEntry>>((
  ref,
) async {
  final api = ref.watch(seerrApiProvider);
  if (api == null) return const [];
  final raw = await rootBundle.loadString('assets/data/studios.json');
  final decoded = jsonDecode(raw);
  final list = decoded is Map ? decoded['studios'] : null;
  if (list is! List) return const [];

  Map<String, String> studioAssets = const {};
  try {
    studioAssets = await _studioAssets();
  } catch (_) {}

  final out = <SeerrStudioEntry>[];
  for (final value in list) {
    if (value is! Map) continue;
    final map = value.cast<String, dynamic>();
    final name = (map['name'] as String?)?.trim() ?? '';
    final companyId = (map['companyId'] as num?)?.toInt();
    if (name.isEmpty || companyId == null || companyId <= 0) continue;
    final gradient = <Color>[];
    final colorsRaw = map['colors'];
    if (colorsRaw is List) {
      for (final color in colorsRaw) {
        final parsed = _parseColor(color is String ? color : null);
        if (parsed != null) gradient.add(parsed);
      }
    }
    final explicitLogo = await _existingAsset(
      (map['logo'] as String?)?.trim(),
    );
    out.add(
      SeerrStudioEntry(
        name: name,
        companyId: companyId,
        logo: explicitLogo ?? studioAssets[_normalizeStudio(name)],
        fillCard: (map['fillCard'] as bool?) ?? false,
        gradient: gradient,
      ),
    );
  }
  return out;
});
