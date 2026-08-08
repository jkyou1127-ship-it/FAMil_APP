import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:famil_app/server/famil_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late FamilServer server;
  late String baseUrl;
  late Directory tempDir;
  final client = HttpClient();

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('famil_misc_test_');
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

  test('건의사항은 익명으로 저장되고 모두가 볼 수 있다', () async {
    final a = await register('sugg1');
    final b = await register('sugg2');

    final postRes = await req('POST', '/suggestions', token: a['token'], body: {'content': '건조기 사주세요'});
    expect(postRes['status'], 201);
    expect(postRes['body']['suggestion'].containsKey('authorId'), false);

    final listRes = await req('GET', '/suggestions', token: b['token']);
    expect((listRes['body']['suggestions'] as List).any((s) => s['content'] == '건조기 사주세요'), true);
  });

  test('상태창은 온라인/방/오늘 일정을 함께 보여준다', () async {
    final admin = await register('status_admin');
    final owner = await register('status_owner');

    final roomRes = await req('POST', '/rooms', token: admin['token'], body: {'name': '방1'});
    final roomId = roomRes['body']['room']['id'];
    await req('POST', '/rooms/$roomId/assign-owner', token: admin['token'], body: {'userId': owner['id']});

    final res = await req('GET', '/status', token: admin['token']);
    expect(res['status'], 200);
    final board = res['body']['board'] as List;
    final ownerEntry = board.firstWhere((b) => b['userId'] == owner['id']);
    expect(ownerEntry['room']['id'], roomId);
  });

  test('온라인 사용자 중에서 추첨하고 실시간으로 결과를 브로드캐스트한다', () async {
    final a = await register('lot1');
    final b = await register('lot2');

    var res = await req('POST', '/lottery/draw', token: a['token']);
    expect(res['status'], 400); // 아직 아무도 소켓으로 연결 안 함 = 온라인 없음

    final channelA = IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/realtime?token=${a['token']}'));
    final channelB = IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/realtime?token=${b['token']}'));
    final queueA = StreamQueue(channelA.stream);
    await queueA.next; // status:update (A 자신의 연결)
    await channelB.stream.first; // status:update (B 자신의 연결)
    await queueA.next; // status:update (B가 연결되며 다시 브로드캐스트됨)

    res = await req('POST', '/lottery/draw', token: a['token']);
    expect(res['status'], 201);
    final winnerId = res['body']['result']['winnerId'];
    expect([a['id'], b['id']], contains(winnerId));

    final drawnRaw = await queueA.next.timeout(const Duration(seconds: 5));
    final drawnMsg = json.decode(drawnRaw as String) as Map<String, dynamic>;
    expect(drawnMsg['event'], 'lottery:drawn');
    expect(drawnMsg['data']['winnerId'], winnerId);

    await queueA.cancel();

    final historyRes = await req('GET', '/lottery/history', token: a['token']);
    expect((historyRes['body']['history'] as List).any((h) => h['winnerId'] == winnerId), true);

    await channelA.sink.close();
    await channelB.sink.close();
  });
}
