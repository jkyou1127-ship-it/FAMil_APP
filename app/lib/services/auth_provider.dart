import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'api_client.dart';
import 'server_config_service.dart';
import 'socket_service.dart';
import 'token_storage.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthProvider extends ChangeNotifier {
  final ApiClient api;
  final SocketService socket;

  AuthProvider({required this.api, required this.socket});

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? _token;

  /// 앱 시작 시 저장된 서버 주소/토큰을 복원해 자동 로그인을 시도한다.
  Future<void> bootstrap() async {
    final baseUrl = await ServerConfigService.getBaseUrl();
    api.updateBaseUrl(baseUrl);

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

  Future<void> register(String username, String password, String displayName) async {
    final res = await api.post('/auth/register', {
      'username': username,
      'password': password,
      'displayName': displayName,
    });
    await _completeSignIn(res);
  }

  Future<void> login(String username, String password) async {
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
    await TokenStorage.clear();
    api.setToken(null);
    socket.disconnect();
    currentUser = null;
    _token = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  String? get token => _token;
}
