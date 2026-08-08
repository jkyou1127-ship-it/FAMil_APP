import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:famil_app/server/famil_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FamilServer server;
  late String baseUrl;
  late Directory tempDir;
  final client = HttpClient();

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('famil_users_test_');
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

  Future<String> registerAndGetToken(String username, {String password = 'pass1234'}) async {
    final res = await req('POST', '/auth/register', body: {
      'username': username,
      'password': password,
      'displayName': username,
    });
    return res['body']['token'] as String;
  }

  test('전체 사용자 목록을 조회할 수 있다', () async {
    await registerAndGetToken('u1');
    final token2 = await registerAndGetToken('u2');
    final res = await req('GET', '/users', token: token2);
    expect(res['status'], 200);
    expect((res['body']['users'] as List).length, 2);
  });

  test('표시 이름을 변경할 수 있다', () async {
    final token = await registerAndGetToken('u3');
    final res = await req('PATCH', '/users/me', token: token, body: {'displayName': '새이름'});
    expect(res['status'], 200);
    expect(res['body']['user']['displayName'], '새이름');
  });

  test('현재 비밀번호 확인 후 비밀번호를 변경할 수 있다', () async {
    final token = await registerAndGetToken('u4');
    var res = await req('PATCH', '/users/me/password',
        token: token, body: {'currentPassword': 'wrong', 'newPassword': 'newpass1'});
    expect(res['status'], 401);

    res = await req('PATCH', '/users/me/password',
        token: token, body: {'currentPassword': 'pass1234', 'newPassword': 'newpass1'});
    expect(res['status'], 204);

    res = await req('POST', '/auth/login', body: {'username': 'u4', 'password': 'newpass1'});
    expect(res['status'], 200);
  });

  test('비밀번호 확인 후 아이디를 변경할 수 있다 (중복 불가)', () async {
    await registerAndGetToken('taken');
    final token = await registerAndGetToken('u5');

    var res = await req('PATCH', '/users/me/username', token: token, body: {'password': 'pass1234', 'newUsername': 'taken'});
    expect(res['status'], 409);

    res = await req('PATCH', '/users/me/username', token: token, body: {'password': 'pass1234', 'newUsername': 'u5renamed'});
    expect(res['status'], 200);
    expect(res['body']['user']['username'], 'u5renamed');
  });

  test('기기 토큰을 등록할 수 있다', () async {
    final token = await registerAndGetToken('u6');
    final res = await req('POST', '/users/me/device-token', token: token, body: {'token': 'abc123', 'platform': 'android'});
    expect(res['status'], 204);
  });

  test('관리자는 탈퇴할 수 없고, 일반 사용자는 비밀번호 확인 후 탈퇴할 수 있다', () async {
    final adminToken = await registerAndGetToken('admin_u');
    var res = await req('DELETE', '/users/me', token: adminToken, body: {'password': 'pass1234'});
    expect(res['status'], 403);

    final token = await registerAndGetToken('u7');
    res = await req('DELETE', '/users/me', token: token, body: {'password': 'wrong'});
    expect(res['status'], 401);

    res = await req('DELETE', '/users/me', token: token, body: {'password': 'pass1234'});
    expect(res['status'], 204);

    res = await req('POST', '/auth/login', body: {'username': 'u7', 'password': 'pass1234'});
    expect(res['status'], 401);
  });

  test('프로필 사진을 업로드하면 /uploads로 접근할 수 있다', () async {
    final token = await registerAndGetToken('u8');
    const boundary = 'famil-test-boundary';
    final imageBytes = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46];

    final body = BytesBuilder();
    body.add(utf8.encode('--$boundary\r\n'));
    body.add(utf8.encode('Content-Disposition: form-data; name="photo"; filename="me.jpg"\r\n'));
    body.add(utf8.encode('Content-Type: image/jpeg\r\n\r\n'));
    body.add(imageBytes);
    body.add(utf8.encode('\r\n--$boundary--\r\n'));

    final request = await client.postUrl(Uri.parse('$baseUrl/users/me/photo'));
    request.headers.set('authorization', 'Bearer $token');
    request.headers.contentType = ContentType('multipart', 'form-data', parameters: {'boundary': boundary});
    request.add(body.takeBytes());
    final response = await request.close();
    final resBody = json.decode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
    expect(response.statusCode, 200);
    final photoUrl = resBody['user']['profilePhoto'] as String;
    expect(photoUrl, startsWith('/uploads/profiles/'));

    final photoReq = await client.getUrl(Uri.parse('$baseUrl$photoUrl'));
    final photoRes = await photoReq.close();
    expect(photoRes.statusCode, 200);
  });
}
