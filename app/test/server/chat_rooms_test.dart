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
    tempDir = Directory.systemTemp.createTempSync('famil_chat_rooms_test_');
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

  test('단톡방을 만들고 REST로 메시지를 주고받을 수 있다', () async {
    final owner = await register('croom_owner');
    final guest = await register('croom_guest');

    var res = await req('POST', '/chat-rooms', token: owner['token'], body: {
      'name': '가족방',
      'memberIds': [guest['id']],
    });
    expect(res['status'], 201);
    final roomId = res['body']['room']['id'];

    res = await req('GET', '/chat-rooms', token: guest['token']);
    final rooms = res['body']['rooms'] as List;
    expect(rooms.length, 1);
    expect(rooms.first['id'], roomId);
    expect((rooms.first['members'] as List).length, 2);

    res = await req('POST', '/chat-rooms/$roomId/messages', token: owner['token'], body: {'content': '안녕하세요'});
    expect(res['status'], 201);

    res = await req('GET', '/chat-rooms/$roomId/messages', token: guest['token']);
    final messages = res['body']['messages'] as List;
    expect(messages.length, 1);
    expect(messages.first['content'], '안녕하세요');
    expect(messages.first['senderName'], 'croom_owner');

    res = await req('DELETE', '/chat-rooms/$roomId/members/me', token: guest['token']);
    expect(res['status'], 204);
    res = await req('GET', '/chat-rooms', token: guest['token']);
    expect((res['body']['rooms'] as List).isEmpty, true);
  });

  test('멤버가 아니면 단톡방 메시지를 보거나 보낼 수 없다', () async {
    final owner = await register('croom_owner2');
    final outsider = await register('croom_outsider');

    final createRes = await req('POST', '/chat-rooms', token: owner['token'], body: {
      'name': '단독방',
      'memberIds': [owner['id']],
    });
    final roomId = createRes['body']['room']['id'];

    final res = await req('GET', '/chat-rooms/$roomId/messages', token: outsider['token']);
    expect(res['status'], 403);
  });

  test('소켓 group:message:send로 보낸 메시지가 다른 멤버에게 실시간으로 도착한다', () async {
    final owner = await register('croom_owner3');
    final guest = await register('croom_guest3');

    final createRes = await req('POST', '/chat-rooms', token: owner['token'], body: {
      'name': '실시간방',
      'memberIds': [guest['id']],
    });
    final roomId = createRes['body']['room']['id'];

    final channelOwner =
        IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/realtime?token=${owner['token']}'));
    final channelGuest =
        IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/realtime?token=${guest['token']}'));
    final queueOwner = StreamQueue(channelOwner.stream);
    final queueGuest = StreamQueue(channelGuest.stream);

    await queueOwner.next; // status:update (owner 자신의 연결)
    await queueGuest.next; // status:update (guest 자신의 연결)
    await queueOwner.next; // status:update (guest가 연결되며 다시 브로드캐스트됨)

    channelGuest.sink.add(json.encode({
      'event': 'group:message:send',
      'data': {'roomId': roomId, 'content': '실시간 단톡방 메시지'},
    }));

    final ownerRaw = await queueOwner.next.timeout(const Duration(seconds: 5));
    final ownerMsg = json.decode(ownerRaw as String) as Map<String, dynamic>;
    expect(ownerMsg['event'], 'group:message:new');
    expect(ownerMsg['data']['content'], '실시간 단톡방 메시지');

    await queueOwner.cancel();
    await queueGuest.cancel();
    await channelOwner.sink.close();
    await channelGuest.sink.close();
  });
}
