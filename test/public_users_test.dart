import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jellyfin_dart/jellyfin_dart.dart';

void main() {
  test('getPublicUsers deserializa la lista del servidor', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((request) {
      if (request.uri.path == '/Users/Public') {
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode([
          {
            'Name': 'Mario',
            'ServerId': 'abc',
            'Id': 'user1',
            'PrimaryImageTag': 'tag1',
            'HasPassword': false,
            'EnableAutoLogin': true,
          },
          {
            'Name': 'Luigi',
            'ServerId': 'abc',
            'Id': 'user2',
            'PrimaryImageTag': null,
            'HasPassword': true,
            'EnableAutoLogin': false,
          },
        ]));
      } else {
        request.response.statusCode = 404;
      }
      request.response.close();
    });

    final port = server.port;
    final client = JellyfinDart(basePathOverride: 'http://127.0.0.1:$port');
    client.setMediaBrowserAuth(
      deviceId: 'device-1',
      version: '1.0.0',
      client: 'Test',
      device: 'Test',
    );

    final response = await client.getUserApi().getPublicUsers();
    final users = response.data;

    expect(users, isNotNull);
    expect(users!.length, 2);
    expect(users[0].name, 'Mario');
    expect(users[0].id, 'user1');
    expect(users[0].primaryImageTag, 'tag1');
    expect(users[1].hasPassword, true);
  });
}
