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
    tempDir = Directory.systemTemp.createTempSync('famil_server_test_');
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

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body, {String? token}) async {
    final request = await client.postUrl(Uri.parse('$baseUrl$path'));
    request.headers.contentType = ContentType.json;
    if (token != null) request.headers.set('authorization', 'Bearer $token');
    request.write(json.encode(body));
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return {'status': response.statusCode, 'body': text.isEmpty ? {} : json.decode(text)};
  }

  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    final request = await client.getUrl(Uri.parse('$baseUrl$path'));
    if (token != null) request.headers.set('authorization', 'Bearer $token');
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    return {'status': response.statusCode, 'body': text.isEmpty ? {} : json.decode(text)};
  }

  test('첫 계정은 자동으로 관리자가 된다', () async {
    final res = await postJson('/auth/register', {
      'username': 'admin1',
      'password': 'pass1234',
      'displayName': '관리자',
    });
    expect(res['status'], 201);
    expect(res['body']['user']['isAdmin'], true);
  });

  test('두번째 계정은 관리자가 아니다', () async {
    await postJson('/auth/register', {'username': 'admin2', 'password': 'pass1234', 'displayName': '관리자'});
    final res = await postJson('/auth/register', {'username': 'member2', 'password': 'pass1234', 'displayName': '멤버'});
    expect(res['body']['user']['isAdmin'], false);
  });

  test('로그인 성공 및 /auth/me', () async {
    await postJson('/auth/register', {'username': 'user3', 'password': 'pass1234', 'displayName': '사용자'});
    final loginRes = await postJson('/auth/login', {'username': 'user3', 'password': 'pass1234'});
    expect(loginRes['status'], 200);
    final token = loginRes['body']['token'] as String;

    final meRes = await getJson('/auth/me', token: token);
    expect(meRes['status'], 200);
    expect(meRes['body']['user']['username'], 'user3');
  });

  test('잘못된 비밀번호는 거부된다', () async {
    await postJson('/auth/register', {'username': 'user4', 'password': 'pass1234', 'displayName': '사용자'});
    final res = await postJson('/auth/login', {'username': 'user4', 'password': 'wrong'});
    expect(res['status'], 401);
  });

  test('토큰 없이 /auth/me 접근은 거부된다', () async {
    final res = await getJson('/auth/me');
    expect(res['status'], 401);
  });
}
