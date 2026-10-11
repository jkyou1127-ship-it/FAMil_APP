import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase 콘솔에 등록해둔 "웹 앱" 설정값(공개 클라이언트 식별자 — 비밀값
/// 아님). Android는 google-services.json으로 자동 인식되므로 여기서 다루지
/// 않는다. Windows는 firebase_auth/cloud_firestore가 네이티브 SDK 없이 REST로
/// 동작해서, 구글 콘솔에 별도 "Windows 앱"이 없으므로 같은 웹 설정값을 그대로
/// 쓴다.
class DefaultFirebaseOptions {
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDKAiT0iKQ6qF1L0WffWhwF3gIgKcbDTKU',
    appId: '1:1040298064388:web:5289b1fb331758af079351',
    messagingSenderId: '1040298064388',
    projectId: 'famil-app',
    authDomain: 'famil-app.firebaseapp.com',
    storageBucket: 'famil-app.firebasestorage.app',
  );

  /// 명시적 설정이 필요한 플랫폼(웹/Windows)은 값을, google-services.json처럼
  /// 네이티브 설정 파일로 자동 인식되는 플랫폼(Android)은 null을 돌려준다 —
  /// null이면 호출하는 쪽에서 `Firebase.initializeApp()`을 옵션 없이 부른다.
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return web;
      default:
        return null;
    }
  }
}
