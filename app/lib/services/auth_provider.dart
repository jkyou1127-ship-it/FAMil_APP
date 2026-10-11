import 'package:flutter/foundation.dart';

import '../models/backend_mode.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'backend_mode_controller.dart';
import 'firebase_backend.dart';
import 'server_config_service.dart';
import 'socket_service.dart';
import 'token_storage.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthProvider extends ChangeNotifier {
  final ApiClient api;
  final SocketService socket;
  final FirebaseBackend firebaseBackend;
  final BackendModeController modeController;

  AuthProvider({
    required this.api,
    required this.socket,
    required this.firebaseBackend,
    required this.modeController,
  });

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? _token;

  /// 앱 시작 시 저장된 서버 주소/토큰을 복원해 자동 로그인을 시도한다.
  /// 로컬 서버가 응답하지 않으면 Firebase 모드로 자동 전환해서, 그쪽에
  /// 로그인 상태가 남아있다면 그대로 이어서 로그인한다.
  Future<void> bootstrap() async {
    final baseUrl = await ServerConfigService.getBaseUrl();
    api.updateBaseUrl(baseUrl);
    final mode = await modeController.resolve(baseUrl);
    api.mode = mode;

    if (mode == BackendMode.firebase) {
      final user = await firebaseBackend.restoreSession();
      currentUser = user;
      status = user != null ? AuthStatus.signedIn : AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    final token = await TokenStorage.read();
    if (token == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    _token = token;
    api.setToken(token);
    try {
      final res = await api.get('/auth/me');
      currentUser = AppUser.fromJson(res['user'] as Map<String, dynamic>);
      status = AuthStatus.signedIn;
      socket.connect(baseUrl, token);
    } catch (_) {
      await TokenStorage.clear();
      api.setToken(null);
      status = AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    await ServerConfigService.setBaseUrl(url);
    final baseUrl = await ServerConfigService.getBaseUrl();
    api.updateBaseUrl(baseUrl);
  }

  Future<void> _resolveModeForAuthAttempt() async {
    final baseUrl = await ServerConfigService.getBaseUrl();
    api.updateBaseUrl(baseUrl);
    api.mode = await modeController.resolve(baseUrl);
  }

  Future<void> register(String username, String password, String displayName) async {
    await _resolveModeForAuthAttempt();
    if (api.mode == BackendMode.firebase) {
      throw ApiException('회원가입은 로컬(PC) 서버가 켜져 있을 때만 가능합니다. 같은 Wi-Fi에 연결되어 있는지 확인해주세요.');
    }
    final res = await api.post('/auth/register', {
      'username': username,
      'password': password,
      'displayName': displayName,
    });
    await _completeSignIn(res);
  }

  Future<void> login(String username, String password) async {
    await _resolveModeForAuthAttempt();
    if (api.mode == BackendMode.firebase) {
      final user = await firebaseBackend.login(username, password);
      currentUser = user;
      status = AuthStatus.signedIn;
      notifyListeners();
      return;
    }
    final res = await api.post('/auth/login', {'username': username, 'password': password});
    await _completeSignIn(res);
  }

  Future<void> _completeSignIn(Map<String, dynamic> res) async {
    final token = res['token'] as String;
    currentUser = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    _token = token;
    await TokenStorage.write(token);
    api.setToken(token);
    socket.connect(api.baseUrl, token);
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    if (api.mode == BackendMode.firebase) {
      final user = await firebaseBackend.restoreSession();
      if (user != null) {
        currentUser = user;
        notifyListeners();
      }
      return;
    }
    final res = await api.get('/auth/me');
    currentUser = AppUser.fromJson(res['user'] as Map<String, dynamic>);
    notifyListeners();
  }

  void applyUserUpdate(AppUser user) {
    if (currentUser != null && currentUser!.id == user.id) {
      currentUser = user;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (api.mode == BackendMode.firebase) {
      await firebaseBackend.logout();
    } else {
      await TokenStorage.clear();
      api.setToken(null);
      socket.disconnect();
    }
    currentUser = null;
    _token = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  String? get token => _token;
}
