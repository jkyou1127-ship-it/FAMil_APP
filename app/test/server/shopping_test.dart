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
    tempDir = Directory.systemTemp.createTempSync('famil_shopping_test_');
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

  test('누구나 장보기 목록에 추가하고, 다른 사람이 추가한 항목도 체크/삭제할 수 있다', () async {
    final a = await register('shop_a');
    final b = await register('shop_b');

    var res = await req('POST', '/shopping', token: a['token'] as String, body: {'content': '우유'});
    expect(res['status'], 201);

    res = await req('GET', '/shopping', token: b['token'] as String);
    var items = res['body']['items'] as List;
    expect(items.length, 1);
    expect(items.first['content'], '우유');
    expect(items.first['bought'], false);
    expect(items.first['addedByName'], 'shop_a');
    final itemId = items.first['id'];

    res = await req('PATCH', '/shopping/$itemId', token: b['token'] as String, body: {'bought': true});
    expect(res['status'], 200);
    items = res['body']['items'] as List;
    expect(items.first['bought'], true);
    expect(items.first['boughtByName'], 'shop_b');

    res = await req('DELETE', '/shopping/bought', token: a['token'] as String);
    expect(res['status'], 204);

    res = await req('GET', '/shopping', token: a['token'] as String);
    expect((res['body']['items'] as List).isEmpty, true);
  });

  test('없는 항목을 체크하거나 지우면 404를 반환한다', () async {
    final a = await register('shop_c');
    var res = await req('PATCH', '/shopping/9999', token: a['token'] as String, body: {'bought': true});
    expect(res['status'], 404);
    res = await req('DELETE', '/shopping/9999', token: a['token'] as String);
    expect(res['status'], 404);
  });
}
