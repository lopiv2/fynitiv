import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kTmdbApiKey = 'app.tmdb_api_key';

/// API key de TMDB del usuario (BYO-key), guardada en almacén seguro.
///
/// `null`/vacío = no configurada: las funciones que dependen de TMDB ("Novedades",
/// "Dónde ver") quedan ocultas.
class TmdbKeyNotifier extends AsyncNotifier<String?> {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> build() async {
    final value = await _storage.read(key: _kTmdbApiKey);
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> setKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _kTmdbApiKey);
      state = const AsyncData(null);
    } else {
      await _storage.write(key: _kTmdbApiKey, value: trimmed);
      state = AsyncData(trimmed);
    }
  }
}

final tmdbKeyProvider =
    AsyncNotifierProvider<TmdbKeyNotifier, String?>(TmdbKeyNotifier.new);

/// True si hay una key de TMDB configurada.
final tmdbHasKeyProvider = Provider<bool>((ref) {
  final key = ref.watch(tmdbKeyProvider).value;
  return key != null && key.isNotEmpty;
});
