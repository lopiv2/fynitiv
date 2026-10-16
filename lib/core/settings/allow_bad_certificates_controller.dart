import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/image_http_overrides.dart';

const _kAllowBadCertificatesKey = 'app.allow_bad_certificates';

/// Preferencia persistente: aceptar certificados TLS no válidos (autofirmados
/// o de CA no confiable), habituales en servidores caseros. Por defecto activada
/// para que Jellyfin/Seerr/ROMm funcionen sin configuración extra.
class AllowBadCertificatesNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_kAllowBadCertificatesKey) ?? true;
    FynitivHttpOverrides.allowBadCertificates = value;
    return value;
  }

  Future<void> setEnabled(bool enabled) async {
    state = AsyncData(enabled);
    FynitivHttpOverrides.allowBadCertificates = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAllowBadCertificatesKey, enabled);
  }
}

final allowBadCertificatesProvider =
    AsyncNotifierProvider<AllowBadCertificatesNotifier, bool>(
      AllowBadCertificatesNotifier.new,
    );
