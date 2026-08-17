import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart' hide MediaSourceType;
import 'package:fynitiv/features/live_tv/application/jellyfin_live_repository.dart';
import 'package:fynitiv/features/live_tv/domain/media_source_type.dart';

void main() {
  group('jellyfinChannelFromDto', () {
    test('mapea datos básicos y favorito', () {
      final dto = BaseItemDto(
        id: 'ch1',
        name: 'Alta Tensión 84',
        channelNumber: '001',
        isHD: true,
        channelType: ChannelType.TV,
        userData: UserItemDataDto(isFavorite: true),
      );
      final channel = jellyfinChannelFromDto(dto, serverUrl: 'https://srv');

      expect(channel.id, 'ch1');
      expect(channel.name, 'Alta Tensión 84');
      expect(channel.number, '001');
      expect(channel.isHd, true);
      expect(channel.isFavorite, true);
      expect(channel.group, 'TV');
      expect(channel.sourceType, MediaSourceType.jellyfin);
      expect(channel.sourceId, 'ch1');
      expect(channel.logoUrl, isNull); // sin imagen primaria
    });
  });

  group('jellyfinProgramFromDto', () {
    test('mapea título, canal y fechas en UTC', () {
      final dto = BaseItemDto(
        id: 'p9',
        name: 'Mad Max',
        channelId: 'ch1',
        overview: 'En un páramo postapocalíptico…',
        genres: const ['Acción'],
        startDate: DateTime(2026, 8, 17, 20, 0),
        endDate: DateTime(2026, 8, 17, 21, 40),
      );
      final program = jellyfinProgramFromDto(dto);

      expect(program.id, 'p9');
      expect(program.title, 'Mad Max');
      expect(program.channelId, 'ch1');
      expect(program.description, 'En un páramo postapocalíptico…');
      expect(program.genre, 'Acción');
      expect(program.startTime.isUtc, true);
      expect(program.endTime.isUtc, true);
      expect(program.sourceType, MediaSourceType.jellyfin);
    });
  });
}
