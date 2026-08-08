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
    tempDir = Directory.systemTemp.createTempSync('famil_sast_test_');
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

  Future<String> registerAndGetToken(String username) async {
    final res = await req('POST', '/auth/register', body: {
      'username': username,
      'password': 'pass1234',
      'displayName': username,
    });
    return res['body']['token'] as String;
  }

  test('취침/기상 흐름과 수면 유도 노래 설정', () async {
    final token = await registerAndGetToken('sleepuser');

    var res = await req('POST', '/sleep/start', token: token);
    expect(res['status'], 201);

    res = await req('POST', '/sleep/start', token: token);
    expect(res['status'], 409); // 이미 취침 중

    res = await req('POST', '/sleep/wake', token: token);
    expect(res['status'], 200);
    expect(res['body']['record']['durationMinutes'], greaterThanOrEqualTo(0));

    res = await req('PATCH', '/sleep/sound', token: token, body: {'enabled': false});
    expect(res['status'], 200);
    expect(res['body']['sleepSoundEnabled'], false);

    res = await req('PATCH', '/sleep/sound', token: token, body: {'enabled': true, 'soundId': 'lullaby2'});
    expect(res['body']['sleepSoundId'], 'lullaby2');

    res = await req('GET', '/sleep/records', token: token);
    expect((res['body']['records'] as List).length, 1);
  });

  test('취침하면 소유한 방이 자동으로 출입금지로 바뀌고, 기상하면 다시 열린다', () async {
    final adminRes = await req('POST', '/auth/register', body: {
      'username': 'sleeproom_admin',
      'password': 'pass1234',
      'displayName': 'admin',
    });
    final adminToken = adminRes['body']['token'] as String;

    final ownerRes = await req('POST', '/auth/register', body: {
      'username': 'sleeproom_owner',
      'password': 'pass1234',
      'displayName': 'owner',
    });
    final ownerToken = ownerRes['body']['token'] as String;
    final ownerId = ownerRes['body']['user']['id'] as int;

    final roomRes = await req('POST', '/rooms', token: adminToken, body: {'name': '방'});
    final roomId = roomRes['body']['room']['id'] as int;
    await req('POST', '/rooms/$roomId/assign-owner', token: adminToken, body: {'userId': ownerId});

    Future<String> roomAccess() async {
      final res = await req('GET', '/rooms', token: ownerToken);
      final rooms = res['body']['rooms'] as List;
      return rooms.firstWhere((r) => r['id'] == roomId)['accessStatus'] as String;
    }

    await req('POST', '/sleep/start', token: ownerToken);
    expect(await roomAccess(), 'closed');

    await req('POST', '/sleep/wake', token: ownerToken);
    expect(await roomAccess(), 'open');

    // 수동으로 닫아둔 방은 기상해도 자동으로 열리지 않는다.
    await req('PATCH', '/rooms/$roomId/access', token: ownerToken, body: {'status': 'closed'});
    await req('POST', '/sleep/start', token: ownerToken);
    await req('POST', '/sleep/wake', token: ownerToken);
    expect(await roomAccess(), 'closed');
  });

  test('요일별 반복 알람 생성/수정/삭제', () async {
    final token = await registerAndGetToken('alarmuser');

    var res = await req('POST', '/alarms', token: token, body: {
      'time': '25:00',
      'repeatType': 'daily',
    });
    expect(res['status'], 400); // 잘못된 시간 형식

    res = await req('POST', '/alarms', token: token, body: {
      'time': '07:30',
      'repeatType': 'weekly',
      'repeatDays': [1, 3, 5],
      'sound': 'tone2',
    });
    expect(res['status'], 201);
    expect(res['body']['alarm']['repeatDays'], [1, 3, 5]);
    final alarmId = res['body']['alarm']['id'];

    res = await req('PATCH', '/alarms/$alarmId', token: token, body: {'enabled': false});
    expect(res['status'], 200);
    expect(res['body']['alarm']['enabled'], false);
    expect(res['body']['alarm']['sound'], 'tone2'); // 변경 안 한 필드는 유지

    res = await req('DELETE', '/alarms/$alarmId', token: token);
    expect(res['status'], 204);

    res = await req('GET', '/alarms', token: token);
    expect((res['body']['alarms'] as List), isEmpty);
  });

  test('일정 등록/월별 조회/수정/삭제', () async {
    final token = await registerAndGetToken('scheduleuser');

    var res = await req('POST', '/schedules', token: token, body: {'date': '2026-08-08', 'content': '가족 모임'});
    expect(res['status'], 201);
    final scheduleId = res['body']['schedule']['id'];

    res = await req('GET', '/schedules?month=2026-08', token: token);
    expect((res['body']['schedules'] as List).length, 1);

    res = await req('PATCH', '/schedules/$scheduleId', token: token, body: {'content': '가족 모임 (수정됨)'});
    expect(res['body']['schedule']['content'], '가족 모임 (수정됨)');

    res = await req('DELETE', '/schedules/$scheduleId', token: token);
    expect(res['status'], 204);
  });

  test('할 일 완료 처리 시 완료일이 기록되고, 지난 완료 항목은 정리 작업으로 삭제된다', () async {
    final token = await registerAndGetToken('todouser');

    var res = await req('POST', '/todos', token: token, body: {'content': '청소하기'});
    expect(res['status'], 201);
    final todoId = res['body']['todo']['id'];

    res = await req('PATCH', '/todos/$todoId', token: token, body: {'completed': true});
    expect(res['status'], 200);
    expect(res['body']['todo']['completed'], true);
    expect(res['body']['todo']['completedDate'], isNotNull);

    // 완료일을 어제로 되돌려, 자정 정리 작업이 지운다고 판단하는 상황을 재현한다.
    server.db.execute("UPDATE todos SET completed_date = '2000-01-01' WHERE id = ?", [todoId]);
    server.runTodoCleanupForTest();

    res = await req('GET', '/todos', token: token);
    expect((res['body']['todos'] as List).any((t) => t['id'] == todoId), false);
  });
}
