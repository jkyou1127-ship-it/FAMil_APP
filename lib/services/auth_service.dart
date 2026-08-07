import '../models/app_user.dart';
import 'api_client.dart';

/// 로그인/회원가입을 자체 백엔드(server/)와 통신해 처리한다.
/// "첫 계정 = 관리자" 규칙은 서버가 보장한다.
class AuthService {
  AuthService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<void> setServerUrl(String url) => _api.setBaseUrl(url);

  bool get hasServerConfigured => _api.hasServer;
  String? get serverUrl => _api.baseUrl;

  Future<AppUser> signIn({required String email, required String password}) async {
    final res = await _api.post('/auth/login', body: {
      'email': email.trim(),
      'password': password,
    });
    await _api.setToken(res['token'] as String);
    return AppUser.fromJson(res['user'] as Map<String, dynamic>);
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final res = await _api.post('/auth/signup', body: {
      'email': email.trim(),
      'password': password,
      'displayName': displayName.trim(),
    });
    await _api.setToken(res['token'] as String);
    return AppUser.fromJson(res['user'] as Map<String, dynamic>);
  }

  Future<AppUser?> tryRestoreSession() async {
    await _api.loadPersisted();
    if (!_api.hasServer || !_api.hasToken) return null;
    try {
      final res = await _api.get('/auth/me');
      return AppUser.fromJson(res['user'] as Map<String, dynamic>);
    } catch (_) {
      await _api.setToken(null);
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // 네트워크 오류여도 로컬 토큰은 지운다.
    }
    await _api.setToken(null);
  }
}
