import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// server/(자체 백엔드)와 통신하는 REST 클라이언트.
/// 서버 주소와 로그인 토큰은 기기에 영구 저장되어 앱을 재실행해도 유지된다.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _baseUrlKey = 'server_base_url';
  static const _tokenKey = 'auth_token';

  String? baseUrl;
  String? token;

  Future<void> loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_baseUrlKey);
    token = prefs.getString(_tokenKey);
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl!);
  }

  Future<void> setToken(String? newToken) async {
    token = newToken;
    final prefs = await SharedPreferences.getInstance();
    if (newToken == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, newToken);
    }
  }

  bool get hasServer => baseUrl != null && baseUrl!.isNotEmpty;
  bool get hasToken => token != null && token!.isNotEmpty;

  Uri _uri(String path, [Map<String, String>? query]) {
    if (!hasServer) {
      throw ApiException(0, '서버 주소가 설정되지 않았습니다.');
    }
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (hasToken) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final res = await http
        .get(_uri(path, query), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path, {Object? body}) async {
    final res = await http
        .post(_uri(path), headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(String path, {Object? body}) async {
    final res = await http
        .patch(_uri(path), headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> put(String path, {Object? body}) async {
    final res = await http
        .put(_uri(path), headers: _headers, body: body != null ? jsonEncode(body) : null)
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res =
        await http.delete(_uri(path), headers: _headers).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> data = const {};
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        // 본문이 JSON이 아닌 경우(예: 프록시 오류 페이지) 무시하고 상태코드로 판단한다.
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }
    throw ApiException(res.statusCode, data['error'] as String? ?? '요청에 실패했습니다 (${res.statusCode}).');
  }
}
