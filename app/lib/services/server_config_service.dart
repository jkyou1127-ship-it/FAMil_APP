import 'package:shared_preferences/shared_preferences.dart';

/// 자체 백엔드 서버 주소 설정을 담당한다.
/// PC/에뮬레이터 개발 기본값은 localhost, 실기기에서는 사용자가 직접
/// 백엔드가 구동 중인 주소(예: http://192.168.0.10:4000)를 입력해야 한다.
class ServerConfigService {
  static const _key = 'server_base_url';
  static const defaultUrl = 'http://localhost:4000';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? defaultUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString(_key, trimmed.isEmpty ? defaultUrl : trimmed);
  }
}
