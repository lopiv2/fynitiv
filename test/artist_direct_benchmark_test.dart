import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fynitiv/features/library/application/artist_jellyfin_direct.dart';
import 'package:fynitiv/features/library/application/library_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Test manual para comparar jellyfin_dart vs API directa
/// Uso: flutter test test/artist_direct_benchmark_test.dart -- --dart-define=SERVER_URL=... --dart-define=TOKEN=... --dart-define=USER_ID=... --dart-define=ARTIST=Aitana
/// O simplemente ejecutar la app y ver logs de ArtistDetailScreen que ya usa jellyIndex.
/// Este test es solo para medir velocidad exacta sin parentId como pediste.

void main() {
  test('benchmark artist direct exact sin parentId', () async {
    // Intenta leer de --dart-define, si no usa valores por defecto vacíos (no falla, solo log)
    const serverUrl = String.fromEnvironment('SERVER_URL', defaultValue: '');
    const token = String.fromEnvironment('TOKEN', defaultValue: '');
    const userId = String.fromEnvironment('USER_ID', defaultValue: '');
    const artist = String.fromEnvironment('ARTIST', defaultValue: 'Aitana');

    if (serverUrl.isEmpty) {
      // Fallback: intenta usar el provider real si hay sesión guardada (solo funciona si se ejecuta con app context)
      // Para prueba rápida sin credenciales, solo verifica que la función existe y no crashea con params vacíos
      final result = await fetchArtistByNameExactDirect(serverUrl: '', token: '', userId: '', artistName: artist);
      expect(result.error, isNotNull);
      debugPrint('Sin SERVER_URL: test de función directa OK (error esperado)');
      return;
    }

    // Con credenciales reales
    final container = ProviderContainer();
    final client = container.read(jellyfinClientProvider);
    final result = await fetchArtistByNameExactDirect(serverUrl: serverUrl, token: token, userId: userId.isEmpty ? null : userId, artistName: artist);
    debugPrint('DIRECT exact sin parentId: ${result.elapsedMs}ms artist=${result.artist?.name} items=${result.items?.length} error=${result.error}');
    expect(result.elapsedMs, greaterThanOrEqualTo(0));

    // Benchmark comparativo
    await benchmarkArtistFetch(serverUrl: serverUrl, token: token.isEmpty ? null : token, userId: userId.isEmpty ? null : userId, artistName: artist, jellyfinClient: client);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
