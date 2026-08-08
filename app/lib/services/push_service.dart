import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'local_notifications_service.dart';

/// 앱이 백그라운드/종료 상태일 때 도착한 FCM 메시지를 처리한다.
/// 최상위 함수여야 하며, 별도의 isolate에서 실행되므로 Firebase를 다시 초기화해야 한다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// 온라인 노크/메신저 등의 실시간 이벤트를 앱이 백그라운드/종료 상태에서도 받을 수 있도록
/// Firebase Cloud Messaging을 연동한다. 소켓 기반 실시간 알림을 대체하는 것이 아니라,
/// 앱이 꺼져 있을 때를 보완하는 용도다. Android 외 플랫폼(Windows/Linux)에서는 동작하지 않는다.
class PushService {
  final LocalNotificationsService localNotifications;
  PushService({required this.localNotifications});

  bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  ApiClient? _api;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  bool _initialized = false;

  Future<void> init(ApiClient api) async {
    _api = api;
    if (!isSupported) return;

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      if (!_initialized) {
        _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
        _initialized = true;
      }

      final token = await messaging.getToken();
      if (token != null) await _registerToken(token);

      await _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen(_registerToken);
    } catch (_) {
      // Firebase 설정이 없거나 초기화에 실패해도 앱은 소켓 기반 실시간 알림으로 계속 동작한다.
    }
  }

  Future<void> _registerToken(String token) async {
    final api = _api;
    if (api == null) return;
    try {
      await api.post('/users/me/device-token', {'token': token, 'platform': 'android'});
    } catch (_) {
      // 다음 토큰 갱신 또는 재로그인 시 다시 시도된다.
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;
    localNotifications.showPush(
      id: message.hashCode & 0x7fffffff,
      title: title ?? 'FAMil APP',
      body: body ?? '',
    );
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    await _foregroundSub?.cancel();
  }
}
