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
    tempDir = Directory.systemTemp.createTempSync('famil_realtime_test_');
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

  Future<String> registerAndGetToken(String username) async {
    final request = await client.postUrl(Uri.parse('$baseUrl/auth/register'));
    request.headers.contentType = ContentType.json;
    request.write(json.encode({'username': username, 'password': 'pass1234', 'displayName': username}));
    final response = await request.close();
    final body = json.decode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
    return body['token'] as String;
  }

  test('연결하면 곧바로 status:update를 받는다', () async {
    final token = await registerAndGetToken('rtuser1');
    final channel = IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/realtime?token=$token'));

    final first = await channel.stream.first.timeout(const Duration(seconds: 5));
    final msg = json.decode(first as String) as Map<String, dynamic>;
    expect(msg['event'], 'status:update');
    expect((msg['data']['users'] as List).length, 1);

    await channel.sink.close();
  });

  test('등록한 이벤트 핸들러가 ack로 응답한다', () async {
    server.realtime.on('ping', (userId, data, ack) {
      ack({'pong': true, 'userId': userId});
    });

    final token = await registerAndGetToken('rtuser2');
    final channel = IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/realtime?token=$token'));
    final queue = StreamQueue(channel.stream);

    // 첫 메시지는 연결 직후의 status:update.
    await queue.next;

    channel.sink.add(json.encode({'event': 'ping', 'data': {}, 'ackId': 'abc'}));
    final raw = await queue.next.then((v) => v).timeout(const Duration(seconds: 5));
    final msg = json.decode(raw as String) as Map<String, dynamic>;
    expect(msg['event'], 'ack');
    expect(msg['ackId'], 'abc');
    expect(msg['data']['pong'], true);

    await queue.cancel();
    await channel.sink.close();
  });

  test('토큰이 없으면 연결이 거부된다', () async {
    final request = await client.getUrl(Uri.parse('$baseUrl/realtime'));
    request.headers.set('connection', 'upgrade');
    request.headers.set('upgrade', 'websocket');
    final response = await request.close();
    expect(response.statusCode, 403);
  });
}
