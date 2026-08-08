// Dart 임베디드 서버(FamilServer)를 위한 end-to-end 스모크 테스트.
// backend/src/scripts/smoketest.js와 같은 목적 — 두 백엔드가 같은 API
// 계약을 지키는지, 실제 HTTP/WebSocket 요청으로 전체 흐름을 검증한다.
// 실행: dart run tool/dart_server_smoketest.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:famil_app/server/famil_server.dart';
import 'package:web_socket_channel/io.dart';

int failures = 0;

void assertThat(bool cond, String message) {
  if (cond) {
    stdout.writeln('✓ $message');
  } else {
    failures += 1;
    stderr.writeln('✗ FAIL: $message');
  }
}

class Res {
  final int status;
  final Map<String, dynamic> body;
  Res(this.status, this.body);
}

Future<Res> req(
  HttpClient client,
  String baseUrl,
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
  return Res(response.statusCode, text.isEmpty ? {} : json.decode(text) as Map<String, dynamic>);
}

Future<Map<String, dynamic>> register(HttpClient client, String baseUrl, String username) async {
  final res = await req(client, baseUrl, 'POST', '/auth/register', body: {
    'username': username,
    'password': 'pass1234',
    'displayName': username,
  });
  return {'token': res.body['token'], 'id': res.body['user']['id']};
}

void main() async {
  final tempDir = Directory.systemTemp.createTempSync('famil_dart_smoketest_');
  final server = FamilServer.open(
    dbPath: '${tempDir.path}/test.db',
    jwtSecret: 'dart_smoketest_secret',
    uploadsDir: '${tempDir.path}/uploads',
  );
  await server.start(port: 0, address: '127.0.0.1');
  final baseUrl = 'http://127.0.0.1:${server.port}';
  final client = HttpClient();

  try {
    // ---- 인증: 첫 계정은 관리자 ----
    final admin = await register(client, baseUrl, 'admin1');
    var res = await req(client, baseUrl, 'GET', '/auth/me', token: admin['token'] as String);
    assertThat(res.status == 200 && res.body['user']['isAdmin'] == true, '첫 계정은 자동으로 관리자가 된다');

    final owner = await register(client, baseUrl, 'owner1');
    final guest = await register(client, baseUrl, 'guest1');

    // ---- 방 + 노크 ----
    res = await req(client, baseUrl, 'POST', '/rooms', token: guest['token'] as String, body: {'name': '해킹시도'});
    assertThat(res.status == 403, '관리자가 아니면 방을 만들 수 없다');

    res = await req(client, baseUrl, 'POST', '/rooms', token: admin['token'] as String, body: {'name': '철수방'});
    assertThat(res.status == 201, '관리자는 방을 만들 수 있다');
    final roomId = res.body['room']['id'];

    res = await req(client, baseUrl, 'POST', '/rooms/$roomId/assign-owner',
        token: admin['token'] as String, body: {'userId': owner['id']});
    assertThat(res.status == 200, '관리자가 소유자를 배정한다');

    // ---- 실시간: 노크 + 1:1 메신저 ----
    final ownerSocket = IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/realtime?token=${owner['token']}'));
    final guestSocket = IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:${server.port}/realtime?token=${guest['token']}'));
    final ownerEvents = StreamIterator(ownerSocket.stream);
    final guestEvents = StreamIterator(guestSocket.stream);
    await ownerEvents.moveNext(); // status:update (owner 자신의 연결)
    await guestEvents.moveNext(); // status:update (guest 자신의 연결)
    await ownerEvents.moveNext(); // status:update (guest 연결로 재브로드캐스트)

    res = await req(client, baseUrl, 'POST', '/rooms/$roomId/knock', token: guest['token'] as String);
    assertThat(res.status == 201, '요청자가 노크를 보낸다');
    await ownerEvents.moveNext().timeout(const Duration(seconds: 5));

    final messagePromise = guestEvents.moveNext().timeout(const Duration(seconds: 5));
    ownerSocket.sink.add(json.encode({
      'event': 'message:send',
      'data': {'receiverId': guest['id'], 'content': '실시간 안녕!'},
    }));
    await messagePromise;
    final guestMsg = json.decode(guestEvents.current as String) as Map<String, dynamic>;
    assertThat(guestMsg['event'] == 'message:new' && guestMsg['data']['content'] == '실시간 안녕!', '소켓으로 실시간 메시지가 전달된다');

    // ---- 단톡방 ----
    res = await req(client, baseUrl, 'POST', '/chat-rooms', token: owner['token'] as String, body: {
      'name': '가족방',
      'memberIds': [guest['id']],
    });
    assertThat(res.status == 201, '단톡방을 만들 수 있다');
    final chatRoomId = res.body['room']['id'];
    await guestEvents.moveNext().timeout(const Duration(seconds: 5)); // group:room:new (초대 알림)

    final groupMessagePromise = guestEvents.moveNext().timeout(const Duration(seconds: 5));
    ownerSocket.sink.add(json.encode({
      'event': 'group:message:send',
      'data': {'roomId': chatRoomId, 'content': '단톡방 실시간 메시지'},
    }));
    await groupMessagePromise;
    final groupMsg = json.decode(guestEvents.current as String) as Map<String, dynamic>;
    assertThat(
      groupMsg['event'] == 'group:message:new' && groupMsg['data']['content'] == '단톡방 실시간 메시지',
      '단톡방 멤버가 실시간으로 메시지를 받는다',
    );

    res = await req(client, baseUrl, 'GET', '/chat-rooms/$chatRoomId/messages', token: guest['token'] as String);
    assertThat((res.body['messages'] as List).any((m) => m['content'] == '단톡방 실시간 메시지'), 'REST로 단톡방 대화 내역을 조회할 수 있다');

    await ownerEvents.cancel();
    await guestEvents.cancel();
    await ownerSocket.sink.close();
    await guestSocket.sink.close();

    // ---- 건의사항 ----
    res = await req(client, baseUrl, 'POST', '/suggestions', token: guest['token'] as String, body: {'content': '건조기 사주세요'});
    assertThat(res.status == 201, '건의사항을 등록할 수 있다');

    // ---- 취침/기상 + 수면 유도 노래 ----
    res = await req(client, baseUrl, 'POST', '/sleep/start', token: guest['token'] as String);
    assertThat(res.status == 201, '취침 기록이 생성된다');
    res = await req(client, baseUrl, 'POST', '/sleep/wake', token: guest['token'] as String);
    assertThat(res.status == 200, '기상 시 잔 시간이 계산된다');
    res = await req(client, baseUrl, 'PATCH', '/sleep/sound',
        token: guest['token'] as String, body: {'enabled': true, 'soundId': 'lullaby2'});
    assertThat(res.status == 200 && res.body['sleepSoundId'] == 'lullaby2', '수면 유도 노래 곡을 선택할 수 있다');

    // ---- 알람 / 일정 / 할 일 ----
    res = await req(client, baseUrl, 'POST', '/alarms',
        token: guest['token'] as String, body: {'time': '07:30', 'repeatType': 'daily'});
    assertThat(res.status == 201, '알람을 만들 수 있다');

    res = await req(client, baseUrl, 'POST', '/schedules',
        token: guest['token'] as String, body: {'date': '2026-08-10', 'content': '병원 예약'});
    assertThat(res.status == 201, '일정을 등록할 수 있다');

    res = await req(client, baseUrl, 'POST', '/todos', token: guest['token'] as String, body: {'content': '설거지'});
    assertThat(res.status == 201, '할 일을 등록할 수 있다');
    final todoId = res.body['todo']['id'];
    res = await req(client, baseUrl, 'PATCH', '/todos/$todoId', token: guest['token'] as String, body: {'completed': true});
    assertThat(res.status == 200 && res.body['todo']['completed'] == true, '할 일을 완료 처리할 수 있다');

    // ---- 상태창 ----
    res = await req(client, baseUrl, 'GET', '/status', token: admin['token'] as String);
    assertThat(res.status == 200 && (res.body['board'] as List).isNotEmpty, '상태창을 조회할 수 있다');
  } finally {
    await server.stop();
    tempDir.deleteSync(recursive: true);
  }

  if (failures == 0) {
    stdout.writeln('\n모든 테스트 통과');
    exit(0);
  } else {
    stderr.writeln('\n$failures개 실패');
    exit(1);
  }
}
