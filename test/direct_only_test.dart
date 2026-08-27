import 'package:flutter_test/flutter_test.dart';
import 'package:fynitiv/features/library/application/artist_jellyfin_direct.dart';

void main() {
  test('direct GetArtistByName exact sin parentId', () async {
    const serverUrl = 'https://jelly.lopivhouse.page';
    const token = 'b119e0913c074d639c56d135b8184857';
    const userId = '5b3befdd1e044f5388544e25bd3f16b2';
    for (final artist in ['Aitana', 'Shakira']) {
      final res = await fetchArtistByNameExactDirect(serverUrl: serverUrl, token: token, userId: userId, artistName: artist);
      print('DIRECT $artist: ${res.elapsedMs}ms artist=${res.artist?.name} items=${res.items?.length} error=${res.error}');
      expect(res.elapsedMs, greaterThanOrEqualTo(0));
    }
  }, timeout: const Timeout(Duration(seconds: 20)));
}
