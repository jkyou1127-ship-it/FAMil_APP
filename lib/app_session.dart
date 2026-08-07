import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/app_user.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/socket_service.dart';

enum SessionStatus { loading, needsServer, signedOut, signedIn }

/// 서버 연결 상태, 로그인 상태, 현재 사용자(AppUser)를 앱 전역에 제공한다.
class AppSession extends ChangeNotifier {
  AppSession(this._authService) {
    _restore();
  }

  final AuthService _authService;
  StreamSubscription<void>? _usersChangedSub;

  SessionStatus status = SessionStatus.loading;
  AppUser? currentUser;
  String? lastError;

  Future<void> _restore() async {
    final user = await _authService.tryRestoreSession();
    if (user == null) {
      status = _authService.hasServerConfigured
          ? SessionStatus.signedOut
          : SessionStatus.needsServer;
      notifyListeners();
      return;
    }
    _onSignedIn(user);
  }

  void _onSignedIn(AppUser user) {
    currentUser = user;
    status = SessionStatus.signedIn;
    final api = ApiClient.instance;
    if (api.baseUrl != null && api.token != null) {
      SocketService.instance.connect(baseUrl: api.baseUrl!, token: api.token!);
    }
    _usersChangedSub?.cancel();
    _usersChangedSub = SocketService.instance.events('users:changed').listen((_) => _refreshMe());
    notifyListeners();
  }

  Future<void> _refreshMe() async {
    final user = await _authService.tryRestoreSession();
    if (user != null) {
      currentUser = user;
      notifyListeners();
    }
  }

  Future<void> configureServer(String url) async {
    await _authService.setServerUrl(url);
    status = SessionStatus.signedOut;
    notifyListeners();
  }

  /// 서버 주소를 잘못 입력했을 때 다시 설정 화면으로 돌아간다.
  Future<void> resetServer() async {
    await _authService.setServerUrl('');
    status = SessionStatus.needsServer;
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    final user = await _authService.signIn(email: email, password: password);
    _onSignedIn(user);
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final user = await _authService.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    _onSignedIn(user);
    return user;
  }

  Future<void> signOut() async {
    await _authService.signOut();
    SocketService.instance.disconnect();
    _usersChangedSub?.cancel();
    currentUser = null;
    status = SessionStatus.signedOut;
    notifyListeners();
  }

  @override
  void dispose() {
    _usersChangedSub?.cancel();
    super.dispose();
  }
}
