import 'package:flutter_test/flutter_test.dart';
import 'package:fynitiv/features/live_tv/domain/program.dart';
import 'package:fynitiv/features/live_tv/domain/media_source_type.dart';
import 'package:fynitiv/features/live_tv/presentation/widgets/epg_viewport.dart';
import 'package:fynitiv/features/live_tv/presentation/widgets/live_tv_utils.dart';

Program _program(int id, DateTime start, DateTime end) => Program(
      id: 'p$id',
      channelId: 'ch1',
      title: 'P$id',
      startTime: start,
      endTime: end,
      sourceType: MediaSourceType.jellyfin,
      sourceId: 'p$id',
    );

void main() {
  group('EpgViewportController', () {
    test('timeToX/xToTime son inversos', () {
      final vp = EpgViewportController()
        ..baseTime = DateTime.utc(2026, 8, 17, 12, 0)
        ..channelCount = 10
        ..setViewportSize(800, 400);

      final t = DateTime.utc(2026, 8, 17, 13, 30);
      final x = vp.timeToX(t);
      expect(vp.xToTime(x), t);
    });

    test('el pan se recorta a los límites', () {
      final vp = EpgViewportController()
        ..baseTime = DateTime.utc(2026, 8, 17, 12, 0)
        ..channelCount = 10
        ..setViewportSize(400, 400);

      vp.panBy(-5000, -5000);
      expect(vp.horizontalOffset, 0);
      expect(vp.verticalOffset, 0);

      vp.panBy(99999, 99999);
      expect(vp.horizontalOffset, vp.totalWidth - 400);
      expect(vp.verticalOffset, vp.totalHeight - 400);
    });

    test('mapea Y a canal y rango visible', () {
      final vp = EpgViewportController()
        ..channelRowHeight = 50
        ..channelCount = 100
        ..setViewportSize(800, 400);
      expect(vp.channelAtY(25), 0);
      expect(vp.channelAtY(125), 2);
      expect(vp.channelAtY(0), 0);
      expect(vp.channelAtY(-1), isNull);

      vp.panBy(0, 300);
      expect(vp.firstVisibleChannel, 6);
      expect(vp.lastVisibleChannel, greaterThanOrEqualTo(6));
    });

    test('zoomBy mantiene estable el punto focal', () {
      final vp = EpgViewportController()
        ..baseTime = DateTime.utc(2026, 8, 17, 12, 0)
        ..channelCount = 5
        ..setViewportSize(1000, 400);
      vp.panBy(200, 0);
      final worldBefore = vp.horizontalOffset + 400;
      vp.zoomBy(2, focalX: 400);
      expect(vp.horizontalOffset + 400, closeTo(worldBefore * 2, 1));
    });
  });

  group('búsqueda binaria de programas', () {
    final programs = [
      _program(1, DateTime.utc(2026, 8, 17, 12, 0), DateTime.utc(2026, 8, 17, 13, 0)),
      _program(2, DateTime.utc(2026, 8, 17, 13, 0), DateTime.utc(2026, 8, 17, 14, 30)),
      _program(3, DateTime.utc(2026, 8, 17, 14, 30), DateTime.utc(2026, 8, 17, 16, 0)),
    ];

    test('programAt encuentra el programa en curso', () {
      expect(programAt(programs, DateTime.utc(2026, 8, 17, 13, 45))!.title, 'P2');
      expect(programAt(programs, DateTime.utc(2026, 8, 17, 15, 0))!.title, 'P3');
      expect(programAt(programs, DateTime.utc(2026, 8, 17, 12, 30))!.title, 'P1');
      expect(programAt(programs, DateTime.utc(2026, 8, 17, 11, 0)), isNull);
      expect(programAt(programs, DateTime.utc(2026, 8, 17, 17, 0)), isNull);
    });

    test('programsInWindow devuelve solo los que intersectan', () {
      final window = programsInWindow(
        programs,
        DateTime.utc(2026, 8, 17, 13, 15),
        DateTime.utc(2026, 8, 17, 15, 0),
      );
      expect(window.map((p) => p.title), ['P2', 'P3']);
    });
  });
}
