import 'dart:convert';
import 'dart:io';

import 'package:famil_app/server/famil_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FamilServer server;
  late String baseUrl;
  late Directory tempDir;
  final client = HttpClient();

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('famil_rooms_test_');
    server = FamilServer.open(
      dbPath: '${tempDir.path}/test.db',
      jwtSecret: 'test_secret',
      uploadsDir: '${tempDir.path}/uploads',
    );
    await server.start(port: 0, address: '127.0.0.1');
    baseUrl = 'http://127.0.0.1:${server.port}';
  });

  tearDown(() async {
    await server.stop();
    tempDir.deleteSync(recursive: true);
  });

  Future<Map<String, dynamic>> req(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
    if (token != null) request.headers.set('authorization', 'Bearer $token');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(json.encode(body));
    }
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return {'status': response.statusCode, 'body': text.isEmpty ? {} : json.decode(text)};
  }

  Future<Map<String, dynamic>> register(String username) async {
    final res = await req('POST', '/auth/register', body: {
      'username': username,
      'password': 'pass1234',
      'displayName': username,
    });
    return {'token': res['body']['token'], 'id': res['body']['user']['id']};
  }

  test('방 생성/이름변경은 관리자만 가능하고, 소유자 배정 후 노크 흐름이 정상 동작한다', () async {
    final admin = await register('admin1');
    final owner = await register('owner1');
    final guest = await register('guest1');

    var res = await req('POST', '/rooms', token: guest['token'], body: {'name': '해킹시도'});
    expect(res['status'], 403);

    res = await req('POST', '/rooms', token: admin['token'], body: {'name': '철수방'});
    expect(res['status'], 201);
    final roomId = res['body']['room']['id'];

    res = await req('PATCH', '/rooms/$roomId/name', token: owner['token'], body: {'name': '해킹'});
    expect(res['status'], 403);
    res = await req('PATCH', '/rooms/$roomId/name', token: admin['token'], body: {'name': '철수의방'});
    expect(res['status'], 200);
    expect(res['body']['room']['name'], '철수의방');

    res = await req('POST', '/rooms/$roomId/assign-owner', token: admin['token'], body: {'userId': owner['id']});
    expect(res['status'], 200);
    expect(res['body']['room']['ownerId'], owner['id']);

    // 노크: 소유자 자신은 노크 불가
    res = await req('POST', '/rooms/$roomId/knock', token: owner['token']);
    expect(res['status'], 400);

    res = await req('POST', '/rooms/$roomId/knock', token: guest['token']);
    expect(res['status'], 201);
    final knockId = res['body']['knock']['id'];

    res = await req('GET', '/rooms/knocks/mine?as=incoming', token: owner['token']);
    expect((res['body']['knocks'] as List).any((k) => k['id'] == knockId), true);

    res = await req('POST', '/rooms/knocks/$knockId/respond', token: guest['token'], body: {'approve': true});
    expect(res['status'], 403); // 소유자만 응답 가능

    res = await req('POST', '/rooms/knocks/$knockId/respond', token: owner['token'], body: {'approve': true});
    expect(res['status'], 200);
    expect(res['body']['knock']['status'], 'approved');

    // 출입 제한 시 노크 거부
    res = await req('PATCH', '/rooms/$roomId/access', token: owner['token'], body: {'status': 'closed'});
    expect(res['status'], 200);
    expect(res['body']['room']['knockEnabled'], false);

    res = await req('POST', '/rooms/$roomId/knock', token: guest['token']);
    expect(res['status'], 403);
  });
}
