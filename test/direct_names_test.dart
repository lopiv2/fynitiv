import 'package:flutter_test/flutter_test.dart';
import 'package:fynitiv/features/library/application/artist_jellyfin_direct.dart';

void main() {
  test('direct names Shakira', () async {
    const serverUrl = 'https://jelly.lopivhouse.page';
    const token = 'b119e0913c074d639c56d135b8184857';
    const userId = '5b3befdd1e044f5388544e25bd3f16b2';
    final res = await fetchArtistByNameExactDirect(serverUrl: serverUrl, token: token, userId: userId, artistName: 'Shakira');
    print('Shakira artist=${res.artist?.name} items=${res.items?.length}');
    for (final it in res.items ?? []) {
      print(' - ${it.name} artists=${it.artists} albumArtist=${it.albumArtist}');
    }
    expect(res.items, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 20)));
}
