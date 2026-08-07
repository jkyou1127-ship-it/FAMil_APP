import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

import 'models/app_user.dart';
import 'services/auth_service.dart';

enum SessionStatus { loading, signedOut, signedIn }

/// 로그인 상태와 현재 사용자(AppUser) 문서를 앱 전역에 제공한다.
class AppSession extends ChangeNotifier {
  AppSession(this._authService) {
    _authSub = _authService.authStateChanges.listen(_onAuthChanged);
  }

  final AuthService _authService;
  StreamSubscription<fb_auth.User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;

  SessionStatus status = SessionStatus.loading;
  AppUser? currentUser;

  void _onAuthChanged(fb_auth.User? user) {
    _userSub?.cancel();
    if (user == null) {
      status = SessionStatus.signedOut;
      currentUser = null;
      notifyListeners();
      return;
    }
    _userSub = _authService.watchAppUser(user.uid).listen((appUser) {
      currentUser = appUser;
      status =
          appUser != null ? SessionStatus.signedIn : SessionStatus.loading;
      notifyListeners();
    });
  }

  Future<void> signOut() => _authService.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
