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
    tempDir = Directory.systemTemp.createTempSync('famil_messages_test_');
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

  test('REST로 메시지를 보내고 대화 목록/내역을 조회할 수 있다', () async {
    final a = await register('msguser1');
    final b = await register('msguser2');

    var res = await req('POST', '/messages', token: a['token'], body: {'receiverId': b['id'], 'content': '안녕!'});
    expect(res['status'], 201);

    res = await req('GET', '/messages/${b['id']}', token: a['token']);
    expect((res['body']['messages'] as List).any((m) => m['content'] == '안녕!'), true);

    res = await req('GET', '/messages/conversations', token: b['token']);
    final conversations = res['body']['conversations'] as List;
    expect(conversations.length, 1);
    expect(conversations.first['partner']['id'], a['id']);
    expect(conversations.first['lastMessage']['content'], '안녕!');
  });

  test('소켓 message:send로 보낸 메시지가 양쪽에 실시간으로 도착한다', () async {
    final a = await register('msguser3');
    final b = await register('msguser4');

    final channelA = IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/realtime?token=${a['token']}'));
    final channelB = IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/realtime?token=${b['token']}'));
    final queueA = StreamQueue(channelA.stream);
    final queueB = StreamQueue(channelB.stream);

    // 첫 메시지는 각자 연결 직후의 status:update.
    await queueA.next;
    await queueB.next;
    // b가 연결되면 a도 상대 온라인 상태 갱신을 한 번 더 받는다.
    await queueA.next;

    channelA.sink.add(json.encode({
      'event': 'message:send',
      'data': {'receiverId': b['id'], 'content': '실시간 안녕!'},
      'ackId': 'x1',
    }));

    // A는 자기 자신에게 온 message:new(발신자도 실시간으로 받음)와 ack를
    // 순서 보장 없이 받을 수 있으므로, 둘 다 받을 때까지 모은다.
    Map<String, dynamic>? ack;
    Map<String, dynamic>? selfEcho;
    for (var i = 0; i < 2; i++) {
      final raw = await queueA.next.timeout(const Duration(seconds: 5));
      final msg = json.decode(raw as String) as Map<String, dynamic>;
      if (msg['event'] == 'ack') {
        ack = msg;
      } else if (msg['event'] == 'message:new') {
        selfEcho = msg;
      }
    }
    expect(ack, isNotNull);
    expect(ack!['data']['message']['content'], '실시간 안녕!');
    expect(selfEcho, isNotNull);
    expect(selfEcho!['data']['content'], '실시간 안녕!');

    final bMsgRaw = await queueB.next.timeout(const Duration(seconds: 5));
    final bMsg = json.decode(bMsgRaw as String) as Map<String, dynamic>;
    expect(bMsg['event'], 'message:new');
    expect(bMsg['data']['content'], '실시간 안녕!');

    await queueA.cancel();
    await queueB.cancel();
    await channelA.sink.close();
    await channelB.sink.close();
  });
}
