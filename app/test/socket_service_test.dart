import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:famil_app/server/famil_server.dart';
import 'package:famil_app/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// SocketService(클라이언트)가 실제 FamilServer(Dart 서버)와 이 프로토콜로
/// 정상적으로 통신하는지 검증한다 — 두 백엔드(Node/Dart)가 같은 프로토콜을
/// 쓰므로, 이 테스트는 사실상 클라이언트가 어느 쪽과도 통신 가능함을 보장한다.
void main() {
  late FamilServer server;
  late String baseUrl;
  late Directory tempDir;
  final client = HttpClient();

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('famil_socket_service_test_');
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

  test('연결하면 status:update 이벤트를 받는다', () async {
    final token = await registerAndGetToken('su1');
    final socket = SocketService();
    final completer = Completer<dynamic>();

    socket.on('status:update', (data) {
      if (!completer.isCompleted) completer.complete(data);
    });
    socket.connect(baseUrl, token);

    final data = await completer.future.timeout(const Duration(seconds: 5));
    expect((data['users'] as List).length, 1);

    socket.disconnect();
  });

  test('emit으로 보낸 이벤트가 서버에 등록된 핸들러를 통해 ack로 응답한다', () async {
    server.realtime.on('ping', (userId, data, ack) => ack({'pong': true}));

    final token = await registerAndGetToken('su2');
    final socket = SocketService();
    final statusCompleter = Completer<dynamic>();
    socket.on('status:update', (data) {
      if (!statusCompleter.isCompleted) statusCompleter.complete(data);
    });
    socket.connect(baseUrl, token);
    await statusCompleter.future.timeout(const Duration(seconds: 5));

    final ackCompleter = Completer<dynamic>();
    socket.emit('ping', {}, (response) => ackCompleter.complete(response));
    final response = await ackCompleter.future.timeout(const Duration(seconds: 5));
    expect(response['pong'], true);

    socket.disconnect();
  });

  test('두 클라이언트 간 message:send로 실시간 메시지가 전달된다', () async {
    final tokenA = await registerAndGetToken('su3a');
    final tokenB = await registerAndGetToken('su3b');
    final res = await client.getUrl(Uri.parse('$baseUrl/users'));
    res.headers.set('authorization', 'Bearer $tokenA');
    final usersRes = await res.close();
    final users = (json.decode(await usersRes.transform(utf8.decoder).join())['users'] as List);
    final bId = users.firstWhere((u) => u['username'] == 'su3b')['id'];

    final socketA = SocketService();
    final socketB = SocketService();
    final aReady = Completer<void>();
    final bReady = Completer<void>();
    socketA.on('status:update', (_) {
      if (!aReady.isCompleted) aReady.complete();
    });
    socketB.on('status:update', (_) {
      if (!bReady.isCompleted) bReady.complete();
    });
    socketA.connect(baseUrl, tokenA);
    socketB.connect(baseUrl, tokenB);
    await aReady.future.timeout(const Duration(seconds: 5));
    await bReady.future.timeout(const Duration(seconds: 5));

    final messageCompleter = Completer<dynamic>();
    socketB.on('message:new', (data) {
      if (!messageCompleter.isCompleted) messageCompleter.complete(data);
    });
    socketA.emit('message:send', {'receiverId': bId, 'content': '안녕!'});

    final data = await messageCompleter.future.timeout(const Duration(seconds: 5));
    expect(data['content'], '안녕!');

    socketA.disconnect();
    socketB.disconnect();
  });
}
